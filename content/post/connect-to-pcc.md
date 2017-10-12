---
authors:
- jlouie
categories:
- PCC
- CF
date: 2017-09-24T17:16:22Z
short: |
  How do you get started with Pivotal Cloud Cache (PCC)? How do you connect your spring boot application to PCC? This blog post attempts to provide you an example on how to connect your spring boot application to PCC. 
title: Connecting To PCC with Spring Boot
---

Ever since I started working with the Pivotal Cloud Cache (PCC) team, I wanted to write a sample application that demonstrated how easy it was to start to use GemFire with little to no configuration. 

# The Scenario

My scenario for my application is fairly simplistic. I own a highly-rated pizza shop that sells only two kinds of pizza: Pepperontonio, and Cheezy Wheezy. I want to find a way to take pizza orders from my customers that is quick and easy.

For my scenario I create models for Pizza, Customer, and Pizza Order. Unfortunately, my pizza shop has a very slow point of sales (PoS) system. Trying to integrate with such a slow PoS system could cause problems, such as not being able to pull and view orders from my application quickly enough to be able to start the pizza order and satisfy my customers. This is a good opportunity to use a cache and have it backed by Pivotal Cloud Cache.

## Creating a PCC cluster

If you are a proud user of Pivotal Cloud Foundry like me and have access to the Pivotal Cloud Cache Tile, then you can quickly create a PCC cluster with just a single command through the Cloud Foundry cli:

So first, type in the following command:

~~~bash
cf create-service p-cloudcache <PLAN> pizza_cache_service
~~~

## Creating your PCC region

Next, you will need to do the following steps to be able to get the pizza shop application working:
Generate a service key for our service so we can get credentials to create our region.
Use `gfsh` and connect to our service instance.
Through `gfsh`, create a region called “PizzaOrder”

## Building the application

Now that you have our service (“pizza_cache_service”), you can start thinking about the application itself. My personal preference for getting started quickly is using Spring Boot- to be more precise - `start.spring.io`. `Start.spring.io` can be used to quickly generate a starter application with libraries that you'll need: `GemFire`, `Web`, `JPA` and ETC. 

### Connecting to PCC

There are some additional libraries you are going to need to add to the `build.gradle` or `pom.xml` file. These are needed to retrieve the credentials from the `pizza_cache_service`. 

- spring-cloud-gemfire-spring-connector
- spring-cloud-gemfire-cloudfoundry-connector


To connect and start using a PCC, the following needs to be done:

