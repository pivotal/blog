---
authors:
- chendrix
categories:
- Golang
- HTTP
- MySQL
date: 2015-11-05T13:55:53-07:00
short: |
  Signaling failure during an HTTP stream
title: HTTP Trailers
---

## Motivation
We, the core-services team, are responsible for the MySQL service. This service runs alongside a Cloud Foundry installation and creates MySQL databases for your Cloud Foundry applications to use.

Operators have been requesting automated database backups so they can restore their MySQL instances in case of failure. A MySQL backup is a tarball containing all the data in the MySQL instance, which can become very large. We ultimately want to upload that file to S3 or another external blobstore so that it will be available to recreate the MySQL instance if it is destroyed.

When the MySQL server gets a request to take a backup, it can do one of two things:

- First generate the backup on local disk and then upload it to our blobstore
- Generate it and stream it as it's being generated.

The problem with the two-step generate-then-upload approach is that we would have to reserve twice as much space on the MySQL server's file system as we would otherwise need.

We settled on trying to generate and simultaneously stream the backup.

## Streaming in HTTP

In HTTP/1.0, you had to specify the length of your response in advance via the Content-Length Header field. HTTP/1.1 removed that limitation, allowing senders to stream content, with the addition of [Chunked Transfer Coding](http://www.w3.org/Protocols/rfc2616/rfc2616-sec3.html#sec3.6.1). According to [Wikipedia](https://en.wikipedia.org/wiki/Chunked_transfer_encoding), this enabled "senders [to] begin transmitting dynamically-generated content before knowing the total size of that content."

## The problems with streaming in HTTP

The first problem we encountered when trying to stream data as it's generated is how to indicate failure.

In a traditional HTTP response, if something went wrong during the processing of the request, you would use the HTTP status code of 5xx to indicate a failure.

An HTTP status code is actually encoded in the [Status Line](http://www.w3.org/Protocols/rfc2616/rfc2616-sec6.html#sec6.1) of the raw response, the first line of the response as seen below (HTTP/1.1 200 OK):

```no-language
$ curl -i --raw http://www.w3.org/Protocols/rfc2616/rfc2616-sec6.html#sec6.1

HTTP/1.1 200 OK
Date: Thu, 23 Jul 2015 21:41:00 GMT
Server: Apache/2
Last-Modified: Wed, 01 Sep 2004 13:24:52 GMT
ETag: "277f-3e3073913b100"
Accept-Ranges: bytes
Content-Length: 10111
Cache-Control: max-age=21600
Expires: Fri, 24 Jul 2015 03:41:00 GMT
P3P: policyref="http://www.w3.org/2014/08/p3p.xml"
Content-Type: text/html; charset=iso-8859-1

<RESPONSE BODY>
```

Notice that the response body begins after all of the headers, including the status code. This means that by the time you start streaming back data, the status code has already been sent. If an issue occurs in the middle of streaming, there is no way of going back and changing the status code.

So how do you indicate that there was a failure in the land of streaming responses?

## Enter HTTP Trailers

If you had a way of sending metadata at the end of the response, then no matter when an error occurs, you could stop the streaming and send an error description.

HTTP Trailers are like HTTP Headers sent at the end of an HTTP response. They can be used to send metadata separate from the response body. Trailers are only available when using Chunked Transfer Coding.

Even though trailers are a part of the official HTTP spec, they are rarely used. According to the Golang documentation, "few HTTP clients, servers, or proxies support HTTP trailers."

## HTTP/1.1 Trailer Spec

HTTP Trailers are implemented in two parts. First, you must send a regular HTTP Header listing the trailers that you will eventually send.

```no-language
Trailer: X-Streaming-Error
```

Second, you must send your trailers at the end of your response. A Chunked Transfer Coding response looks like

```
Chunked-Body = *chunk
               last-chunk
               trailer
               CRLF
```

Your trailers are sandwiched between the last-chunk you send and the CRLF that indicates the end of the response.

## Implementation

#### Go 1.4

Golang provides the HTTP [ResponseWriter](http://golang.org/pkg/net/http/#ResponseWriter) interface for writing the headers and body of an HTTP response. Unfortunately, in Go 1.4, the `ResponseWriter` interface does not support writing trailers. [This issue](https://github.com/golang/go/issues/7759) has been filed in the golang github repo.

As described in that issue, we can use the HTTP `Hijacker` object as a work-around to take over the connection and write raw HTTP data directly:

```go
func (b *BackupHandler) ServeHTTP(writer http.ResponseWriter, r *http.Request) {
    trailerKey := http.CanonicalHeaderKey("X-Streaming-Error")

    // NOTE: We set this in the Header because of the HTTP spec
    // http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.40
    // Even though we cannot test it, because the `net/http.Get()` strips
    // "Trailer" out of the Header
    writer.Header().Set("Trailer", trailerKey)

    err := runBackupProcessAndWriteTo(writer)

    errorString := ""
    if err != nil {
        errorString = err.Error()
    }

    writeTrailer(writer, trailerKey, errorString)
}

func writeTrailer(writer http.ResponseWriter, key string, value string) {
    trailers := http.Header{}
    trailers.Set(key, value)

    writer.(http.Flusher).Flush()
    conn, buf, _ := writer.(http.Hijacker).Hijack()

    buf.WriteString("0\r\n") // eof
    trailers.Write(buf)

    buf.WriteString("\r\n") // end of trailers
    buf.Flush()
    conn.Close()
}
```

The trailers from the response are stored in the [`Response.Trailer`](http://golang.org/src/net/http/response.go?s=2161:2254) field, which is of type `Header` (just a `map[string][]string`). It's important to note that this field will not be populated until you finish reading the entire response body.

```go
It("has HTTP 200 status code but writes the error to the trailer", func() {
    resp, err := http.Get(backupUrl)    Expect(err).ShouldNot(HaveOccurred())

    Expect(resp.StatusCode).To(Equal(200))

    // NOTE: You must read the body from the response in order to populate the response's
    // trailers
    body, err := ioutil.ReadAll(resp.Body)
    Expect(err).ShouldNot(HaveOccurred())
    Expect(body).To(Equal([]byte("hello"))) // data sent before the error occurred

    t := resp.Trailer.Get(http.CanonicalHeaderKey("X-Streaming-Error"))
    Expect(t).To(ContainSubstring("exit status 1"))
})
```

#### Go 1.5

In [Go 1.5](http://tip.golang.org/doc/go1.5), the ability to write trailers should be supported natively by [`ResponseWriter`](http://tip.golang.org/pkg/net/http/#example_ResponseWriter_trailers):

```go
mux := http.NewServeMux()
mux.HandleFunc("/sendstrailers", func(w http.ResponseWriter, req *http.Request) {
    // Before any call to WriteHeader or Write, declare
    // the trailers you will set during the HTTP
    // response. These three headers are actually sent in
    // the trailer.
    w.Header().Set("Trailer", "AtEnd1, AtEnd2")
    w.Header().Add("Trailer", "AtEnd3")

    w.Header().Set("Content-Type", "text/plain; charset=utf-8") // normal header
    w.WriteHeader(http.StatusOK)

    w.Header().Set("AtEnd1", "value 1")
    io.WriteString(w, "This HTTP response has both headers before this text and trailers at the end.\n")
    w.Header().Set("AtEnd2", "value 2")
    w.Header().Set("AtEnd3", "value 3") // These will appear as trailers.
})
```
---

Happy Hacking,

Chris Hendrix + Evan Short on behalf of the CF Core Services team

