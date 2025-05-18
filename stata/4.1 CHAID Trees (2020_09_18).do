//------------------------------------------------------------------------------
// Housekeeping: Clear previous variables and set session parameters
//------------------------------------------------------------------------------
clear all
set more off

// Set working directory to relative path for portability
cd "project_folder\data"

//------------------------------------------------------------------------------
// CHAID (Chi-squared Automatic Interaction Detection): Perform CHAID analysis on the data
//------------------------------------------------------------------------------
use temp\topup_merged_analysis, clear

//------------------------------------------------------------------------------
// CHAID - Transaction Level: Fit CHAID models at the transaction level
//------------------------------------------------------------------------------
use temp\rstu_sa_analysis_dropdup, clear

// Create a variable to indicate whether the top-up is linked to a CPF center
g topper_close_cpf = 0 if topper_cpf_centre == 0 
replace topper_close_cpf = 1 if topper_cpf_centre > 0 & topper_cpf_centre !=. 

// Create quantile bins for continuous variables
foreach x in topper_age amt topper_osra_bal_amt day_since topper_tot_wage{
	xtile xt`x' = `x', nquantiles(4) 
}
// Log the output of the CHAID models
log using log\dropdup_chaid_1719, replace 
set seed 500
// Fit CHAID models with different combinations of predictors
chaid hardcopy, unordered(topper_male topper_race relationship cash topper_close_cpf topper_emp_status) ordered(order_cat xttopper_age xtamt xttopper_osra_bal_amt xtday_since xttopper_tot_wage)
chaid hardcopy, unordered(topper_male topper_race relationship cash topper_close_cpf topper_emp_status) ordered(order_cat xttopper_age xtamt xttopper_osra_bal_amt)
chaid hardcopy, unordered(topper_male topper_race relationship cash topper_close_cpf topper_emp_status) ordered(order_cat)
chaid hardcopy, unordered(topper_male topper_race topper_close_cpf topper_emp_status) ordered(order_cat xttopper_age xtamt)
chaid hardcopy, unordered(topper_male topper_close_cpf topper_emp_status) ordered(order_cat xttopper_age xtamt)

// Close the log file
log close

//------------------------------------------------------------------------------
// CHAID - Individual Level: Perform CHAID at the individual level
//------------------------------------------------------------------------------
use temp\rstu_sa_analysis_dropdup_indiv, clear

// Log the output of the individual-level CHAID models
log using log\dropdup_chaid_indiv_1719, replace 
set seed 500

// Full model (chaid1)
chaid hardcopy, unordered(topper_male topper_race topper_close_cpf topper_emp_status) ordered(order_cat xttopper_age xttotal_amt xttopper_osra_bal_amt xttopper_tot_wage) //41 clusters
save temp\rstu_sa_analysis_dropdup_indiv_chaid1, replace

// Model without wage variable (chaid2)
chaid hardcopy, unordered(topper_male topper_race topper_close_cpf topper_emp_status) ordered(order_cat xttopper_age xttotal_amt xttopper_osra_bal_amt) //41 clusters
save temp\rstu_sa_analysis_dropdup_indiv_chaid2, replace

// Model without race variable (chaid3)
chaid hardcopy, unordered(topper_male topper_close_cpf topper_emp_status) ordered(order_cat xttopper_age xttotal_amt xttopper_osra_bal_amt xttopper_tot_wage) //44 clusters
save temp\rstu_sa_analysis_dropdup_indiv_chaid3, replace

// Model without race and wage variables (chaid4)
chaid hardcopy, unordered(topper_male topper_close_cpf topper_emp_status) ordered(order_cat xttopper_age xttotal_amt xttopper_osra_bal_amt) //46 clusters
save temp\rstu_sa_analysis_dropdup_indiv_chaid4, replace

log close

// Fit a CHAID model at the individual level with importance scores
use temp\rstu_sa_analysis_dropdup_indiv, clear
chaid hardcopy, unordered(topper_male topper_race topper_close_cpf  topper_emp_status) ordered(order_cat  xttopper_age  xttotal_amt  xttopper_osra_bal_amt  xttopper_tot_wage) importance 
save temp\rstu_sa_analysis_dropdup_indiv_chaid1, replace
	
//------------------------------------------------------------------------------
// CHAID - Individual Level - Summary Statistics: Generate and export summary statistics
//------------------------------------------------------------------------------
use temp\rstu_sa_analysis_dropdup_indiv_chaid1, clear

// Generate summary statistics for various variables by CHAID groups
tabstat topper_age xttopper_age order_cat total_amt xttotal_amt topper_tot_wage xttopper_tot_wage topper_osra_bal_amt xttopper_osra_bal_amt topper_race topper_emp_status topper_male topper_close_cpf, by(_CHAID) stat(n mean median min max) save
tabstatmat matrix_t

// Export the summary statistics to Excel
putexcel set "sumstats\\dropdup_chaid1sumstats.xls", sheet(tabstat_var) replace
putexcel A3 = matrix(matrix_t), names

// Generate and export additional summary statistics for employment status
tab topper_emp_status, g(topper_emp_status_)
tabstat topper_emp_status_1 topper_emp_status_2 topper_emp_status_3, by(_CHAID) stat(n mean median min max) save
tabstatmat matrix_t
putexcel set "sumstats\\dropdup_chaid1sumstats2.xls", sheet(tabstat_var2) replace
putexcel A3 = matrix(matrix_t), names

// Generate and export summary statistics for median and average amounts
tabstat median_amt avg_amt, by(_CHAID) stat(n mean median min max) save
tabstatmat matrix_t
putexcel set "sumstats\\dropdup_chaid1sumstats3.xls", sheet(tabstat_var3) replace
putexcel A3 = matrix(matrix_t), names
