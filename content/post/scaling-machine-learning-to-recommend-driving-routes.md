---
authors:
- Swati Soni 
- swati
categories:
- Spark & Hadoop
- real-time prediction & recommendation
- feature engineering pipeline
- driver revenue prediction
- Scale Machine Learning
date: 2018-03-24T17:16:22Z
draft: true
short: |
  The Pivotal Data Science Labs helped a multinational customer build a scalable, real-time predictions and recommendations application to increase revenue. We built an end-to-end machine learning workflow which addresses online deployments and offline training using open source projects and Pivotal products.
title: Scaling Machine Learning to Recommend Driving Routes
image: /images/pairing.jpg
---
<div style="text-align: justify">
In this blog post, we talk about creating a smooth and effective experience for taxi drivers, by exploiting ML-as-a-service which scales machine learning to comply with service-level-agreements(SLAs). We designed an end-to-end data-driven workflow. It encompass establishing feature engineering pipeline from incoming streams of data, creating and updating models for estimations and producing metrics to weigh updated models. We use Pivotal’s data products such as Greenplum Database and Gemfire, and Cloud Foundry platform to analyze data, build & deploy models at scale, make predictions, and monitor accuracy to measure reliability at scale. In a nutshell, we showcase our strategy to build consistent and fail-safe channels to manage end-to-end ML tasks.
</div>
{{< responsive-figure src="/images/scaling-machine-learning-to-recommend-driving-routes/final_img_scale_ml_on_spark.png" class="center" height="42" width="42">}}
<p align="center">
 Figure 1. Driver earning prediction and next pickup location recommendation pipeline
</p>
### Driver earning prediction and next pickup location recommendation app
<div style="text-align: justify">
We built an app to predict potential earning of a driver given his current location for next 8 hours in successive time intervals. The App also provided recommendations of next best pickup locations ranked based on driver preferences and behavior. Potential earning per recommended locations is predicted for several time interval such as next 15 minutes, 30 minutes, one hour, two hours and four hours. This provided options to the user, which further helped in learning user behaviour. Our main aim was to maximize the revenue of the company by maximizing earnings per driver.

We leveraged a Hadoop cluster with HDFS for cold-store and Spark’s fast computing framework for data transformation logic, modelling, and deploying large-scale analytics. Greenplum Database (GPDB) is used to store structured feature vectors and batch predictions (for example, to display historical trends in average earnings across grids in past few days). Gemfire is used to cache near-real-time feature vectors and models and provide online predictions (such as earning predictions near a driver in the next 15 minutes).

### **Data Collection and Filtration**

We used Kafka to funnel data into Spark Streaming to ingest and transform incoming data and store in Data lake. Apart from the data from trips by users, data is also streamed from online weather service, third-party traffic and news services, processed by Spark.

The following data sources with specified attributes (partially provided by the customer and partially back-filled by us) are collected and manipulated via a cleaning and featurizing pipeline. The extracted features are further used in training models using Spark.
##### 1. ***Trips*** 
Trips dataset had a billion taxi trips from destination to a source with features such as pick-up and drop-off dates/times, pick-up and drop-off locations in GPS coordinates, trip distance, itemized fares, the rate per mile, payments including gratuity, and a total number of travellers. Each pair of longitude and latitude is considered as a grid point. A collection of grid points in a specified diameter is considered as a grid region. 
##### 2. ***Weather***
Weather dataset contained data at fifteen-minutes interval capturing weather statistics per grid-point, for previous four years with attributes such as precipitation, snow depth, temperature, and other available weather facts.
##### 3. ***Events, eta, route, and incidences***
We query a third-party proprietary routes API to determine the estimated ETA between each source and destination, get a route’s vector of coordinates along a route taken between grids, historical traffic incidents, traffic events along a route affecting traffic flow and intensity of incidence.
##### 4. ***Sentiment scores on news events***
We query the news API to gather information on latest news headlines, short descriptions and sentiment scores for all news under traffic, travel, weather and other events categories for a grid location. We then analyze the headings and short descriptions to capture sentiment scores for entities mentioned in the news.
##### 5. ***User***
Explicit user preferences are learned such as desired shift start and end time and location, shift duration, break frequency, duration, and time desired earnings per day.

