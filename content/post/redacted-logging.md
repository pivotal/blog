---
authors:
- kgerritz
categories:
- Spring
- Jackson
- Logging
- Redact
- ObjectMapper
- Aspect
date: 2018-09-01T17:16:22Z
draft: true
short: 
---

## Simplifying Logging with Custom Redaction

### The Problem
As a team we want to simplify the act of logging all requests and response from out Spring controllers. In addition we deal with sensitive data that needs to be omitted or obfuscated in logging.

### The Solution
Annotations! Give the dev team a set of annotations, one to be placed on controller methods that require logging and a couple of annotations to put on request/response objects to specify how to redact information.

### How did we do it?

We created `@Loggable`which is to put on any controller method requiring logging. And then we added `RedactPIIOne`, `RedactPIITwo` and `RedactPIIThree` which are placed on members of request/response objects for various types of redaction. 

Hence redacting logging can be implemented as simply as this.

~~~java
@Loggable
@PostMapping(value = "/some/path", consumes = MediaType.APPLICATION_JSON_VALUE)
public CreateTransferResponse create(@RequestBody Request request) throws Exception {
    return useCase.execute(args);
}
~~~

~~~java
public class Request {
        @RedactPIIOne
        private final String id;
        private final String type;
}
~~~

#### @Loggable

The first step was to create vanilla logging for the controllers and we did this through AspectJ.

~~~java
// add in Loggable definition
~~~

~~~java
@Aspect
public class LoggableAspect {

    private final JsonLoggingHelper jsonLoggingHelper;

    public LoggableAspect(JsonLoggingHelper jsonLoggingHelper) {
        this.jsonLoggingHelper = jsonLoggingHelper;
    }

    @Around(
        "@annotation(com.example.Loggable)")
    public Object logPost(ProceedingJoinPoint joinPoint) throws Throwable {
        if (requestBody != null) {
            jsonLoggingHelper.log(joinPoint.getArg)
            // to flesh out
        }

        Object returnValue = joinPoint.proceed();

        if (returnValue != null) {
            jsonLoggingHelper.log(joinPoint.getArg)
            // to flesh out
        }

        return returnValue;
    }
}
~~~

Now to log any request or response we simply need to add `@Loggable` to our controller method.

### JsonLoggingHelper

Note that we use a `JsonLoggingHelper` which we wrote that's important for the redaction.

~~~java
	// Add JsonLoggingHelper
~~~

~~~java
private JsonLoggingHelper(Logger logger, ObjectMapper mapper) {
    this.logger = logger;
    this.mapper = mapper;
    this.mapper.setAnnotationIntrospector(new RedactorAnnotationsIntrospector());
}
~~~
We create the `JsonLoggingHelper` with an `ObjectMapper` that we then set up for   redacted logging by adding our `RedactorAnnotationsIntrospector`

#### RedactorAnnotationsIntrospector

~~~java
// example of RedactPII.class
~~~

~~~java
public class RedactorAnnotationsIntrospector extends AnnotationIntrospector {

    @Override
    public Object findSerializer(Annotated am) {

        if (am.hasAnnotation(RedactPIIOne.class)) {
            return new RedactionSerializer(new PiiOneRedactionFunction());
        } else if (am.hasAnnotation(RedactPIITwo.class)) {
            return new RedactionSerializer(new PiiTwoRedactionFunction());
        }

        return super.findSerializer(am);
    }

    public boolean hasIgnoreMarker(AnnotatedMember member) {
        boolean skipPassword = member.hasAnnotation(RedactPIIThree.class);
        return skipPassword || super.hasIgnoreMarker(member);
    }
~~~
We have two types of redaction here for three different types of sensitive data (PII). One is to obfuscate like in the case of `RedactPIIOne` e.g. mypassword becomes ****. The second is to remove the PII altogether like in the case of `RedactPIIThree`

### RedactionSerializer

~~~java
static class RedactionSerializer extends StdSerializer<String> {

    private Function redactor;

    public RedactionSerializer(Function redactor) {
        super(String.class);
        this.redactor = redactor;
    }

    @Override
    public void serialize(String value, JsonGenerator jgen, SerializerProvider provider) throws IOException {
        jgen.writeObject(redactor.apply(value));
    }
}
~~~

We used a `RedactionSerializer` in the `RedactorAnnotationsIntrospector` which is required to tell `ObjectMapper` how to serialize the given field. In this example our `RedactionSerializer` takes a redactor function which applies the given obfuscation and then serializes it.

~~~java
 // give example of redactor function
~~~

### Redact PII

Now we can add the redaction annotation to our `Request` object and all logging will redact the specified fields.

---
