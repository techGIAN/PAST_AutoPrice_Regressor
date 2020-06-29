/* Import the Dataset */
title "Auto Price Dataset";
data auto;
infile '/folders/myfolders/data/auto.csv' dlm=',' firstobs=2;
input id x1$ x2$ x3$ x4$ x5$ x6$ x7$ x8$ x9 x10 x11 x12
		x13 x14$ x15$ x16 x17$ x18 x19 x20 x21 x22
		x23 x24 y;
drop x1--x4 x6 x8 x14 x15 x17;	/*	Initially drop some categorical variables	*/

/* Create dummy variables for the remaining categorical variables */
title "Dummy Variables";
data auto_dummy;
	set auto;
	/* Changing "four" and "two" to numerical */
	if x5 = "four" then do; 
		x5temp = 4;
	end; 
	else if x5 = "two" then do; 
		 x5temp = 2;
	end;
	drop x5;
	rename x5temp = x5;
	
	/* Creating dummy variables for x7 */
	/* x74wd = 4-wheel drive */
	/* x7rwd = rear-wheel drive */
	/* x7fwd = front-wheel drive */
	if x7 = "4wd" then do; 
		x74wd = 1; x7rwd = 0; x7fwd = 0;
	end; 
	else if x7 = "rwd" then do; 
		 x74wd = 0; x7rwd = 1; x7fwd = 0;
	end;
	else if x7 = "fwd" then do; 
		 x74wd = 0; x7rwd = 0; x7fwd = 1;
	end;
	drop x7;
run;

title "Dropping Variables";
data auto_drop;
	set auto_dummy;
	/* Drop the variables here */
	drop x7fwd x24 x23 x13 x18 x19 x22;
	
	/* Move the dependent variable to the end */
	tempY = y;
	drop y;
	rename tempY = y;

/* Create pairwise interaction terms based on the remaining variables */
/* Any higher order terms added in are in here. */
title "Interaction Terms and Higher Order";
data auto_function;
	set auto_drop;
	x16x11 = x16*x11;
	x16x20 = x16*x20;
	x16x21 = x16*x21;
	x16x74wd = x16*x74wd;
	x16x7rwd = x16*x7rwd;
	
	x11x20 = x11*x20;
	x11x21 = x11*x21;
	x11x74wd = x11*x74wd;
	x11x7rwd = x11*x7rwd;
	
	x20x21 = x20*x21;
	x20x74wd = x20*x74wd;
	x20x7rwd = x20*x7rwd;
	
	x21x74wd = x21*x74wd;
	x21x7rwd = x21*x7rwd;

	/* Want the dependent y variable to be in the last column. */
	tempY = y;
	drop y;
	rename tempY = y;

/* Split the data set into training and testing sets */
title "Data Split";
proc surveyselect data=auto_function rate=0.8 
	out= auto_select seed = 12345 outall 
	method=srs; 
run;
data auto_train auto_test;
	set auto_select; 
	if selected =1 then output auto_train;
	else output auto_test;
	drop selected; 
run;

/* Print the correlation matrix to check for any multicollinearities */
title "Correlation Matrix";
proc corr data=auto_train;
run;

/* Check for the Variance Inflation Factor to determine serious multicollinearities. */
title "Regression for VIFs";
proc reg data = auto_train; 
	model y = x9--x7rwd / p vif;
run;

/* Perform a preliminary screening on the importance of the IV's. */
title "Stepwise Regression";
proc stepwise data = auto_train;  
	model y = x9--x7rwd  / stepwise sle = 0.05 sls = 0.05; 
run;

/* Perform a second screening to know which of the interaction terms are significant. */
title "Stepwise Regression";
proc stepwise data = auto_train;  
	model y = x11 x16 x20 x21 x74wd x7rwd 
				x11x20 x11x21 x11x74wd x11x7rwd
				x20x21 x20x74wd x20x7rwd
				x21x74wd x21x7rwd
				x16x11 x16x20 x16x21
				x16x74wd x16x7rwd  / stepwise sle = 0.05 sls = 0.05; 
run;

/* Perform a Regression on the model obtained from Stepwise Regression */
title "Regression on Stepwise";
proc reg data = auto_train; 
	model y =  x11 x20 x21 x74wd x7rwd x21x7rwd x11x21 x16 x16x21;
run;

/* Get the R^2 Estimates */
title "R-Squares";
proc rsquare data=auto_train cp mse sse adjrsquare;
	model y = x11 x20 x21 x74wd x7rwd x21x7rwd x11x21 x16 x16x21;
run;

/* Check for Independence using the DW Testing */
title 'Dubrin-Watson Test';
proc reg data = auto_train; 
	model y=x11 x20 x21 x74wd x7rwd x21x7rwd x11x21 x16 x16x21/ p dw dwprob;
run;

/* Check for any outliers an influential points */
title 'Checking for Outliers and Influential Points';
proc reg data=auto_train outest=r;
	model y = x11 x20 x21 x74wd x7rwd x21x7rwd x11x21 x16 x16x21 / r influence; 
run; 
proc print data=r;
run;

/* Remove any outliers and influential points */
title "Remove Observations";
data auto_removed_train;
	set auto_train;
	if id=14 then delete;
	if id=16 then delete;
	if id=89 then delete;
	
	drop id;
run;

/* Perform a complete F-test on the overall model. */
title "Complete F-Test";
proc reg data = auto_removed_train;
	model y = x11 x20 x21 x74wd x7rwd x21x7rwd x11x21 x16 x16x21;
run;

/* Do a Hypothesis Testing */
title "Hypothesis Testing for b_j";
proc reg data=auto_removed_train;
	model y=x11 x20 x21 x74wd x7rwd x21x7rwd x11x21 x16 x16x21
				/alpha=0.05
				p
				clm
				cli;
run;

/* Based on the hypothesis testing, we check for the significance of x7 dummies. */
/* Use the partial F-test on the reduced model. */
title "Partial F-Testing - drop x74wd and x7rwd?";
proc reg data=auto_removed_train;
	model y=x11 x20 x21 x74wd x7rwd x11x21 x16 x16x21;
				pft: test x7rwd=0, x74wd=0;
run;