During the exploration phase, stratified samples of data in high, mild and low traffic regions revealed the true quality of data. Initially, the pipeline is generated on data partitioned across geographical regions or grid regions. Data had many missing events, incidents and sentiment scores, incomplete trips, noisy values of coordinates, passenger counts etc. Further, close similarities in weather conditions for long durations, and mild variations in incident reports across regions showed no significant signals. Correlations and similarities in variables are further examined to ensure signals are not noise.

After analyzing the distributions of various features, we formatted, removed outliers and noise. We generated a pipeline for data filtering by removing redundant and incomplete variables. To reduce dependency and ensure completeness in data, dedicated pipelines for each of the four aforementioned categories are build to execute in parallel across regions. This is to ensure data uniformity in the cleaning process. 

### **Feature Engineering** 

Feature generation pipeline further combine aggregates and transform filtered data. Using feature-templates features across grid-points at different grid granularities are generated. Data is imputed, standardized and/or binarized depending on feature type (categorical vs numerical). Transformed features per grid location included information from the trips (such as average pickup grid location, duration of the trip, fare, gratuity, trip-destination, etc.), weather data (i.e. precipitation, temperature etc.), sentiment-score vectors from news articles, and traffic conditions severity vectors along the route from start to end. We partitioned data per spatial and temporal characteristics using windows functions. 

Spark actions cached each generated feature matrix to HDFS for model training. The batch Spark jobs are scheduled to run at regular intervals each day to generate features based on newly streamed data. Using the same pipeline logic, feature vectors are generated and stored in GPDB for bulk predictions. 

User preference data is streamed to HDFS, which is further processed by Spark and pushed to Gemfire. Same feature pipeline updates feature matrix per user in Gemfire. Updates are either scheduled on a regular basis or are triggered by user activities. This is to service recommendation serving containers at low latency.

We generated pipelines in Spark to create feature ‘deltas’, which are extreme changes over time to provide triggers for model generation pipeline. These deltas capture significant changes and trends in traffic, weather conditions, and passenger counts per region. This is simple and efficient and works very well for historical features which need to be updated only a few times during the day such as for generating a heat map of weather conditions over past few weeks or days.

This reproducible pipeline of data collection, formatting, performing quality checks, transformations, and feature generation is fed to train models via Spark jobs. This same pipeline is used to precompute real-time feature vectors per user (such as average-wait-time per pick up over a time window) to ensure consistency in model inputs at scoring.

### **Model Training** 

After feature generation, models are trained, tuned, and configured for performance. We build modelling jobs to consume generated features to train models using Jupyter notebook which encapsulates the training logic. Using Spark, Yarn, and an HDFS-based cluster, the distributed model training scaled up to billions of data points. 

Spatial and temporal features are used to built models for estimating the earnings in the future time intervals for each grid perimeter. Models are trained at five granularity levels of grid-points defined by grid diameters (such as 2, 5, 10, 15, 20 miles). This would failsafe scenarios where models at finer granularity level couldn’t produce. Scenarios such as delay in real-time feature processing, or third party service breakdowns result in incomplete feature-vectors. An unavailability of a finer model alternates to the next available model higher in grid granularity level (e.g. if a finer model for a grid point trained for a 2-miles-level is unavailable, prediction logic fallbacks to models at 5-miles-level).

Both Random-Forest and Gradient-Boosted Trees performed well at different granularity levels.  Random Forest ensembles performed second best in accuracy. Accuracy is measured by RMSE and R-squared. The results of each modelling task are stored in  Greenplum Database (GPDB) indexed by grids, their granularity levels, and prediction time-slot window. Information such as learned parameters of the models, model configurations (used features, feature tables, hyper-parameters), a sampled ordered array of feature-vector, training kick-off and completion time and model accuracy are stored in GPDB. 

Further, models are tuned to adapt to newer data. We configured Spark jobs to run modelling at regular intervals across grids. Apart from schedulers executing training jobs, jobs are time and event triggered by severe weather conditions and traffic-incident alerts or by ‘delta’ feature matrix. 