First, extend the class `BaseServiceInfo` service info to parse the credentials and set the locators and the user credentials. see [ServiceInfo.java](https://github.com/pivotal-Jammy-Louie/PCC-Pizza/blob/master/src/main/java/io/pivotal/pccpizza/config/ServiceInfo.java)  

Second, extend the class `CloudFoundryServiceInfoCreator` and override the methods `createServiceInfo` and  `accept`. Extending `CloudFoundryServiceInfoCreator` will allow you to work with the PCC service and have access the service’s details (VCAP_SERVICES), which will return a `ServiceInfo`  object that we implemented previously. see [ServiceInfoCreator.java](https://github.com/pivotal-Jammy-Louie/PCC-Pizza/blob/master/src/main/java/io/pivotal/pccpizza/config/ServiceInfoCreator.java)

For more information about [CloudFoundryServiceInfoCreator](https://spring.io/blog/2014/08/05/extending-spring-cloud)

Once the `CloudFoundryServiceInfoCreator` has been created, you will need set the implementation of the `org.springframework.cloud.cloudfoundry.CloudFoundryServiceInfoCreator` to be used by the service loader, as seen in [CloudFoundryServiceInfoCreator.java](https://github.com/pivotal-Jammy-Louie/PCC-Pizza/blob/master/src/main/resources/META-INF/services/org.springframework.cloud.cloudfoundry.CloudFoundryServiceInfoCreator)

You will also need to implement `AuthInitialize` from the geode library and override the `getCredentials`. This will act as a mechanism for the client to get credentials and is required to be implemented as seen in the [UserAuthInitialize.java](https://github.com/pivotal-Jammy-Louie/PCC-Pizza/blob/master/src/main/java/io/pivotal/pccpizza/config/UserAuthInitialize.java)

### Creating the Client Cache

You can now create the ClientCache by parsing the service info credentials and use the ClientCacheFactory.

~~~java`
@Bean
public ClientCache gemfireCache() {
	Cloud cloud = new CloudFactory().getCloud();
	ServiceInfo serviceInfo = (ServiceInfo) cloud.getServiceInfos().get(0);
	ClientCacheFactory factory = new ClientCacheFactory();
	for (URI locator : serviceInfo.getLocators()) {
	   factory.addPoolLocator(locator.getHost(), locator.getPort());
	}
	factory.set(SECURITY_CLIENT, "io.pivotal.pccpizza.config.UserAuthInitialize.create");
	factory.set(SECURITY_USERNAME, serviceInfo.getUsername());
	factory.set(SECURITY_PASSWORD, serviceInfo.getPassword());
	factory.setPdxSerializer(new ReflectionBasedAutoSerializer("io.pivotal.model.PizzaOrder"));
	factory.setPoolSubscriptionEnabled(true); // to enable CQ
	return factory.create();
}
~~~

[GemfireConfiguration.java](https://github.com/pivotal-Jammy-Louie/PCC-Pizza/blob/master/src/main/java/io/pivotal/pccpizza/config/GemfireConfiguration.java)

Now that you have the messy configuration stuff out of the way, you can now get down to the fun stuff with PCC!

### Creating our model

Next is creating thePOJO’s (Plain Old Java Objects) for the pizza shop for things such as pizzas, customers, pizza orders, etc. In the PizzaOrder class, use the `@Region` annotation to map your object to a region and use the `@Id` annotation to indicate which field is going to be used as your key when the objects are placed into the cache.
[PizzaOrder.java](https://github.com/pivotal-Jammy-Louie/PCC-Pizza/blob/master/src/main/java/io/pivotal/pccpizza/model/PizzaOrder.java)

Now to make sure that the app is backed up by PCC, set the cacheManager to use the `ClientCache` that was configured earlier.


~~~java
@Bean
public GemfireCacheManager cacheManager(ClientCache gemfireCache) {
	GemfireCacheManager cacheManager = new GemfireCacheManager();
	cacheManager.setCache(gemfireCache);
	return cacheManager;
}
~~~

If you need to further configure your region with custom settings, you can create a clientRegionFactoryBean and set many different kinds of different attributes, as shown below:

~~~java
@Bean(name = "PizzaOrder")
   ClientRegionFactoryBean<Long, PizzaOrder> orderRegion(@Autowired ClientCache gemfireCache) {
       ClientRegionFactoryBean<Long, PizzaOrder> orderRegion = new ClientRegionFactoryBean<>();
       orderRegion.setCache(gemfireCache);
       orderRegion.setClose(false);
       orderRegion.setShortcut(ClientRegionShortcut.PROXY);
       orderRegion.setLookupEnabled(true);
       return orderRegion;
   }
~~~

With the cache manager set to be backed by the `ClientCache` bean,you can now use the Spring Cache abstraction annotations `@cacheable`, `@cacheput` and `@cacheevict` to place objects into PCC.

For more information about [caching abstraction](https://spring.io/guides/gs/caching/)

As demostated in [PizzaOrderService.java](https://github.com/pivotal-Jammy-Louie/PCC-Pizza/blob/master/src/main/java/io/pivotal/pccpizza/service/PizzaOrderService.java). To simulate a slow POS system there is a thread sleep embedded into the code, if the data is already in our cache when we try to retrieve it we won't need to run into the slow service and just grab the data from the cache.


There we have it! Pizza’s hot and ready.

