//------------------------------------------------------------------------------
// Housekeeping: Clear previous variables and set session parameters
//------------------------------------------------------------------------------
clear all
set more off

// Set working directory to relative path for portability
cd "project_folder\data"

//------------------------------------------------------------------------------
// Variable Generation: Create and modify key variables for analysis
//------------------------------------------------------------------------------
use temp\topup_mergedv2, clear

// Dead: Flag members who have passed away based on the transaction date
g deadbytrns = (trns_dte > death_date)
tab deadbytrns
drop if deadbytrns == 1 // Drop deceased members
drop deadbytrns death_date

// Age at time of transaction
g age = yr - year(birth_date) if (mth > month(birth_date)) | (mth == month(birth_date) & day(trns_dte) >= day(birth_date))
replace age = yr - year(birth_date) -1 if (mth < month(birth_date)) | (mth == month(birth_date) & day(trns_dte) < day(birth_date))

// CPF Centre: Assign CPF center based on postal code and overseas address flag
replace cpf_centre = 0 if cpf_centre == . & postal_2d !=. 
replace cpf_centre = 0 if ad_overseas == 1 

// Close CPF flag: Assign flag based on whether member is close to CPF center
g close_cpf = 0 if cpf_centre == 0 
replace close_cpf = 1 if cpf_centre > 0 & cpf_centre !=. 

// OSRA Balance: Calculate total balance from multiple accounts
egen osra_bal_amt = rowtotal(oa_bal_amt sa_bal_amt ra_bal_amt)

// Missing values handling for top-up variables: Replace missing values with zero
drop topup_amt
foreach mode in all hard soft {
     replace topup_`mode'_num = 0 if topup_`mode'_num == .
     forval y = 2017/2020{
          replace topup_`mode'_num_`y' = 0 if  topup_`mode'_num_`y' ==.
     }
}

// Amounts handling: Replace missing values for amounts
foreach type in mean tot {
     foreach mode in all hard soft {
          replace topup_`mode'_amt_`type'= 0 if topup_`mode'_amt_`type' ==. 
          forval y = 2017/2020{
               replace topup_`mode'_amt_`type'_`y' = 0 if topup_`mode'_amt_`type'_`y' ==. 
          }
     }
}

// Top-up Number Categories: Create categories based on number of top-ups
g topup_all_num_cat = topup_all_num 
count if topup_all_num == . 
recode topup_all_num_cat (2/3=1) (4/5=2) (6/10=3) (11/.=4)
tabstat topup_all_num, by(topup_all_num_cat) stat(min max)
lab def topup_all_num_cat_lab 1 "2-3" 2 "4-5" 3 "6-10" 4 "11+"
lab val topup_all_num_cat topup_all_num_cat_lab

// Replace wage: Handle missing or invalid wages
replace mltp_lst_con_wge = 0 if mltp_lst_con_wge ==. 

// Quartiles: Divide key variables into quartiles
foreach y in age topup_all_amt_tot osra_bal_amt mltp_lst_con_wge {
	xtile xt`y' = `y', nquantiles(4) 
}

foreach y in topup_all_amt_mean {
	xtile xt`y' = `y', nquantiles(4) 
}

// Tabulate statistics for each variable by quartile
foreach y in age topup_all_amt_tot osra_bal_amt mltp_lst_con_wge topup_all_amt_mean{
	tabstat `y', by(xt`y') stat(min max)
}

save temp\topup_merged_v1v2, replace


//------------------------------------------------------------------------------
// Sample Restriction: Filter data based on top-up frequency
//------------------------------------------------------------------------------
use temp\topup_merged_v1v2, clear

// Keep only members with multiple top-ups
sum topup_all_num topup_hard_num topup_soft_num
keep if topup_all_num > 1 

// Create flags for members with only hardcopy or only softcopy top-ups
g only_hardcopy = (topup_soft_num == 0)
g only_softcopy = (topup_hard_num == 0)

keep if only_hardcopy == 1 | only_softcopy == 1 

// Flag for hardcopy transactions
g hard = 1 if only_hardcopy == 1 
replace hard = 0 if only_softcopy == 1

// Drop temporary flags
drop only_*

save temp\topup_merged_analysisv2, replace

//------------------------------------------------------------------------------
// Sample Restriction (Hard, Soft, Mixed): Separate members based on top-up type
//------------------------------------------------------------------------------
use temp\topup_merged_v1v2, clear

// Keep only members with multiple top-ups
sum topup_all_num topup_hard_num topup_soft_num
keep if topup_all_num > 1 

g only_hardcopy = (topup_soft_num == 0)
g only_softcopy = (topup_hard_num == 0)

// Check the distribution of members across top-up types
codebook tppr_acct_num  // Check the total number of members
codebook tppr_acct_num if only_hardcopy == 1  // Members with only hardcopy
codebook tppr_acct_num if only_softcopy == 1  // Members with only softcopy
codebook tppr_acct_num if only_hardcopy != 1 & only_softcopy != 1  // Members with mixed top-ups

save temp\topup_merged_analysis_mixed, replace
