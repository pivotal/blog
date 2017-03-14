---
authors:
- gtam
categories:
- HAWQ
- GPDB
- Big Data
- PostgreSQL
- Postgres
- MPP
- Histogram
- Scatter Plot
- ROC Curve
date: 2017-03-14T17:47:48-05:00
short: A tutorial on how to build histograms, scatter plots, and ROC curves using an MPP database and plot them in Python or R.
title: Plotting Using an MPP Database
---

Data visualization is the process of transforming and condensing data into an easily digestible graphic. It is crucial in helping data scientists understand their data and share their insights with others. With the recent surge of big data, data scientists must adapt their current techniques of visualizing data since traditional methods of plotting are limited by the machine's memory and thus only work on smaller, local data. This blog introduces methods of plotting to generate histograms and scatterplots—two of the most common ways to visualize univariate and bivariate data—in an MPP database such as <a href="https://pivotal.io/pivotal-greenplum">Pivotal Greenplum (GPDB)</a> or <a href="http://hawq.incubator.apache.org/">Apache HAWQ (incubating)</a> or in <a href="https://www.postgresql.org/">PostgreSQL</a>. Additionally, we will show how to compute an ROC curve, a plot which measures performance of a binary classifier, in-database. 

## MPP Histogram
Histograms are visual representations of the distribution of univariate data. They are created by grouping data into bins and plotting the number of observations that falls into each bin. If the amount of data we wish to plot is too large, we would not be able to use standard histogram functions that come in Python or R. However, because a histogram is a summary of the data, comprising of bin locations and heights, we can perform the legwork to compute these in database by using the parallel capabilities of GPDB or HAWQ. The desired output table, which can be plotted in Python or R, will be much smaller than the original data; it will only contain columns indicating the bin locations and heights.

We can achieve the task of mapping the data to their bins in three distinct steps:
<ol>
<li>Scale our data to range from 0 to the desired number of bins.</li>
<li>Take the floor function of our scaled data to discretize them into distinct groups.</li>
<li>Scale our data back to its original scale.</li>
</ol>

One caveat we must be wary about is that if our data point takes the maximum value for that variable, it may be put into a bin by itself. We account for this by placing it in the second to last bin.

This set of steps can be summarized in a single formula:
{{<responsive-figure src="/images/mpp-plotting/bin_loc_formula.png" class="center">}}

Now that we have created our bin numbers, we can group by the bin locations and heights. Template code to illustrate this process is shown below (note that the `DISTRIBUTED` clause does not exist in PostgreSQL, so if using PostgreSQL, please omit the final line):

```
CREATE TABLE histogram_values
     AS WITH min_max_table AS
             (SELECT MIN(column_name) AS min_val,
                     MAX(column_name) AS max_val
                FROM table_name
             ),
             binned_table AS
             (SELECT CASE WHEN column_name < max_val
                               THEN FLOOR((column_name - min_val)::NUMERIC
                                          /(max_val - min_val)
                                          * nbins
                                         )
                                    /nbins * (max_val - min_val) 
                                    + min_val
                          WHEN column_name = max_val
                               THEN (nbins - 1)::NUMERIC/nbins * (max_val - min_val) 
                                    + min_val
                          ELSE NULL
                           END AS bin_loc
                FROM table_name
                     CROSS JOIN min_max_table
               WHERE column_name IS NOT NULL
             )
      SELECT bin_loc, COUNT(*) AS bin_height
        FROM binned_table
       GROUP BY bin_loc
       ORDER BY bin_loc
 DISTRIBUTED BY (bin_loc);
```

We replace `column_name` and `table_name` with their appropriate names and `nbins` with an integer value. The resulting table will have two columns—the bin number and its frequency, i.e., the number of observations that fall into that bin number. All of the bins have the same width and are spread out evenly.


### Plotting MPP Histograms in Python
Using this information, we can then plot bar charts to create our histogram. In Python, we can pull the `histogram_values` table locally via the <a href="http://initd.org/psycopg/">psycopg2</a> library. We can run the following code assuming `conn` is our psycopg2 connection object that is pointing to GPDB or HAWQ and `psql` is the alias for the `pandas.io.sql` module:

```
sql = '''
SELECT *
  FROM histogram_values
 ORDER BY bin_loc;
'''
py_hist_df = psql.read_sql(sql, conn)
```

