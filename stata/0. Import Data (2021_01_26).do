//------------------------------------------------------------------------------
// Housekeeping: Clear previous variables and set session parameters
//------------------------------------------------------------------------------
clear all
set more off

// Set working directory to relative path for portability
cd "project_folder\data"

//------------------------------------------------------------------------------
// Import & Append Transaction Data
//------------------------------------------------------------------------------
// Import top-up data for each year
forval y = 2013/2020 {
	import delimited "clean\topup_`y' .csv", clear
	save raw\topup_`y', replace
}

// Append data from all years into one dataset
use raw\topup_2013, clear
forval y = 2014/2020 {
	append using raw\topup_`y'
}
save raw\topup, replace


//------------------------------------------------------------------------------
// Extract unique set of member IDs
//------------------------------------------------------------------------------
use raw\topup, clear

// Keep only the account numbers for each member
keep *_acct_num 

// Loop through topper (tppr) and toppee (tppe) to extract account numbers
foreach x in tppr tppe {
	preserve 
	keep `x'_acct_num
	rename `x' MBR_NUM 
	save raw\topup_`x'_acct_num, replace
	restore
}

// Combine account numbers from both account types into one dataset of unqiue account nubers
use raw\topup_tppr_acct_num, clear
append using raw\topup_tppe_acct_num
duplicates drop 
export delimited using "temp\topup_mbr_num.csv", replace

// Clean up temporary files
erase "raw\topup_tppr_acct_num.dta"
erase "raw\topup_tppe_acct_num.dta"

//------------------------------------------------------------------------------
// Import Member-level Data
//------------------------------------------------------------------------------
// Member data extracted based on unique member numbers found above

// Loop to import member data for each year from 2013 to 2020
forval y = 2013/2020 {
	local mth "01 02 03 04 05 06 07 08 09 10 11 12"
	
	foreach m in `mth' {
		import delimited "clean\topup_mbr_`y'_`m' .csv", clear
		tostring dth_dte adrs_ovrs_tag, replace
		save raw\topup_mbr_`y'_`m', replace
	}
}

// Combine monthly member data into annual datasets for each year
forval y = 2013/2020 {
	use raw\topup_mbr_`y'_01, clear 
	local mth "02 03 04 05 06 07 08 09 10 11 12"
	foreach m in `mth' {
		append using raw\topup_mbr_`y'_`m'
	}
	save raw\topup_mbr_`y', replace
	
	// Clean up the monthly files after use
	foreach m in `mth' {
		erase "raw\topup_mbr_`y'_`m'.dta"
	}
}
