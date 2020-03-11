---
authors:
- bwatkins
- tomakehurst
categories:
- Spring
- Java
- Testing
- WireMock
- OAuth2
date: 2020-03-10T11:48:00+00:00
short: |
  When your Java Spring web application depends on a third-party OAuth2 single sign-on service,
  tests can be slow, brittle, or difficult to control. In this article we'll show you three ways to address these
  issues by faking OAuth2 single sign-on in your tests.
title: Faking OAuth2 Single Sign-on in Spring, 3 Ways
package used: spring-security-config version 5.2.1.RELEASE
---

When writing a Java Spring web application that uses an OAuth2 single sign-on (SSO) service for
authentication, testing can be difficult, especially if the SSO service is provided by a third party.
In such cases, it may be more expedient to fake the SSO service in your tests.

This article describes three ways to structure your tests so that they no longer depend on a third-party SSO service:

* Bypass authentication entirely using MockMvc.
* Use WireMock to simulate an OAuth2 SSO service.
* Use MockLab's hosted [OAuth2 / OpenID Connect simulation](https://www.moocklab.io/oauth2/?utm_source=pivotal.io&utm_medium=blog&utm_campaign=oauth2-mock).

## Setting up OAuth2 SSO

To enable OAuth2 login in your Spring Boot app, you need to add the `spring-boot-starter-oauth2-client` dependency.
Autoconfiguration will handle most of the OAuth2 plumbing supported by a little bit of configuration, which
we'll get into shortly

Let's assume we're writing a web application with a controller that uses user information gathered from the
OAuth2 SSO service:

~~~java
@SpringBootApplication
@RestController
public class OAuth2ExampleApp extends WebSecurityConfigurerAdapter {

    @Override
    protected void configure(HttpSecurity http) throws Exception {
        http
                .authorizeRequests(a -> a
                        .antMatchers("/", "/error", "/css/**", "/js/**", "/images/**", "/assets/**").permitAll()
                        .anyRequest().authenticated()
                )
                .oauth2Login();
    }

    @GetMapping("/api/user")
    public Map<String, String> getUserInfo(@AuthenticationPrincipal OAuth2User user) {

        Map<String, String> userInfo = new HashMap<>();
        userInfo.put("email", user.getAttribute("email"));
        userInfo.put("id",    user.getAttribute("sub"));

        return userInfo;
    }

    public static void main(String[] args) {
        SpringApplication.run(OAuth2ExampleApp.class, args);
    }
}
~~~

In order to test fetching of user details, we either need to authenticate a user against the app,
or convince Spring that we've already done this. The following sections show three ways this can be achieved.


## Strategy #1: Bypass Authentication with MockMvc

We want to write a test that describes the behavior of our controller method without actually contacting the
third-party SSO service. For our first attempt at achieving this goal, we'll structure our test so that it
bypasses the authentication process altogether. We'll use Spring's `MockMvc` class to make
requests on behalf of a user who appears to have already been authenticated.

Here's our test class:

~~~java
@RunWith(SpringRunner.class)
@SpringBootTest(
        webEnvironment = SpringBootTest.WebEnvironment.MOCK,
        classes = OAuth2ExampleApp.class)
@AutoConfigureMockMvc
public class MockMvcOAuth2Test {

    @Autowired
    private MockMvc mockMvc;

    @Test
    public void testGetAuthenticationInfo() throws Exception {
        OAuth2AuthenticationToken principal = buildPrincipal();
        MockHttpSession session = new MockHttpSession();
        session.setAttribute(
            HttpSessionSecurityContextRepository.SPRING_SECURITY_CONTEXT_KEY,
            new SecurityContextImpl(principal));

        mockMvc.perform(MockMvcRequestBuilders.get("/api/user")
                .session(session))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.email").value("bwatkins@test.org"))
            .andExpect(jsonPath("$.id").value("my-id"));
    }

    private static OAuth2AuthenticationToken buildPrincipal() {
        Map<String, Object> attributes = new HashMap<>();
        attributes.put("sub", "my-id");
        attributes.put("email", "bwatkins@test.org");

        List<GrantedAuthority> authorities = Collections.singletonList(
                new OAuth2UserAuthority("ROLE_USER", attributes));
        OAuth2User user = new DefaultOAuth2User(authorities, attributes, "sub");
        return new OAuth2AuthenticationToken(user, authorities, "whatever");
    }
}
~~~

