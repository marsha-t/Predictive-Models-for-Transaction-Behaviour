//------------------------------------------------------------------------------
// Housekeeping: Clear previous variables and set session parameters
//------------------------------------------------------------------------------
clear all
set more off

// Set working directory to relative path for portability
cd "project_folder\data"

//------------------------------------------------------------------------------
// Merge Top Up Data with Member Data (v1)
//------------------------------------------------------------------------------
use temp\topup_indiv, clear

// Merge member constant characteristics with top-up data
merge m:1 tppr_acct_num using temp\mbr_1719_constant
drop _merge 

// Merge member varying characteristics with top-up data
rename trns_yr yr
rename trns_mth mbr_varying_mth
merge 1:1 tppr_acct_num yr mbr_varying_mth using temp\mbr_1719_varying_monthly
drop if _merge == 2 // Drop non-matching records from this merge
drop _merge

// Merge member contribution data with top-up data
rename mbr_varying_mth mbr_con_mth
merge 1:1 tppr_acct_num yr mbr_con_mth using temp\mbr_1719_con_monthly 
drop if _merge ==2 // Drop non-matching records from this merge
drop _merge 

// Rename month variable and save the merged dataset
rename mbr_con_mth mth
save temp\topup_merged, replace


//------------------------------------------------------------------------------
// Merge Top Up Data with Member Data (v2)
//------------------------------------------------------------------------------
use temp\topup_indivv2, clear

// Merge member constant characteristics with top-up data
merge m:1 tppr_acct_num using temp\mbr_1719_constant
drop if _merge == 2
drop _merge 

// Merge member varying characteristics with top-up data

rename trns_yr yr
rename trns_mth mbr_varying_mth
merge 1:1 tppr_acct_num yr mbr_varying_mth using temp\mbr_1719_varying_monthly
drop if _merge == 2
drop _merge

// Merge member contribution data with top-up data
rename mbr_varying_mth mbr_con_mth
merge 1:1 tppr_acct_num yr mbr_con_mth using temp\mbr_1719_con_monthly 
drop if _merge ==2 
drop _merge 

// Rename month variable and save the merged dataset
rename mbr_con_mth mth
save temp\topup_mergedv2, replace