### **Model Deployment and Prediction**

For generating batch predictions across grids, we used Gradient Boosted models deployed in containers and run in Spark jobs. A change in the version or timestamp of previously loaded model triggers a change in the model used for predictions. Thereafter, a script updates model containers with latest model, configurations and timestamp. Each update triggers a pipeline to update predictions and feature vectors in Greenplum and downstream in Gemfire. Predictions are stored in Greenplum and are pushed back to HDFS for future training and evaluation tasks. Each prediction record is augmented with model id and last update time to ensure current state of the system. As data grows, we add more spark executors and Hadoop node to leverage cluster memory.

Grid predictions at and around user’s locations are used to generate heat maps for users. This data is cached in aggregated form in Gemfire by another job. This is used to generate a heatmap of earnings and traffic trends in a region. 

For real-time deployment, we created automated scripts to build model artifacts, deploy to real-time production prediction service clusters, where prediction containers automatically load new models from GPDB to service client requests. These containers referenced GPDB to load pre-computed feature data from data pipeline and Gemfire to compute near real-time User features and then fed to model for real-time scoring. 

#### **Recommendations** 

A recommendations list of top eight locations based on user profile or explicit preferences (e.g. work duration, desired daily earning, other explicit preferences such as desired destination at end of a shift) as well as past user activities and implicit user behaviour (e.g. break schedules, break durations, previously visited grid locations, passenger pickup and dropoff proximity to trip-start source and trip-end destination) is generated. The feature vectors are combined with real-time predictions and similarity scores to other users which are stored in GPDB. These are generated for each future time-slot to provide work schedules per user and stored in Gemfire. Gemfire caches 6 recommendations list per user, based on his current location and next best 5 grid locations with estimates of earnings in each location in a future time-window. 

Recommendation serving container queries Gemfire cache to get freshly updated lists of recommendations both periodically as well as on basis of triggers. Triggers are generated by deflections in user activities such as route-deflections. 

The app provided near real-time recommendations. A near real-time experience is delivered to ensure the customer needs are accommodated as more data streams of a driver’s behaviour such as current route, surrounding weather, news and traffic forecasts are learned. The recommendation list is updated frequently with the next best destinations from the current pickup location, which maximizes earnings and hence the revenue of the company.

### **Evaluation and Monitoring predictions pipeline**

For each model, previous predictions per grid are utilized for evaluating the model performance in GPDB. These are compared with actual values stored by data pipeline on User behaviour and earnings by computing MSEs and deviations from User vectors. A negative performance of the new model at finer grid prompts a model at higher grid level to override predictions at finer grid or if using the same feature matrix, provide predictions for finer grid data. This hierarchical approach of overwriting predictions at finer grids using higher level models is followed, if models at finer grids continue to perform poorly or simply fail to exist. 

If a similar situation arises at the highest grid, we use nearest neighbours data table. The nearest neighbour of the highest grid is chosen to be similar in weather, traffic and past earnings feature vectors for the time-of-the-day and day-of-the-year parameters. Models and predictions for neighbours at the highest grids are used as a proxy to evaluate newly generated models and predictions. We choose to take an average of those predictions to reflect true performance. In case the highest level is not available or similar grids are not available we switch back to generating predictions from previous models to ensure the performance at least as seen before. 
### **Conclusion and Next Steps**

By developing an end-to-end ML-as-a-service pipeline, we enabled clients to build scalable data pipelines, analyze, build and deploy models to production at scale. The strategy for seamless model updates will lay grounds for further A/B testing of models and corresponding recommendations. Online models and scoring can be scaled by simply adding more nodes in production cluster.

Similar scalable pipelines can be generated for use cases involving Fraud Detection, Spam Detection, Portfolio Selection or Online ad placement. Open source tools and technologies like Hadoop, Spark, Greenplum and Geode (Gemfire), are key components for analytics-driven applications on big data.  Learn more about Data Science at Pivotal and embark on the journey of becoming a data-driven company with us.