This data can then be used to plot a histogram using <a href="http://matplotlib.org/">matplotlib</a> where `plt` is the alias for the `matplotlib.pyplot` module.

```
bin_width = py_hist_df.bin_loc.diff().mean()

plt.figure(figsize=(10, 7))
plt.bar(py_hist_df.bin_loc, py_hist_df.bin_height,
        width=bin_width, edgecolor='black')
plt.title('matplotlib Histogram (Python)', size=26)
plt.xlabel('x-axis', size=22)
plt.ylabel('Frequency', size=22)
plt.xticks(size=14)
plt.yticks(size=14)
plt.tight_layout()
```

{{<responsive-figure src="/images/mpp-plotting/python_histogram.png" class="center">}}
<center><em>Figure 1: MPP Histogram in Python</em></center>

### Plotting MPP Histograms in R
We can follow this same procedure in R by using the <a href="https://cran.r-project.org/web/packages/RPostgreSQL/index.html">RPostgreSQL</a> library to bring data from GPDB or HAWQ locally and using <a href="http://docs.ggplot2.org/current/">ggplot2</a> or R’s default plotting library to plot the histograms.

```
sql <- "
SELECT *
  FROM histogram_values
 ORDER BY bin_loc;
"
r_hist_df <- dbGetQuery(conn, sql)
```

Again, `conn` is a <a href="https://cran.r-project.org/web/packages/DBI/DBI.pdf">DBIConnection</a> object in R that is pointing to GPDB or HAWQ. This pulls in data in the same manner as before. Now, we can plot our histogram using `ggplot`.

```
# Since all bin widths are the same, we can define 
# them by the distance between the first two points
plot_bin_width <- r_hist_df$bin_loc[2] - r_hist_df$bin_loc[1]

ggplot(r_hist_df, aes(bin_loc, weight = bin_height)) +
  geom_histogram(binwidth = plot_bin_width, col = 'black', fill = 'dodgerblue2') +
  labs(title = 'ggplot Histogram (R)', x = 'x-axis', y = 'Frequency') +
  theme(plot.title = element_text(size = 26, hjust = 0.5),
        axis.title.x = element_text(size = 22),
        axis.title.y = element_text(size = 22),
        axis.text.x = element_text(size = 14), 
        axis.text.y = element_text(size = 14)
       )
```

{{<responsive-figure src="/images/mpp-plotting/R_histogram.png" class="center">}}
<center><em>Figure 2: MPP Histogram in R</em></center>

## MPP Scatter Plot
Scatter plots differ from histograms in that they do not condense data, that is, we must plot each point individually. However, there will likely be many overlapping points if the data set is very large. Trying to plot this is inefficient because many points will be hidden under others. A more economical solution would be to group by bin number as we did for histograms. We can achieve this using the same technique, but instead group by bin numbers in both the x and y directions.

The resulting table would have three columns—the bin number in the x direction, the bin number in the y direction, and the frequency. We can visualize this by plotting the bin locations with partial transparency. Areas of lower density would be be more transparent and areas of higher density would be more opaque. We can use a similar query as before, but add another bin column to account for the added dimension.

### Plotting MPP Scatter Plots in Python
We pull in our condensed data into Python as before.
```
sql = '''
SELECT *
  FROM scatter_plot_values
 ORDER BY scat_bin_x, scat_bin_y;
'''
py_scat_df = psql.read_sql(sql, conn)
```

Then we can make our plot using `matplotlib`’s `scatter` function.

```
# Manually specify color with opacity proportional to frequency
col = np.zeros((py_scat_df.shape[0], 4))
# Set to blue
col[:, :3] = (0.29, 0.44, 0.69)
# Add transparency
col[:, 3] = py_scat_df.freq/py_scat_df.freq.max()

plt.scatter(py_scat_df.scat_bin_x, py_scat_df.scat_bin_y, c=col, lw=0)
plt.title('matplotlib Scatter Plot (Python)', size=26)
plt.xlabel('x variable', size=22)
plt.ylabel('y variable', size=22)
plt.xticks(size=14)
plt.yticks(size=14)
plt.tight_layout()
```

{{<responsive-figure src="/images/mpp-plotting/python_scatter_plot.png" class="center">}}

<center><em>Figure 3: MPP Scatter Plot in Python</em></center>

### Plotting MPP Scatter Plots in R
The steps to do this in R are analogous.

```
sql <- "
SELECT *
  FROM scatter_plot_values
 ORDER BY scat_bin_x, scat_bin_y;
"
r_scat_df <- dbGetQuery(conn, sql)
```