What we're doing here is programmatically creating the authentication token
that would normally be created from the data fetched from the SSO service.

We place this into the session so that it is available to the Spring Security
filter chain. The presence of a valid token means that the protected resource `/api/user` is
served, rather than a redirect to the login page.


## Strategy #2. Fake an OAuth2 SSO Service with WireMock

If you want your tests use a real browser via an automation framework like
[Fluentlenium](http://www.fluentlenium.org), `MockMvc` won't cut it and you'll need a different strategy.

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

    assertThat(pageSource()).contains("username\":\"bwatkins\"");
    assertThat(pageSource()).contains("my-fun-token");
}
~~~

Our test makes a request to a protected resource, so we expect to be redirected to the SSO service's login page for authentication.
After the single sign-on flow is complete, we will be redirected to the endpoint we
originally requested, and at that point we can make expectations about the response.

We'll use WireMock to provide a fake OAuth2 SSO service on port 8077, so we first need to configure our test environment to use it.
We provide an `application-test.yml` file that overrides the existing application properties, configuring Spring Security to use
different URIs during testing:

~~~yml
spring:
    security:
        oauth2:
            client:
                provider:
                    wiremock:
                        authorization-uri: http://localhost:8077/oauth/authorize
                        token-uri: http://localhost:8077/oauth/token
                        user-info-uri: http://localhost:8077/userinfo
                        user-name-attribute: sub

                registration:
                    wiremock:
                        provider: wiremock
                        authorization-grant-type: authorization_code
                        scope: email
                        redirect-uri: "{baseUrl}/{action}/oauth2/code/{registrationId}"
                        clientId: wm
                        clientSecret: whatever
~~~

In our test class, we add a rule to start the WireMock server on port 8077, enabling
response templating globally (the reason for this will be explained shortly):

~~~java
@Rule
public WireMockRule mockOAuth2Provider = new WireMockRule(wireMockConfig()
  .port(8077)
  .extensions(new ResponseTemplateTransformer(true)));
~~~

Next, we need to set up the stubs required for the authentication process. Let's
start with the login page displayed to the user:

~~~java
@Before
public void setUp() {
    mockOAuth2Provider.stubFor(get(urlPathMatching("/oauth/authorize?.*"))
        .willReturn(aResponse()
            .withStatus(200)
            .withHeader("Content-Type", "text/html")
            .withBodyFile("login.html")));

    // More stubs later ...
}
~~~

When an unauthenticated user requests a protected resource in our app, Spring Security will redirect that user to the SSO service
for authentication. Several parameters will be passed on the query string, including a randomly generated `state` parameter to
guard against CSRF attacks, which we'll discuss later.

The stub for `/oauth/authorize?.*` provides a login page to which the user is redirected.

This login page can be configured as necessary, but it should mimic the form that the real single sign-on service
will use. For the stub to be able to reference `login.html`, the file needs to be placed under WireMock's files directory. This will by default be `src/test/resources/__files`.

Here's a basic example of the required HTML:

~~~html
<html>
<body>
Welcome to the login page!
<br />
<form method="POST" action="/login">
    <input type="hidden" name="state" value="{{request.query.state}}"/>
    <input type="hidden" name="redirectUri" value="{{request.query.redirect_uri}}"/>

    <input type="text" name="username" />
    <input type="password" name="password" />

    <input type="submit" />
</form>
</body>
</html>
~~~

Why all the hidden fields? Well, as mentioned earlier Spring will generate a random, unique value
for `state` at the start of the login flow, and this must be returned to the app's callback
after login otherwise it will be considered to be a potential CSRF attack and rejected.

A real SSO service would store the value of `state` and retrieve it later, and we
could mimick this behavior using a WireMock extension (in fact a previous version of this article
showed how to do this).

However, in this instance we're going to avoid the need to store anything and write
the state into a hidden form field. This way it gets sent to the login form handler stub, which
in turn will include it in the redirect URL used to take the user back to the app.

