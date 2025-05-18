//------------------------------------------------------------------------------
// Housekeeping: Clear previous variables and set session parameters
//------------------------------------------------------------------------------
clear all
set more off

// Set working directory to relative path for portability
cd "project_folder\data"

//------------------------------------------------------------------------------
// Logistic Regressions: Perform logistic regressions on hardcopy as the dependent variable
//------------------------------------------------------------------------------
use temp\topup_merged_analysisv2, clear

// Generate log-transformed OSRA balance for use in models

g l_osra_bal_amt = ln(osra_bal_amt)
local base_var "i.female  age  i.race " 
local base_var2 "i.female age"
local rstu_var "topup_all_amt_tot   i.topup_all_num_cat "  
local empl_var "i.emp_status  mltp_lst_con_wge  "
local cpfb_var "l_osra_bal_amt"
local addr_var "i.close_cpf  "
	
// Version 1: Run logistic regression using the full set of variables
logit hardcopy `base_var' `rstu_var' `empl_var' `cpfb_var' `addr_var'
outreg2 using "reg\v2logit_indiv_1720.xls", excel nocons ctitle(v1) nose replace
margins, atmeans  // Marginal effects at the mean
margins, dydx(*) post  // Calculate marginal effects for all predictors
outreg2 using "reg\v2logit_indiv_1720_ame.xls", excel nocons ctitle(v1) nose replace

// Version 2: Run logistic regression with a simplified model (without race)
logit hardcopy `base_var2' `rstu_var' `empl_var' `cpfb_var' `addr_var'
outreg2 using "reg\v2logit_indiv_1720.xls", excel nocons ctitle(v2) nose append
margins, atmeans
margins, dydx(*) post
outreg2 using "reg\v2logit_indiv_1720_ame.xls", excel nocons ctitle(v2) nose append

// Version 3: Run logistic regression adding `topup_all_amt_mean` to the model
logit hardcopy `base_var2' `rstu_var' topup_all_amt_mean `empl_var' `cpfb_var' `addr_var'
outreg2 using "reg\v2logit_indiv_1720.xls", excel nocons ctitle(v3) nose append
margins, atmeans
margins, dydx(*) post
outreg2 using "reg\v2logit_indiv_1720_ame.xls", excel nocons ctitle(v3) nose append
	
		

//------------------------------------------------------------------------------
// Check whether wages no longer sig with other cov added in 
//------------------------------------------------------------------------------
use temp\topup_merged_analysisv2, clear

// Logistic regression with age and wage as predictors
logit hardcopy age mltp_lst_con_wge // Check significance

// Add employment status and check again
logit hardcopy age i.emp_status mltp_lst_con_wge // Check significance with employment status

// Add gender to check if it affects the results
logit hardcopy i.female age i.emp_status mltp_lst_con_wge // Check for insignificance

// Re-run without gender to confirm the result
logit hardcopy i.female i.emp_status mltp_lst_con_wge 

// Descriptive statistics for `mltp_lst_con_wge` by gender and hardcopy status
tabstat mltp_lst_con_wge if female == 1, by(hardcopy)
tabstat mltp_lst_con_wge if female == 0, by(hardcopy)

// Descriptive statistics for `mltp_lst_con_wge` by employment status and hardcopy status
tabstat mltp_lst_con_wge if emp_status == 1, by(hardcopy)
tabstat mltp_lst_con_wge if emp_status == 2, by(hardcopy)
tabstat mltp_lst_con_wge if emp_status == 3, by(hardcopy)
	