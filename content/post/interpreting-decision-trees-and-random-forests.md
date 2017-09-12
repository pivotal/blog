---
authors:
- gtam
categories:
- Decision Tree
- Random Forest
- Data Science
date: 2017-09-12
draft: true
short: This blog dives deeper into the fundamentals of decision trees and random forests to better interpret them.
title: Interpreting Decision Trees and Random Forests
---

The random forest has been a burgeoning machine learning technique in the last few years. It is a non-linear tree-based model that often provides accurate results. However, being mostly black box, it is hard to interpret and fully understand. In this blog, we will deep dive into the fundamentals of random forests to better grasp them. We start by looking at the decision tree—the building block of the random forest. This work is an extension of the work done by Ando Saabas (https://github.com/andosa/treeinterpreter).

## How Do Decision Trees Work?
Decision trees work by iteratively splitting the data into distinct subsets in a greedy fashion. For regression trees, they are chosen to minimize either the MSE (mean squared error) or the MAE (mean absolute error) within all of the subsets. For classification trees, the splits are chosen so as to minimize entropy or Gini impurity in the resulting subsets.

The resulting classifier separates the feature space into distinct subsets. Predictions are made based on which subset an observation falls into.

{{<responsive-figure src="/images/interpreting-decision-trees-and-random-forests/dt_iterations.png" class="center">}}
<center><em>Figure 1: Iterations of a Decision Tree</em></center>

Decision Tree Contributions
Let's use the abalone data set as an example. We will try to predict the number of rings based on variables such as shell weight, length, diameter, etc. We will fit a shallow decision tree for illustrative purposes.

{{<responsive-figure src="/images/interpreting-decision-trees-and-random-forests/reg_dt_path.png" class="center">}}
<center><em>Figure 2: Decision Tree path for number of rings prediction</em></center>

To predict the number of rings for an abalone, a decision tree will traverse down the tree until it reaches a leaf. Each step splits the current subset into two. For a specific split, the contribution of the variable that determined the split is defined as the change in mean number of rings.

For example, if we take an abalone with a shell weight of 0.02 and a length of 0.220, it will fall in the left-most leaf, with a predicted number of rings as 4.4731. Shell weight will have a contribution of

Length will have a contribution of

These negative contributions imply that the shell weight and length values for this particular abalone drive its predicted number of rings down.

We can get these contributions by running the following code:

```
from treeinterpreter import treeinterpreter as ti
dt_reg_pred, dt_reg_bias, dt_reg_contrib = ti.predict(dt_reg, X_test)
```

The contributions variable, `dt_reg_contrib`, is a 2d numpy array with dimensions (`n_obs`, `n_features`), where `n_obs` is the number of observations and `n_features` is the number of features.

We can plot these contributions for a given abalone to see which features most impact its predicted value.

{{<responsive-figure src="/images/interpreting-decision-trees-and-random-forests/contribution_plot_dt_reg.png" class="center">}}
<center><em>Figure 3: Decision Tree contribution plot for one example</em><center>

We can compare this particular abalone’s contributions to the entire population by using violin plots.


{{<responsive-figure src="/images/interpreting-decision-trees-and-random-forests/contribution_plot_violin_dt_reg.png" class="center">}}
<center><em>Figure 4: Decision Tree contribution plot with violin for one example</em></center>

These plots, while insightful, still do not give us a full understanding on how a specific variable affects the number of rings an abalone has. Instead, we may plot a given feature's contribution against its values.


{{<responsive-figure src="/images/interpreting-decision-trees-and-random-forests/contribution_plot_violin_dt_reg.png" class="center">}}
<center><em>Figure 4: Decision Tree contribution plot with violin for one example</em></center>

{{<responsive-figure src="/images/interpreting-decision-trees-and-random-forests/shell_weight_contribution_dt.png" class="center">}}
<center><em>Figure 5: Decision Tree contribution vs. shell weight plot</em></center>

{{<responsive-figure src="/images/interpreting-decision-trees-and-random-forests/shucked_weight_contribution_dt.png" class="center">}}
<center><em>Figure 6: Decision Tree contribution vs. shucked weight plot</em></center>

Now, we can see the number of rings increase with shell weight. Shucked weight, on the other hand, has a non-linear, non-monotonic relationship with the number of rings.

## Extending to Random Forests
This process of determining the contributions can naturally be extended to Random Forests by taking the mean contribution for a variable across all trees.


{{<responsive-figure src="/images/interpreting-decision-trees-and-random-forests/contribution_plot_violin_rf.png" class="center">}}
<center><em>Figure 7: Random Forest contribution plot with violin for one example</em></center>

{{<responsive-figure src="/images/interpreting-decision-trees-and-random-forests/shell_weight_contribution_rf.png" class="center">}}
<center><em>Figure 8: Random Forest contribution vs. shell weight plot</em></center>

Now that we have injected a bit of randomness by using Random Forests, there can be variability in contribution for a given shell weight. However, the increasing trend still remains as shown by the smoothed black trend line.

Again, we may see more complicated, non-monotonic trends.
{{<responsive-figure src="/images/interpreting-decision-trees-and-random-forests/diameter_contribution_rf.png" class="center">}}
<center><em>Figure 9: Random Forest contribution vs. for diameter plot</em></center>

Diameter appears to have a dip in contribution at about 0.45 and a peak in contribution around 0.3 and 0.6. Apart from that, there seems to be a general increasing relationship between diameter and number of rings.

## Classification
We have shown that feature contribution for regression trees is derived from the mean number of rings and how it changes at successive splits. We can extend this to binomial and multinomial classification by looking instead at the percentage of observations of a certain class within each subset. The contribution for a feature is the total change in the percentage caused from that feature.

This is more easily explained with an example. Suppose we instead are trying to predict sex, i.e., whether the abalone is a female, male, or an infant.

{{<responsive-figure src="/images/interpreting-decision-trees-and-random-forests/contribution_plot_violin_multi_clf_dt.png" class="center">}}
<center><em>Figure 10: Decision Tree path for multinomial classification</em></center>

Each node has 3 values—the percentage of abalones in the subset that are female, male, and infants respectively. An abalone with a viscera weight of 0.1 and a shell weight of 0.1 would end up in the left-most leaf (with probabilities of 0.082, 0.171, and 0.747). The same logic of contributions for regression trees applies here.

The contribution of viscera weight to this particular abalone being in infant is:

And the contribution of shell weight is:


We can plot a contribution plot for each class. Below, we have shown one such plot for the infant class.


{{<responsive-figure src="/images/interpreting-decision-trees-and-random-forests/contribution_plot_violin_multi_clf_dt.png" class="center">}}
Figure 10: Contribution plot for infant class in multi-class Decision Tree

And as before, we can also plot the contributions vs. the features for each class

{{<responsive-figure src="/images/interpreting-decision-trees-and-random-forests/shell_weight_contribution_by_sex_rf.png" class="center">}}
Figure 11: Contribution vs. shell weight for each class (Random Forest)

## Final Thoughts
We have shown in this blog that by looking at the paths, we can gain a deeper understanding of decision trees and random forests. This is especially useful since random forests are an embarrassingly parallel, typically high performing machine learning model. By interpreting them better, its value increases.