Exactly the same logic applies to the `redirectUri` field.

By avoiding having to store any state during the interaction, we avoid the complexity
of extending WireMock and ensure that we can run multiple concurrent tests against the same
instance if we need to.

When the form in this login page is submitted, a POST request will be made to another endpoint at `/login`, for which we need another stub:

~~~java
mockOAuth2Provider.stubFor(post(urlPathEqualTo("/login"))
    .willReturn(temporaryRedirect("{{formData request.body 'form' urlDecode=true}}{{{form.redirectUri}}}?code={{{randomValue length=30 type='ALPHANUMERIC'}}}&state={{{form.state}}}")));
~~~

At this point, a real SSO service would check that the user has successfully authenticated before proceeding; our fake service will
assume the credentials are fine and continue with the single sign-on flow, redirecting back to the Spring app's callback URL.

The templated redirect URL ensures that the redirect URL specified by the app is honoured
and the `state` value is correctly passed back.

Spring Security takes care of providing the callback endpoint. When redirecting here, the SSO service
provides a `code` parameter which is a short-lived authorization code. This must be
exchanged for an access token by calling another endpoint on the SSO service, which we will stub now:

~~~java
mockOAuth2Provider.stubFor(post(urlPathEqualTo("/oauth/token"))
    .willReturn(okJson("{\"token_type\": \"Bearer\",\"access_token\":\"{{randomValue length=20 type='ALPHANUMERIC'}}\"}")));
~~~

Finally, the Spring app needs to be able to retrieve information about the user
once it has their access token. Again, this is achieved by calling an endpoint on the SSO service
for this we need a stub:

~~~java
mockOAuth2Provider.stubFor(get(urlPathEqualTo("/userinfo"))
    .willReturn(okJson("{\"sub\":\"my-id\",\"email\":\"bwatkins@test.com\"}")));
~~~

With these four stubs in place, we've provided a fake OAuth2 SSO service to use during testing. Using this approach, we can
write acceptance tests that describe the bahvior of our application when errors are encountered during the single sign-on process.
Better yet, we can write tests that are faster and more resilient since they no longer depend on a
third-party service for authentication.

You can find a fully working example of this approach here: [https://github.com/mocklab/mocklab-demo-app/blob/master/src/test/java/mocklab/demo/OAuth2LoginTest.java#L24](https://github.com/mocklab/mocklab-demo-app/blob/master/src/test/java/mocklab/demo/OAuth2LoginTest.java#L24).

## Strategy #3 - The MockLab OAuth2 / OpenID Connect simulation

MockLab hosts a free SSO simulation based on the above WireMock configuration,
with support added for OpenID Connect in addition to the plain OAuth2 flow. OpenID Connect is now a
widely adopted standard, and used by SSO services such as Google, Okta and Auth0.

MockLab's website describes in full how to [integrate the oauth2 mock](https://www.mocklab.io/docs/oauth2-mock/?utm_source=pivotal.io&utm_medium=blog&utm_campaign=oauth2-mock),
but in esssence all you need to do is modify Spring application configuration as follows:

```yml
spring:
    security:
        oauth2:
            client:
                provider:
                    mocklab:
                        authorization-uri: https://oauth.mocklab.io/oauth/authorize
                        token-uri: https://oauth.mocklab.io/oauth/token
                        user-info-uri: https://oauth.mocklab.io/userinfo
                        user-name-attribute: sub
                        jwk-set-uri: https://oauth.mocklab.io/.well-known/jwks.json

                registration:
                    mocklab:
                        provider: mocklab
                        authorization-grant-type: authorization_code
                        scope: openid, profile, email
                        redirect-uri: "{baseUrl}/{action}/oauth2/code/{registrationId}"
                        clientId: mocklab_oidc
                        clientSecret: whatever
```

Note the `openid` value that appears in the `scope` parameter. Adding this causes
Spring Security to attempt to use an OpenID Connect compatible flow, whereby the user info
is retrieved from an ID token in JSON Web Token format. It also causes a nonce value
to be passed to the SSO server and back via the ID token, which helps prevent replay
attacks.
