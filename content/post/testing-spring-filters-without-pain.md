---
authors:
- fede
categories:
- Spring
- TDD
- Mocking
- Kotlin
date: 2019-03-13T02:51:00Z
short: |
  This article aims at showing you how to test http filters effectively, by avoiding unnecessary mocking and rather appropriately using the test toolkit that Spring offers.
title: Testing Spring filters without pain
---

The Spring framework has grown and changed at a massive pace over the last years. 
It has evolved from XML configured beans to annotation based beans, from synchronous to a non-blocking and reactive programming paradigm, from application server deployments to stand-alone microservice deployments. 

The list goes on.

This evolution is tangible for most of its core classes and interfaces. But there are a few of these that have barely changed since they were initially implemented, and yet they are central cornerstones when developing Spring Boot microservices. One of these classes is the org.springframework.web.filter.GenericFilterBean which was initially developed back in 2003. 

The `org.springframework.web.filter.GenericFilterBean` is the base class you should extend when creating your own filters. 
It simplifies the filter initialisation by being bean-friendly and reduces the number of methods to implement from the servlet Filter interface to just one, the classic doFilter(ServletRequest request, ServletResponse response, FilterChain chain). This method gives you the opportunity to observe the request or response and take action accordingly, for example, vetoing the rest of the filter chain.

Now that we know a little bit more about filters, let’s see how can we implement one, and more importantly, test it with high confidence and fast feedback loops.
This article aims at showing you how to test http filters effectively, by avoiding unnecessary mocking and rather appropriately using the test toolkit that Spring offers.

Imagine that you have to create a http filter that injects the email from the user who initiated the request, into each controller of your app. The filter will get the user id from the query parameters, call a helper service to get the email for that user and finally pass this information down the filter chain. 

Since http requests are immutable, the only possible way to pass additional information down the filter chain is by setting attributes to the request. Setting a request attribute from the filter is straightforward, but the contract of how to use the attribute in the controller is a bit loose, so you might want to capture this well in your filter test.

Before writing the test, let’s start by defining a simple skeleton for our base filter class:

~~~kotlin
@Component
class UserFilter(private val userService: UserService) : GenericFilterBean() {
   override fun doFilter(request: ServletRequest, response: ServletResponse, chain: FilterChain) {
       // implementation goes here
   }
}
~~~

Notice that the filter implements the `GenericFilterBean` mentioned above and takes as parameter a handy `UserService`, which will allow us to obtain the email from a given user id. This service is obviously defined by ourselves, and for this example we are going to use an interface and forget about its actual implementation.

The signature for the `UserService` interface is the following:

~~~kotlin
interface UserService {
   fun getUserEmail(userId: String): String
}
~~~

If we think about the implementation of the filter, these are the steps we need to follow in the code:

1. extract the userId from the query parameters
2. find the email associated to the user id via the userService
3. set the email as a an attribute to the request
4. continue down the filter chain

This implementation captures the steps outlined above:

~~~kotlin
override fun doFilter(request: ServletRequest, response: ServletResponse, chain: FilterChain) {
   val userId = request.getParameter("userId") // 1
   val userEmail = userService.getUserEmail(userId) // 2
   request.setAttribute("userEmail", userEmail) // 3
   chain.doFilter(request, response) // 4
}
~~~

Now let’s move on and see what approaches we have to test this filter.

### Test approach #1: Death by 1,000 mocks

The first way to test that a filter is doing its job is by observing the interactions it plays with the objects that are given to it (in this case the request, response and chain) and then verify that it interacts as expected by calling the right methods of the objects it has references to.

We will see that this way of testing is very hairy and highly ineffective!

Let’s create the test:

~~~kotlin
@Test
fun `user filter adds the user email in a request attribute`() {
   
}
~~~

We then have to mock the request, response and chain:

~~~kotlin
val request = mock(ServletRequest::class.java)
val response = mock(ServletResponse::class.java)
val chain = mock(FilterChain::class.java)
~~~

We are going to stub the `ServletRequest.getParameter` method to return "13" each time we ask for the `userId` value in the query parameter string:

~~~kotlin
Mockito.`when`(request.getParameter("userId")).thenReturn("1")
~~~

Next, we are going to stub our `userService` and return the email of an arbitrary user each time a user with an id 13 comes along:

~~~kotlin
val userService: UserService = Mockito.mock(UserService::class.java)
Mockito.`when`(userService.getUserEmail("13")).thenReturn("han.solo@rebelalliance.com")
~~~

Now we create the filter and we pass the `userService` that will return Han Solo's email whenever a user id of 13 is present:

~~~kotlin
val userFilter = UserFilter(userService)
~~~

We can now invoke the `doFilter` method providing the arguments mocked above:

~~~kotlin
userFilter.doFilter(request, response, chain)
~~~

The last step is to verify the interactions with the mocked objects:

