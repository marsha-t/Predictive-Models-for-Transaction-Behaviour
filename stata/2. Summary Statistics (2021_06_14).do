//------------------------------------------------------------------------------
// Housekeeping: Clear previous variables and set session parameters
//------------------------------------------------------------------------------
clear all
set more off

// Set working directory to relative path for portability
cd "project_folder\data"

//------------------------------------------------------------------------------
// Summary Statistics - Full Individual Level 
//------------------------------------------------------------------------------
use temp\topup_merged_v1v2, clear

// Define output file for summary statistics
local filename "sumstats\sumstats_v3.xls"

// Summary statistics over time for hardcopy and softcopy transactions
tabstat hardcopy if hardcopy == 1, by(yr) stat(n) save 
tabstatmat hardcopy_yr_hard
tabstat hardcopy if hardcopy == 0, by(yr) stat(n) save 
tabstatmat hardcopy_yr_soft

// Export summary statistics to Excel
putexcel set `filename', sheet(hard_yr) modify
putexcel A1 = ("Hardcopy by Year")
putexcel A3 = matrix(hardcopy_yr_hard) , names
putexcel D4 = matrix(hardcopy_yr_soft)
putexcel A3 = ("Hardcopy")
putexcel D3 = ("Softcopy")

// Sequence analysis for transactions
cap noi log close
log using log\hardcopy_sequence_1720v2, replace 
	use temp\topup_trnsv2, clear
	drop if trns_yr < 2017
	sort tppr_acct_num trns_dte
	bys tppr_acct_num: g order = _n
	bys tppr_acct_num: g dup = _N
	
	sqset hardcopy tppr_acct_num order
	sqtab if dup > 1, so 
log close 

log using log\hardcopy_sequence_1719v2, replace 
	use temp\topup_trnsv2, clear
	drop if trns_yr < 2017 | trns_yr > 2019
	sort tppr_acct_num trns_dte
	bys tppr_acct_num: g order = _n
	bys tppr_acct_num: g dup = _N
	
	sqset hardcopy tppr_acct_num order
	sqtab if dup > 1, so 
log close 

//------------------------------------------------------------------------------
// Summary Statistics - Hardcopy/Softcopy Only Individual Level 
//------------------------------------------------------------------------------
use temp\topup_merged_analysisv2, clear
local filename "sumstats\sumstats_v3.xls"

// Calculate summary statistics for the selected variables, by hardcopy status
local tabstat_var "age  female  osra_bal_amt  topup_all_amt_tot  topup_all_num   mltp_lst_con_wge "		
tabstat `tabstat_var', stat(n mean median min max) by(hardcopy) save 
tabstatmat matrix_t

// Export summary statistics for the selected variables to Excel
putexcel set `filename', sheet(tabstat_var) modify
putexcel A3 = matrix(matrix_t), names

// Frequency tables for categorical variables by hardcopy status
local tab_var " topup_all_num_cat  close_cpf  emp_status "
foreach var in `tab_var' { 
	tab `var' hardcopy, missing matcell(`var'_freq) matrow(`var'_row)
	putexcel set `filename', sheet(`var') modify
	
	putexcel A1 = ("`var'")
	putexcel A2 = matrix(`var'_row)
	putexcel B2 = matrix(`var'_freq)

}

//------------------------------------------------------------------------------
// Summary Statistics - Individual Level (Hard/Soft/Mixed)
//------------------------------------------------------------------------------
use temp\topup_merged_analysis_mixed, clear

// Define topper category based on hardcopy/softcopy status
g topper = 1 if only_hardcopy == 1 
replace topper = 2 if only_softcopy == 1
replace topper = 3 if only_softcopy != 1 & only_hardcopy !=1 

local filename "sumstats\sumstats_v3.xls"

// Calculate and export summary statistics by topper category (hardcopy, softcopy, mixed)
local tabstat_var "age  female  osra_bal_amt  topup_all_amt_tot  topup_all_num   mltp_lst_con_wge "		
tabstat `tabstat_var', stat(n mean median min max) by(topper) save 
tabstatmat matrix_t

putexcel set `filename', sheet(tabstat_var_m) modify
putexcel A3 = matrix(matrix_t), names

// Frequency tables for categorical variables by topper category
local tab_var " topup_all_num_cat  close_cpf  emp_status "
foreach var in `tab_var' { 
	tab `var' topper, missing matcell(`var'_freq) matrow(`var'_row)
	putexcel set `filename', sheet(`var'_m) modify
	
	putexcel A1 = ("`var'")
	putexcel A2 = matrix(`var'_row)
	putexcel B2 = matrix(`var'_freq)

}
	