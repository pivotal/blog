---
authors:
- bwatkins
categories:
- Spring
- Java
- Testing
date: 2016-04-11T06:34:12-04:00
short: |
  When your Java Spring web application depends on a third-party OAuth2 single sign-on service,
  tests can be slow, brittle, or difficult to control. I'll describe two ways to address these
  issues by faking OAuth2 single sign-on in your tests. 
title: Faking OAuth2 Single Sign-on in Spring, Two Ways
package used: spring-security-test version 4.0.2.RELEASE 
---

When writing a Java Spring web application that uses an OAuth2 single sign-on (SSO) service for
authentication, testing can be difficult, especially if the SSO service is provided by a third party.
In such cases, it may be more expedient to fake the SSO service in your tests. I'll describe two ways to
structure your tests so that they no longer depend on a third-party SSO service.

Let's assume we're writing a web application with a controller that uses information gathered from the
OAuth2 SSO service. It could be that our controller needs a properly configured `Oauth2RestTemplate` to make
some other request for a protected resource. More commonly, our controller could need to access
details about the authenticated user provided by the SSO service, such as a username or email address.

We'll write a test for the following controller method, which prints the OAuth2 token and
username provided by the SSO service:

~~~java
@RestController
public class TokenController {
    @Autowired
    OAuth2RestTemplate oauthRestTemplate;

    @RequestMapping(path="/api/token", method=RequestMethod.GET)
    public TokenData getAuthenticationInfo() {
        OAuth2Authentication authentication = (OAuth2Authentication) SecurityContextHolder
            .getContext()
            .getAuthentication();
        
        HashMap<String, String> userDetails = (HashMap<String, String>)authentication
            .getUserAuthentication()
            .getDetails();
        
        return new AuthenticationInfo(oauthRestTemplate.getAccessToken(), userDetails);
    }

    class AuthenticationInfo {
        private OAuth2AccessToken token;
        private HashMap<String,String> userDetails;

        public AuthenticationInfo(OAuth2AccessToken token, HashMap<String,String> userDetails) {
            this.token = token;
            this.userDetails = userDetails;
        }

        public String getToken() { return this.token.getValue(); }

        public String getUsername() {
            return this.userDetails.get("user_name");
        }
    }
}
~~~

## Setting up OAuth2 SSO