~~~kotlin
verify(request).setAttribute("userEmail", "han.solo@rebelalliance.com")
verify(chain).doFilter(request, response)
verifyNoMoreInteractions(chain)
verifyZeroInteractions(response)
~~~

The test in its grandiose shape looks like this:

~~~kotlin
@Test
fun `user filter adds the user email in a request attribute`() {
   val request = mock(ServletRequest::class.java)
   val response = mock(ServletResponse::class.java)
   val chain = mock(FilterChain::class.java)
   Mockito.`when`(request.getParameter("userId")).thenReturn("1")

   val userService: UserService = Mockito.mock(UserService::class.java)
   Mockito.`when`(userService.getUserEmail("13")).thenReturn("han.solo@rebelalliance.com")

   val userFilter = UserFilter(userService)
   userFilter.doFilter(request, response, chain)

   verify(request).setAttribute("userEmail", "han.solo@rebelalliance.com")
   verify(chain).doFilter(request, response)
   verifyNoMoreInteractions(chain)
   verifyZeroInteractions(response)
}
~~~

What just happened here? Well my friend, we have just stepped into mock hell and we need to get out of there quickly, because in addition to the monumental effort it takes to mock all these objects, we have not learned a single thing about http filters. This test assumes many things about the mocked objects and it can’t possibly prove it works as expected.

Besides preventing you to actually learn how filters work, every time you will refactor your filter, chances are that you will have to refactor the tests too. In addition, the test describes the implementation, but it does not capture the expected behaviour of the filter. This test is just the bone X-ray of the implementation, a description step by step of what the filter needs to do.

So how can we escape mock hell?

There are better ways to test a http filter. Spring provides awesome tools to test the web layer. 
The  next approach I am going to describe leverages Spring’s MockMvc test framework. This approach will give you a higher level of confidence that your filter is doing the right thing as it puts the filter to work with the components that are affected down the chain, like the controller.

### Test approach #2: Using a real controller in the test to interact with the filter

Let's go back to our test class and create a private controller that will return, in the body of the response, the request attribute value that the filter is supposed to inject into the request object: 

~~~kotlin
@RestController
private class TestController {
   @GetMapping("/test")
   fun test(@RequestAttribute userEmail: String): String = userEmail
}
~~~

The first step to escape from the mock hell created before is to remove all the contents from the previous test. The only thing we are going to keep is stubbing the UserService. Here it makes sense to stub the retrieval of the user email and delegate this to a mock (although you could also initialise the DB locally with the data needed for the test and let the filter hit it in your test).

~~~kotlin
@Test
fun `user filter adds the user email in a request attribute`() {
    val userService: UserService = Mockito.mock(UserService::class.java)
    Mockito.`when`(userService.getUserEmail("13")).thenReturn("han.solo@rebelalliance.com")
   // more to come
}
~~~

The next step is to use the `MockMvcBuilders` class from Spring and add the controller just created, along with the filter:

~~~kotlin
val mockMvc = MockMvcBuilders
       .standaloneSetup(TestController())
       .addFilter<StandaloneMockMvcBuilder>(UserFilter(userService))
       .build()
~~~

Finally, we call this `mockMvc` instance with a URL that maps to the test controller and with a query parameter including the userId with a value of "13". Then we will set the expectation that the response content should be the email of Han Solo:

~~~kotlin
mockMvc
       .perform(MockMvcRequestBuilders.get("/test?userId=13"))
       .andExpect(status().isOk)
       .andExpect(content().string("han.solo@rebelalliance.com"))
~~~

Now if we take a step back, the new filter test looks like this:

~~~kotlin
@Test
fun `user filter adds the user email in a request attribute`() {
   val userService: UserService = Mockito.mock(UserService::class.java)
   Mockito.`when`(userService.getUserEmail("1")).thenReturn("han.solo@rebelalliance.com")
   val mockMvc = MockMvcBuilders
           .standaloneSetup(TestController())
           .addFilter<StandaloneMockMvcBuilder>(UserFilter(userService))
           .build()
   mockMvc
           .perform(MockMvcRequestBuilders.get("/test?userId=1"))
           .andExpect(status().isOk)
           .andExpect(content().string("han.solo@rebelalliance.com"))
}
~~~

Notice the following:

In this test we are actually putting the filter with the test controller at work. We have learned that if you add a parameter to the controller function with the annotation @RequestAttribute, your controller will extract that parameter injected from the filter and you will be able to consume it.

By using a test controller and adding the filter to it, we are simulating how our filter will behave once it has been registered with the application controllers. The feedback loop of testing this filter is very quick and the confidence level is high, because we know that the contracts are met when the test passes - for instance, we know that the request attribute is properly injected.

You could argue that this is not a unit-test because we are testing it with different layers of the application, like the controller defined in the test. I prefer not to obsess too much about which layer I am testing the code on, but rather ask myself whether I am accurately capturing the essence of the class I am testing and making sure I don't end up in mock hell as option #1 leads to.

      


