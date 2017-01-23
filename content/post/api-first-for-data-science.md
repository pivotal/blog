---
authors:
- dat
- alicia
categories:
- Data Science
- Machine Learning
- API First
- Cloud Foundry
- Smart Apps
date: 2016-07-29T14:55:31+02:00
draft: false
short: |
  How API first can help to create smart data-driven apps.
title: API First for Data Science
---

_Joint work by [Dat Tran](https://de.linkedin.com/in/dat-tran-a1602320) (Data Scientist) and [Alicia Bozyk](https://www.linkedin.com/in/aliciabozyk) (Senior Software Engineer)._

## Key Takeaways
* Think about wrapping up your data science model as an API as early as possible
* Cloud Foundry enables us to reliably expose models as scalable predictive APIs
* Use a suitable continuous delivery tool to automatically deploy your code
* Deploy as early/often as possible, users can test it and give early/regular feedback
* Test-driven development is not appropriate for data science at all phases, especially at the beginning where we need to experiment a lot
* Pairing with fellow software engineers helps in developing better production ready code

## The Problem

During our engagements we often come across business problems which clients want to address in a data driven manner. Usually, we start with understanding the data, creating useful features from it and then building a model. We cross-validate the model for evaluation. In the past, we would present the results to our clients using powerpoints slides which just end up unused.

Often a major contributor to the models going unused is that the tools used by data scientists can differ from those software engineers commonly use to create production ready applications. Data scientists use R, Python, SAS and/or SQL to solve their problems. Those languages are well established in the analytics community but are not as commonly used to create production-ready apps by software engineers. There are solutions like Shiny, SAS or yhat which help data scientist to expose their model but they are limited in scope. You either have to pay a high price to use it or you are stuck with a vendor lock. On the other hand, you have software engineers who can create apps using languages like Java, Ruby or Swift but in most cases they don’t have an understanding of data science techniques or even languages like R or SAS.

Our data science team has found that a good way to bridge this gap is to follow an API first approach, and has adopted this as one of our core principles. In this blog article, I want to discuss how this can help to create smart apps. I will use an end-to-end smart app example to demonstrate this. The whole example can be found in my [repo]( https://github.com/datitran/cf-demo).

## From an Idea to the Smart App

Creating a smart app involves many steps, from data science to making the app itself. But where do we start? Based on data availability we can either kick start the data science part first or lay a foundation to collect enough data.

## The Example

In our case, let’s assume we have the data at hand and our problem is to recognize handwritten numbers from zero to nine using the famous [Mixed National Institute of Standards and Technology database](https://en.wikipedia.org/wiki/MNIST_database) (MNIST) data. The MNIST dataset consists of 60,000 training and 10,000 testing images with a size of 28x28.

{{< responsive-figure src="/images/api-first-for-data-science/mnist-examples.png" class="center" >}}

The primary goal is to convert handwritten text into a format which the computer can understand. For instance we can use a sketchpad to draw our numbers and then the output should be the expected digit. This is a typical handwriting recognition problem and can be extremely useful for many other use cases where we not only want to recognize numbers but also texts.

## The Exploration Phase

Typically, in our data science engagements we start with an exploration phase during which we experiment with different models and approaches to solve our problem. This phase is usually not test driven and we use interactive tools like [Jupyter Notebooks]( http://jupyter.org/) to create model prototypes or just to get a visual understanding of the data.
In our example, the MNIST problem is a typical classification problem which can be solve with many approaches. In this case, we will use a [deep learning](http://deeplearning.net/) model, particularly a [multilayer  perceptron](https://en.wikipedia.org/wiki/Multilayer_perceptron) (MLP) to solve it.

MLP is a feedforward artificial neural network and is especially very good at learning non-linear relations in the data. Nowadays, neural network models are widely used in computer vision, handwritten recognition and many other areas due to their continuous overperformance against traditional machine learning models.

To create our neural network we will use [Keras]( http://keras.io/), a deep learning library written in Python that can be run on top of either [Theano](https://github.com/Theano/Theano) or [TensorFlow](https://github.com/tensorflow/tensorflow). Keras is especially designed for fast prototyping and its simple library allows us to create, train and evaluate neural networks in a very easy and fast manner.

First we load the data. Luckily, Keras has some built-in datasets, including the MNIST dataset, which are used to demonstrate Keras’ capabilities. Using this option, we can easily load the data and get the train and test dataset in the appropriate numerical format.

~~~python
(X_train, y_train), (X_test, y_test) = mnist.load_data()
~~~

In reality, this might not be so straightforward. Normally, the data that we get from our clients are very messy and we spend substantial time in understanding, cleaning and transforming it.

Next, we do some transformations like normalizing the feature space to zero and one. This is useful to speed up the calculation for the neural network later.

~~~python
# reshape the array, use float32 and rescale the data
X_train = X_train.reshape(60000, 784)
X_test = X_test.reshape(10000, 784)
X_train = X_train.astype("float32")
X_test = X_test.astype("float32")
X_train /= 255
X_test /= 255

# convert class vectors to binary class matrices
Y_train = np_utils.to_categorical(y_train, 10)
Y_test = np_utils.to_categorical(y_test, 10)
~~~

Then we create the MLP model with two hidden layers, dropout at each the hidden layer and relu activation. For the output layer we use softmax since it is a multi-class problem.

~~~python
model = Sequential()
model.add(Dense(512, input_shape=(784,)))
model.add(Activation("relu"))
model.add(Dropout(0.2))
model.add(Dense(512))
model.add(Activation("relu"))
model.add(Dropout(0.2))
model.add(Dense(10))
model.add(Activation("softmax"))
~~~

Afterwards, we train and evaluate our model. As the evaluation metric we use [accuracy](https://en.wikipedia.org/wiki/Confusion_matrix) which calculates the correctly identified predictions over the entire population.

~~~python
model.compile(loss="categorical_crossentropy",
              optimizer=RMSprop(),
              metrics=["accuracy"])

model.fit(X_train, Y_train,
          batch_size=128, nb_epoch=20,
          verbose=1, validation_data=(X_test, Y_test))

model.evaluate(X_test, Y_test, verbose=0)
~~~

The result that we got, shows a promising test accuracy value of approx. 98% and therefore we will store this model. Keras normally stores the network architecture and model weight separately. Based on the model’s performance we can try improving the result. In our case the model is already performing quite well so that we can use it for our smart app.

Now we know the input and output of the model and the question is how would we design an interaction point for this app? We’ve been working with images of 28 x 28 size which is not optimal from an app point of view. Imagine yourself drawing it on a small sketchpad, this would be painful. It would therefore make sense to resize the output of the image drawn on a sketchpad to fit our machine learning model. Having those thoughts in mind, we are basically ready to create an API for this problem. At this point, it would make sense to pair with software engineers who can help in writing better quality code.

## The Production Phase

Next, we can start to put our code into production. At this stage, we start to do test-driven development which helps to keep our code base clean and trustworthy. In our [repo]( https://github.com/datitran/cf-demo), you can see that we have a particular directory structure for our production phase. We put all our production-ready code into a folder `src`. In our example, we have a module to train the model and store its output to redis (a key-value storage system), another one to expose the model as a RESTful API and one to consume the API. My Labs colleague [Alicia](https://twitter.com/_alicia) uses [sketch.js](http://intridea.github.io/sketch.js/), a simple canvas-based drawing tool for jQuery to create the sketchpad.

For deployment and testing of our apps, we use [Pivotal Cloud Foundry (PCF) Dev]( https://github.com/pivotal-cf/pcfdev), which is a smaller distribution of PCF. Cloud Foundry (CF) enables us to reliably expose models as scalable predictive APIs. We use [Concourse CI]( https://concourse.ci/) for auto deployment to CF.

{{< responsive-figure src="/images/api-first-for-data-science/ds-concourse-ci.png" class="center" >}}

Concourse checks if a new commit has been made on our git repo and then runs the tests. If the tests pass, our apps will automatically be pushed to CF. In our instance, we have two spaces, one for testing and one for production. The production is only triggered if there is a new tagged version of the code. This makes sense as you might do some user tests for your app with a smaller amount of users instead of all users in production e.g. A/B testing etc.

## The Smart App

Finally, here is the app in action:

{{< responsive-figure src="/images/api-first-for-data-science/handwritten-digit-recognition.gif" class="center" >}}

A live demo is hosted on Pivotal's own Cloud Foundry instance, [PWS](https://run.pivotal.io/). Here is the [link](http://sketch-app.cfapps.io/) for the skech app! The model is still not perfect yet so there are some incorrect recognitions. Try it out by yourself! We can improve our model though by using a different algorithm like convolutional neural network or increasing the size of the hidden layers. Actually LeCun et al. list the test error rate for many different models on their [website]( http://yann.lecun.com/exdb/mnist/).

## The Conclusion

Hope the idea of creating smart apps has become clearer now and it was useful for you. Do get in touch with us if you want to discuss more about this!