We can also use `ggplot` to create a similar plot.

```
ggplot(r_scat_df, aes(scat_bin_x, scat_bin_y, alpha = freq)) +
  geom_point(col = 'dodgerblue2') +
  labs(title = 'ggplot Scatter Plot (R)', x = 'x variable', y = 'y variable') +
  theme(plot.title = element_text(size = 26, hjust = 0.5),
        axis.title.x = element_text(size = 22),
        axis.title.y = element_text(size = 22),
        axis.text.x = element_text(size = 14), 
        axis.text.y = element_text(size = 14),
        legend.title = element_text(size = 18),
        legend.text = element_text(size = 16)
       )
```

{{<responsive-figure src="/images/mpp-plotting/R_scatter_plot.png" class="center">}}
<center><em>Figure 4: MPP Scatter Plot in R</em></center>

### ROC Curve
An ROC curve is a plot we can use to measure the performance of a binary classifier. It is created by computing the true and false positive rate for every possible threshold value. This computation may not be possible locally if the data is too large. Suppose we have a table named `model_scores` that contains all of the true labels, `y_true`, and the predicted probabilities, `y_score`, we can compute the ROC curve values in-database using the following code:

```
CREATE TABLE roc_curve_values
     AS WITH row_num_table AS
             (SELECT row_number()
                         OVER (ORDER BY y_score) AS row_num, *
                FROM model_scores
             ),
             pre_roc AS 
             (SELECT *,
                     SUM(y_true)
                         OVER (ORDER BY y_score DESC) AS num_pos,
                     SUM(1 - y_true)
                         OVER (ORDER BY y_score DESC) AS num_neg
                FROM row_num_table
             ),
             class_sizes AS
             (SELECT SUM(y_true) AS tot_pos,
                     SUM(1 - y_true) AS tot_neg
                FROM model_scores
             )
      SELECT DISTINCT
             y_score AS thresholds,
             num_pos/tot_pos::NUMERIC AS tpr,
             num_neg/tot_neg::NUMERIC AS fpr
        FROM pre_roc
             CROSS JOIN class_sizes
 DISTRIBUTED BY (thresholds);
```

We achieve this by using window functions to sort the observations by their score and taking the sum of `y_true` and  `1 - y_true`. This produces two columns—`num_pos` and `num_neg`—which represent the number of predicted positive and negative observations in the model given that the threshold is equal to `y_score`. We can then take these numbers and divide by the number of total positive and negatives respectively to get the true and false positive rates. 

Bringing this table locally and sorting by threshold, we can form the ROC curve by plotting these two rates against each other.

{{<responsive-figure src="/images/mpp-plotting/MPP_ROC_curve.png" class="center">}}
<center><em>Figure 5: MPP ROC Curve</em></center>

## AUC Score
The ROC score is a diagnostic check to assess the performance of a binary classifier, but we cannot use it to directly compare different classifiers. To do that, we can use the AUC (area under the curve) statistic, which is precisely the area underneath the ROC curve. We can compute this by summing up the area of the trapezoids formed by successive points along the ROC curve.

```
  WITH roc_trapezoids AS
       (SELECT *,
               AVG(tpr)
                   OVER (ORDER BY thresholds DESC
                          ROWS BETWEEN 1 PRECEDING
                           AND CURRENT ROW
                        ) AS avg_height,
               fpr - LAG(fpr, 1)
                   OVER (ORDER BY thresholds DESC)
                   AS width
          FROM roc_curve_values
         ORDER BY thresholds DESC
       )
SELECT SUM(avg_height * width) AS auc_score
  FROM roc_trapezoids;
```

As of the most recent version of MADlib (v1.9.1), there are built-in functions to get the ROC curve and AUC score. However, older versions of MADlib or PostgreSQL will not provide such functionality.

## Next Steps
In this blog, we have outlined a basic set of steps to generate histograms and scatter plots in an MPP database. They are useful for exploring univariate and bivariate data before modeling or for visualizing results after modeling. We have also shown how to compute an ROC curve in-database. This is an important tool to use after modeling. We can extend this procedure of doing heavy computation in-database, then plotting locally to many other types of plots. For reusable code that defines functions to perform these plots, please refer to <a href="https://github.com/gregtam/mpp-plotting">https://github.com/gregtam/mpp-plotting</a>.