Since I'll be focusing on testing with OAuth2 SSO, I won't spend too much time describing how to properly configure SSO in a
Spring Boot application. A more detailed explanation can be found [here](http://cloud.spring.io/spring-cloud-security/). In general,
though, you'll need to add the `spring-security-oauth` and `spring-security-test` dependencies to your project, add
the `@EnableOauth2Sso` annotation to the class annotated with `@SpringBootApplication`, and configure your application to use
the OAuth2 SSO service for authentication. Here's the SSO configuration section from a sample `application.yml` file:

```yml
security:
  oauth2:
    client:
      clientId: oauth-client-id
      clientSecret: oauth-client-secret
      accessTokenUri: http://oauthService.com/oauth/token
      userAuthorizationUri: http://oauthService.com/oauth/authorize
      clientAuthenticationScheme: header
    resource:
      userInfoUri: http://oauthService.com/userinfo
```

## Strategy #1: Bypass Authentication with MockMvc

We want to write a test that describes the behavior of our controller method without actually contacting the
third-party SSO service. For our first attempt at achieving this goal, we'll structure our test so that it
bypasses the authentication process altogether. We'll use Spring's `MockMvc` class to make
requests on behalf of a user who appears to have already been authenticated.

Here's our test:

~~~java
@Test
public void testGetAuthenticationInfo() throws Exception {
    MockMvc mockMvc = MockMvcBuilders.webAppContextSetup(webApplicationContext)
            .apply(springSecurity())
            .build();

    mockMvc.perform(MockMvcRequestBuilders.get("/api/token")
            .with(authentication(getOauthTestAuthentication()))
            .sessionAttr("scopedTarget.oauth2ClientContext", getOauth2ClientContext()))
            .andExpect(status().isOk())
            .andExpect(content().contentType(MediaType.APPLICATION_JSON_UTF8))
            .andExpect(jsonPath("$.username").value("bwatkins"))
            .andExpect(jsonPath("$.token").value("my-fun-token"));
}
~~~

We first create a MockMvc object and configure it with the `springSecurity()` method. This initializes the Spring MVC
testing environment so that it can integrate with the Spring security testing framework. Next, we configure the
request so that it uses a fake authentication object (provided by the `getOauthTestAuthentication()` method). This
authentication object describes properties of the authenticated user. Lastly, we inject an `Oauth2ClientContext` object
into the session associated with this request. The client context holds the OAuth2 token; without
this object in the session, Spring security will attempt to make a request to obtain the token if the controller object
attempts to use it (as in our case).

Let's take a closer look at some of the setup for our test.

~~~java
private Authentication getOauthTestAuthentication() {
    return new OAuth2Authentication(getOauth2Request(), getAuthentication());
}
~~~

To create the `Oauth2Authentication` object, we need an `Oauth2Request` object and an `Authentication` object. We can create the
request like so:

~~~java
private OAuth2Request getOauth2Request () {
    String clientId = "oauth-client-id";
    Map<String, String> requestParameters = Collections.emptyMap();
    boolean approved = true;
    String redirectUrl = "http://my-redirect-url.com";
    Set<String> responseTypes = Collections.emptySet();
    Set<String> scopes = Collections.emptySet();
    Set<String> resourceIds = Collections.emptySet();
    Map<String, Serializable> extensionProperties = Collections.emptyMap();
    List<GrantedAuthority> authorities = AuthorityUtils.createAuthorityList("Everything");

    OAuth2Request oAuth2Request = new OAuth2Request(requestParameters, clientId, authorities,
        approved, scopes, resourceIds, redirectUrl, responseTypes, extensionProperties);

    return oAuth2Request;
}
~~~

Normally, Spring would create the `Oauth2Request` object based on the parameters specified in the `application.yml` file along
with parameters returned by the SSO service. Since we are bypassing the authentication step altogether, we'll have to provide our own,
but this gives us an opportunity to modify parameters -- especially the `approved` flag or the list of granted
authorities -- as needed to support various testing scenarios.

The `Authentication` object stores details about the logged-in user that would be obtained when Spring makes a
request to the SSO service `userInfoUri` specified in the application configuration. We provide an
`Authentication` object, configured for our tests, like so:

~~~java
private Authentication getAuthentication() {
    List<GrantedAuthority> authorities = AuthorityUtils.createAuthorityList("Everything");

    User userPrincipal = new User("user", "", true, true, true, true, authorities);

    HashMap<String, String> details = new HashMap<String, String>();
    details.put("user_name", "bwatkins");
    details.put("email", "bwatkins@test.org");
    details.put("name", "Brian Watkins");

    TestingAuthenticationToken token = new TestingAuthenticationToken(userPrincipal, null, authorities);
    token.setAuthenticated(true);
    token.setDetails(details);

    return token;
}
~~~

Finally, we need to create the `Oauth2ClientContext` object that will be injected into the session associated with the request.
Here, we provide a mock object that provides the OAuth2 token we want whenever it is requested.


~~~java
private OAuth2ClientContext getOauth2ClientContext () {
    OAuth2ClientContext mockClient = mock(OAuth2ClientContext.class);
    when(mockClient.getAccessToken()).thenReturn(new DefaultOAuth2AccessToken("my-fun-token"));

    return mockClient;
}
~~~

With these methods in place, our configured MockMvc object will make a fully authenticated request, including details about
the authenticated user and an OAuth2 token. Using this strategy, we can test our application without needing
to authenticate with the actual OAuth2 SSO service.

## Strategy #2. Fake an OAuth2 SSO Service with WireMock

If you need to write an integration or acceptance test that drives a web browser, and you're able to use
[HtmlUnit](http://htmlunit.sourceforge.net) as your browser, you can build on the previous strategy, bypassing
authentication by providing HtmlUnit with a properly configured `MockMvc` object to which it will delegate
HTTP requests. See
[MockMvcHtmlUnitDriverBuilder](https://docs.spring.io/spring/docs/current/javadoc-api/org/springframework/test/web/servlet/htmlunit/webdriver/MockMvcHtmlUnitDriverBuilder.html) and [this series of blog posts](https://spring.io/blog/2014/03/19/introducing-spring-test-mvc-htmlunit) for some
strategies on how to accomplish this.

If you'd prefer that your integration or acceptance style tests use a framework like
[Fluentlenium](http://www.fluentlenium.org) to drive a headless browser like
[PhantomJS](http://phantomjs.org), then you'll need a different approach.
For this second approach, instead of bypassing authentication altogether, we'll 
use [WireMock](http://wiremock.org) to provide our own fake OAuth2 Single Sign-on service
for use during our tests.

Here's our integration test, built with Fluentlenium:

~~~java
@Test
public void testShowAuthenticationInfo () {
    goTo("http://localhost:8099/api/token");

    fill("input[name='username']").with("bwatkins");
    fill("input[name='password']").with("password");
    find("input[type='submit']").click();

    assertThat(pageSource()).contains("username\":\"bwatkins\");
    assertThat(pageSource()).contains("my-fun-token");
}
~~~

Our test makes a request to a protected endpoint, so we expect to be redirected to the SSO service's login page for authentication.
After the single sign-on flow is complete, we will be redirected to the endpoint we
originally requested, and at that point we can make expectations about the response. 

We'll use WireMock to provide a fake OAuth2 SSO service on port 8077, so we first need to configure our test environment to use it.
We provide an `application-test.yml` file that overrides the existing application properties, configuring Spring Security to use
different URIs during testing:

~~~yml
security:
  oauth2:
    client:
      accessTokenUri: http://localhost:8077/oauth/token
      userAuthorizationUri: http://localhost:8077/oauth/authorize
    resource:
      userInfoUri: http://localhost:8077/userinfo
~~~

In our test class, we add a rule to start the WireMock server on port 8077:

~~~java
@Rule
public WireMockRule wireMockRule = new WireMockRule(wireMockConfig().port(8077)
    .extensions(new CaptureStateTransformer()));
~~~

Notice, the `CaptureStateTransformer` extension. This WireMock extension will allow us to examine and modify some of our requests
as needed to complete the OAuth2 SSO flow; we'll get to this in a moment. First, we need to set up the stubs required for the
authentication process. 

~~~java
@Before
public void setUp() {
    stubFor(get(urlPathMatching("/oauth/authorize?.*"))
        .willReturn(aResponse()
            .withStatus(200)
            .withHeader("Content-Type", "text/html")
            .withBodyFile("login.html")
            .withTransformers("CaptureStateTransformer")));

    // More stubs later ...
}
~~~

When an unauthenticated user requests a protected resource in our app, Spring Security will first redirect that user to the SSO service
for authentication, passing several parameters on the query string, including a generated `state` parameter to
guard against CSRF attacks, which we'll discuss later. 
The stub for `/oauth/authorize?.*` handles this redirect request and provides a login page.

This login page can be configured as necessary, but it should mimic the form that the real single sign-on service
will use. Here's a basic example:

~~~html
<html>
<body>
Welcome to the login page!
<br />
<form method="POST" action="/loginSubmit">
    <input type="text" name="username" />
    <input type="password" name="password" />
    <input type="submit" />
</form>
</body>
</html>
~~~

When the form in this login page is submiteed, a POST request will be made to another stubbed endpoint: `/loginSubmit`.

~~~java
stubFor(post(urlEqualTo("/loginSubmit"))
    .willReturn(aResponse()
        .withStatus(302)
        .withHeader("Location", "http://localhost:8099/login?code=oauth_code&state=${state-key}")
        .withTransformers("CaptureStateTransformer")));
~~~

At this point, a real SSO service would check that the user has successfully authenticated before proceeding; our fake service will
assume the credentials are fine and continue with the single sign-on flow.

The SSO service next issues a redirect to a `/login` endpoint within our application. Since we are using Spring Security, that login
endpoint is already configured and maintained automatically in our application. When redirecting to this endpoint, the SSO service
provides a `code` parameter and a `state` parameter. The `code` parameter is a short string generated by the SSO service; for the
purposes of our test it can be anything we want. The `state` parameter must match the value provided earlier in the request to
`/oauth/authorize`. For this reason, our fake SSO service must keep track of the `state` parameter between these requests. We provide
a WireMock extension (`CaptureStateTransformer`) that records the `state` value from the request
to `/oauth/authorize` and adds it to the redirect to `/login`. 

~~~java
class CaptureStateTransformer extends ResponseTransformer {
  private String state = null;

  @Override
  public ResponseDefinition transform(Request request, ResponseDefinition responseDef, FileSource files) {
      // Capture the state parameter from the /oauth/authorize request
      if (state == null && request.queryParameter("state") != null) {
          state = request.queryParameter("state").firstValue();
      }

      // Add the state parameter to the /login redirect
      if (responseDef.getHeaders().getHeader("Location").isPresent()) {
          String redirectLocation = responseDef.getHeaders().getHeader("Location").firstValue();
          return ResponseDefinition.redirectTo(redirectLocation.replace("${state-key}", this.state));
      }

      return responseDef;
  }

  @Override
  public String name() {
      return "CaptureStateTransformer";
  }

  @Override
  public boolean applyGlobally() {
      return false;
  }
}
~~~

This WireMock extension examines requests on the two stubs tagged with `CaptureStateTransformer`. If there is a `state` parameter
among the request parameters (as there is in the request to `/oauth/authorize`), that value is stored. If there is a `Location` header (as there
is in the redirect to `/login`), it replaces the variable `${state-key}` with the stored value. This allows us to capture the state
key in the original request for the login form and pass it back as part of the redirect after the login form is submitted.

We need to provide two more stubs. The request to `/oauth/token` must return the OAuth2 access token, and the request to
`/userInfo` will return data about the authenticated user. The responses here can be configured as necessary for the purposes of the test.

~~~java
stubFor(post(urlEqualTo("/oauth/token"))
    .willReturn(aResponse()
        .withStatus(200)
        .withHeader("Content-Type", "application/json")
        .withBody("{\"access_token\":\"my-fun-token\"}")));

stubFor(get(urlPathEqualTo("/userinfo"))
    .willReturn(aResponse()
        .withStatus(200)
        .withHeader("Content-Type", "application/json")
        .withBody("{\"user_id\":\"my-id\",\"user_name\":\"bwatkins\",\"email\":\"bwatkins@test.com\"}")));
~~~

With these four stubs in place, we've provided a fake OAuth2 SSO service to use during testing. Using this approach, we can
write acceptance tests that describe the bahvior of our application when errors are encountered during the single sign-on process.
Better yet, we can write tests that are faster and more resilient since they no longer depend on a
third-party service for authentication. 
