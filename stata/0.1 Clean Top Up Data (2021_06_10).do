//------------------------------------------------------------------------------
// Housekeeping: Clear previous variables and set session parameters
//------------------------------------------------------------------------------
clear all
set more off

// Set working directory to relative path for portability
cd "project_folder\data"

//------------------------------------------------------------------------------
// Clean top-up variables 
//------------------------------------------------------------------------------
use raw\topup, clear 

// Date variables: Convert to proper date format and extract year and month
g trns_date = date(trns_dte, "DMY")
format trns_date %td
drop trns_dte 
rename trns_date trns_dte
rename yr_of_trns trns_yr
g trns_mth = month(trns_dte)

g perd_dte = date(perd_id, "DMY")
format %td perd_dte
drop perd_id
g perd_yr = year(perd_dte)
g perd_mth = month(perd_dte)

order perd_dte trns_dte , first

// Account variable: Encode account type for consistent handling
encode acct_tp_cde, gen(acct_tp)
drop acct_tp_cde

// Relationship: Define relationship categories for top-up
/* Note: if 'parent' - toppee is parent to topper 
*/

g relationship = 1 if topup_by_tag == "O" & csh_topup_cde == ""
replace relationship = 2 if topup_by_tag =="O" & csh_topup_cde == "E"
replace relationship = 3 if topup_by_tag =="O" & csh_topup_cde == "F"
replace relationship = 4 if topup_by_tag =="S" 
replace relationship = 5 if topup_by_tag =="T" 
replace relationship = 6 if topup_by_tag =="V" 
replace relationship = 7 if topup_by_tag =="W" 
replace relationship = 8 if topup_by_tag =="X" 
lab def relationship_lab 1 "Self" 2"Employer" 3"Foreigner" 4" Spouse" 5"Parent" 6 "Grandparent" 7 "Sibling" 8 "Others"
lab val relationship relationship_lab

// Detailed relationship categories (including in-laws)
g relationship_detailed = relationship 
replace relationship_detailed = 9 if topup_by_tag =="T" & in_laws_topup_cde == "I"
replace relationship_detailed = 10 if topup_by_tag =="T"  & in_laws_topup_cde == "I"
lab def relationship_detailed_lab 1 "Self" 2"Employer" 3"Foreigner" 4" Spouse" 5"Parent" 6 "Grandparent" 7 "Sibling" 8 "Others" 9 "Parents in law" 10 "Grandparents in law"
lab val relationship_detailed relationship_detailed_lab

// Top-Up Amount: Handle missing or negative values and create summary totals
foreach x in csh_topup_amt cpf_trnf_amt {
	replace `x' = 0 if `x' ==. 
}

count if csh_topup_amt < 0 & rnst_tag !="R" // Reinstatement check
count if cpf_trnf_amt < 0 & rnst_tag !="R" // Reinstatement check
replace rnst_tag = "R" if rnst_tag != "R" & cpf_trnf_amt <0

// Combine cash and CPF top-up amounts into a single variable
egen topup_amt = rowtotal(csh_topup_amt cpf_trnf_amt)
drop if topup_amt ==0 

// Define top-up type based on the available data
g cash = (csh_topup_amt > 0 & !missing(csh_topup_amt))
g cpf = (cpf_trnf_amt > 0 & !missing(cpf_trnf_amt))

// Mode of Transaction: Categorize based on transaction mode codes
g mode_detail = 1 if inlist(topup_mde_cde, "MSSD052", "MSSD053@", "MTPD008", "MTPD009@")
replace mode_detail = 2 if inlist(topup_mde_cde, "MSSM118", "MSSM119@", "MTPM006", "MTPM007@")
replace mode_detail = 3 if inlist(topup_mde_cde, "MSSD064", "MSSD065@", "MTPD015", "MTPD016@")
replace mode_detail = 4 if inlist(topup_mde_cde, "MTPD077@", "PNWRAPMT", "MTPD083@", "PNWSAPMT")
replace mode_detail = 5 if inlist(topup_mde_cde, "MSSD116", "MSSD117@", "MTPD029", "MTPD030@")
replace mode_detail = 6 if inlist(topup_mde_cde, "DCMSE002")
replace mode_detail = 7 if inlist(topup_mde_cde, "MTPD107@", "MTPD106@")
replace mode_detail = 8 if inlist(topup_mde_cde, "OATOSA")
replace mode_detail = 9 if mode ==. 
lab def mode_detail_lab 1 "AXS/E-Cashier" 2 "GIRO" 3 "OCBC PIB" 4 "PayNow Straight-Through" 5 "OMR cash top-up" 6 "CPF transfer Straight-Through" 7 "CPF transfer batch or straight-through" 8 "Self OA to SA transfer" 9 "Other Manual "
lab val mode_detail mode_detail_lab

// Assign a flag for hardcopy transactions
g hardcopy = 0
replace hardcopy = 1 if inlist(mode_detail, 5, 9)

// Reinstatement Handling: Adjust amounts and remove duplicate records
g topup_amt2 = topup_amt 
replace topup_amt2 = -topup_amt2 if topup_amt2 < 0 

g r_tag = (rnst_tag == "R")

// Handle reinstatements within the same year
bys tppr_acct_num tppe_acct_num topup_amt2 trns_yr : egen max = max(r_tag)
bys tppr_acct_num tppe_acct_num topup_amt2 trns_yr : g dup = _N
replace dup = . if max == 0 

drop if dup == 2 
bys tppr_acct_num tppe_acct_num topup_amt2 trns_yr r_tag : g tag =(_n==1) if  max== 1 
bys tppr_acct_num tppe_acct_num topup_amt2 trns_yr : egen temp = total(tag) if max == 1
drop if tag == 1 & temp == 2 

// Handle reinstatements in the following year
bys tppr_acct_num tppe_acct_num topup_amt2: egen max2 = max(r_tag)
bys tppr_acct_num tppe_acct_num topup_amt2 : g r_yr_t = trns_yr if r_tag == 1
bys tppr_acct_num tppe_acct_num topup_amt2 : egen r_yr = max(r_yr_t)
drop r_yr_t
replace max2 = 0 if trns_yr > r_yr

// Handle remaining duplicates and clean up
bys tppr_acct_num tppe_acct_num topup_amt2 max2 : g dup2 = _N if max2 == 1
tab dup2 if max2 == 1
sum trns_yr if dup2 == 1 
drop if dup2 == 2 
bys tppr_acct_num tppe_acct_num topup_amt2 r_tag max2: g tag2 =(_n==1) 
replace tag2 = 0 if max2 == 0
bys tppr_acct_num tppe_acct_num topup_amt2  : egen temp2 = total(tag2)
drop if tag2 == 1 & temp2 == 2 

drop max dup tag temp max2 r_yr dup2 max2 tag2 temp2
drop if r_tag == 1
drop r_tag rnst_tag 

duplicates report

save temp\topup_trns, replace

//------------------------------------------------------------------------------
// Collapse to individual-level data 
//------------------------------------------------------------------------------
use temp\topup_trns, clear

// Restrict to 2017-2020 
keep if inrange(trns_yr, 2017,2020)

sort tppr_acct_num hardcopy

// Calculate the number of top-ups (all, hardcopy, softcopy)
by tppr_acct_num: g topup_all_num = _N
by tppr_acct_num hardcopy: g topup_hard_num_t = _N if hardcopy == 1
by tppr_acct_num hardcopy: g topup_soft_num_t = _N if hardcopy == 0
by tppr_acct_num : egen topup_hard_num = max(topup_hard_num_t)
by tppr_acct_num : egen topup_soft_num = max(topup_soft_num_t)

// Calculate total top-up amounts
by tppr_acct_num: egen topup_all_amt_tot = total(topup_amt)
by tppr_acct_num hardcopy: egen topup_hard_amt_tot_t = total(topup_amt) if hardcopy == 1 
by tppr_acct_num hardcopy: egen topup_soft_amt_tot_t = total(topup_amt) if hardcopy == 0
by tppr_acct_num : egen topup_hard_amt_tot = max(topup_hard_amt_tot_t) 
by tppr_acct_num : egen topup_soft_amt_tot = max(topup_soft_amt_tot_t) 

// Calculate mean top-up amounts
foreach x in all hard soft {
	g topup_`x'_amt_mean = topup_`x'_amt_tot / topup_`x'_num
}

drop *_t

sort tppr_acct_num trns_yr

// Calculate top-up data by year
forval x = 2017/2020 {

	by tppr_acct_num trns_yr: g topup_all_num_`x'_t = _N if trns_yr == `x'
	by tppr_acct_num : egen topup_all_num_`x' = max(topup_all_num_`x'_t) 
	
	by tppr_acct_num trns_yr: egen topup_all_amt_tot_`x'_t = total(topup_amt) if trns_yr == `x'
	by tppr_acct_num : egen topup_all_amt_tot_`x' = max(topup_all_amt_tot_`x'_t) 
	
	g topup_all_amt_mean_`x' = topup_all_amt_tot_`x' / topup_all_num_`x'

} 

// GIRO data handling

forval x = 2017/2020 {
	
	// Process GIRO-related top-ups
	by tppr_acct_num trns_yr: g topup_hard_num_`x'_t = _N if trns_yr == `x' & hardcopy == 1 
	by tppr_acct_num trns_yr: g topup_soft_num_`x'_t = _N if trns_yr == `x' & hardcopy == 0 
	
	// Calculate totals for GIRO
	by tppr_acct_num trns_yr: egen topup_hard_amt_tot_`x'_t = total(topup_amt) if trns_yr == `x' & hardcopy == 1
	by tppr_acct_num trns_yr: egen topup_soft_amt_tot_`x'_t = total(topup_amt) if trns_yr == `x' & hardcopy == 0
	
	// Calculate means for GIRO top-ups
	foreach y in hard soft {
		by tppr_acct_num : egen topup_`y'_num_`x' = max(topup_`y'_num_`x'_t) 
		by tppr_acct_num : egen topup_`y'_amt_tot_`x' = max(topup_`y'_amt_tot_`x'_t) 
		g topup_`y'_amt_mean_`x' = topup_`y'_amt_tot_`x' / topup_`y'_num_`x'
	}

} 

drop *_t

// Clean up and save individual-level data
sort tppr_acct_num trns_dte 
by tppr_acct_num : g tag = (_n==_N)
keep if tag == 1

by tppr_acct_num: g dup = _N
tab dup 
drop dup tag
save temp\topup_indiv, replace

//------------------------------------------------------------------------------
// Newly added code: Update date to use newly provided mapping for harcopy transactions
//------------------------------------------------------------------------------
use temp\topup_trns, clear

// Remove existing mode_detail variable and re-categorize 
drop mode_detail 
g mode_detail = 1 if inlist(topup_mde_cde, "MSSD052", "MSSD053@", "MTPD008", "MTPD009@")
replace mode_detail = 2 if inlist(topup_mde_cde, "MSSM118", "MSSM119@", "MTPM006", "MTPM007@")
replace mode_detail = 3 if inlist(topup_mde_cde, "MSSD064", "MSSD065@", "MTPD015", "MTPD016@")
replace mode_detail = 4 if inlist(topup_mde_cde, "MTPD077@", "PNWRAPMT", "MTPD083@", "PNWSAPMT")
replace mode_detail = 5 if inlist(topup_mde_cde, "MSSD116", "MSSD117@", "MTPD029", "MTPD030@")
replace mode_detail = 6 if inlist(topup_mde_cde, "DCMSE002")
replace mode_detail = 7 if inlist(topup_mde_cde, "MTPD107@", "MTPD106@")
replace mode_detail = 8 if inlist(topup_mde_cde, "OATOSA")
replace mode_detail = 9 if inlist(topup_mde_cde, "")
replace mode_detail = 10 if mode_detail ==. 
lab def mode_detail_lab2 1 "AXS/E-Cashier" 2 "GIRO" 3 "OCBC PIB" 4 "PayNow Straight-Through" 5 "OMR cash top-up" 6 "CPF transfer Straight-Through" 7 "CPF transfer batch or straight-through" 8 "Self OA to SA transfer" 9 "55 transfer" 10 "Other Manual "
lab val mode_detail mode_detail_lab2

// Rename hardcopy to prevent overwriting and clean data
rename hardcopy hardcopy_v1
drop if inrange(mode_detail, 6,9)

// Assign hardcopy flag
g hardcopy = 1 if inlist(mode_detail, 2, 5, 10)
replace hardcopy = 0 if inlist(mode_detail, 1,3,4)

// Check for missing hardcopy values
tab hardcopy, missing

save temp\topup_trnsv2, replace

//------------------------------------------------------------------------------
// Collapse to individual-level data (v2)
//------------------------------------------------------------------------------
use temp\topup_trnsv2, clear

// Restrict to 2017-2020 
keep if inrange(trns_yr, 2017,2020)

sort tppr_acct_num hardcopy

// Calculate the number of top-ups (total, hardcopy, and softcopy)
by tppr_acct_num: g topup_all_num = _N
by tppr_acct_num hardcopy: g topup_hard_num_t = _N if hardcopy == 1
by tppr_acct_num hardcopy: g topup_soft_num_t = _N if hardcopy == 0
by tppr_acct_num : egen topup_hard_num = max(topup_hard_num_t)
by tppr_acct_num : egen topup_soft_num = max(topup_soft_num_t)

// Calculate total top-up amounts for each account
by tppr_acct_num: egen topup_all_amt_tot = total(topup_amt)
by tppr_acct_num hardcopy: egen topup_hard_amt_tot_t = total(topup_amt) if hardcopy == 1 
by tppr_acct_num hardcopy: egen topup_soft_amt_tot_t = total(topup_amt) if hardcopy == 0
by tppr_acct_num : egen topup_hard_amt_tot = max(topup_hard_amt_tot_t) 
by tppr_acct_num : egen topup_soft_amt_tot = max(topup_soft_amt_tot_t) 

// Check summary statistics for top-up amounts
sum topup_all_amt_tot topup_hard_amt_tot topup_soft_amt_tot 
	
// Calculate mean top-up amount for all categories (all, hard, soft)
foreach x in all hard soft {
	g topup_`x'_amt_mean = topup_`x'_amt_tot / topup_`x'_num
}

// GIRO Transactions: Process data for GIRO and non-GIRO transactions
g hard_giro = (mode_detail == 2)  // GIRO transactions
g hard_ngiro = inlist(mode_detail, 5, 10)  // Non-GIRO transactions

// Calculate number of GIRO and non-GIRO top-ups per account
bys tppr_acct_num hard_giro: g topup_giro_num_t = _N if hard_giro == 1 
bys tppr_acct_num hard_ngiro: g topup_ngiro_num_t = _N if hard_ngiro == 1 

// Calculate total amounts for GIRO and non-GIRO top-ups
bys tppr_acct_num : egen topup_giro_num = max(topup_giro_num_t)
by tppr_acct_num : egen topup_ngiro_num = max(topup_ngiro_num_t)

bys tppr_acct_num hard_giro: egen topup_giro_amt_tot_t = total(topup_amt) if hard_giro == 1 
bys tppr_acct_num hard_ngiro: egen topup_ngiro_amt_tot_t = total(topup_amt) if hard_ngiro == 1 

// Combine GIRO and non-GIRO totals
bys tppr_acct_num : egen topup_giro_amt_tot = max(topup_giro_amt_tot_t) 
by tppr_acct_num : egen topup_ngiro_amt_tot = max(topup_ngiro_amt_tot_t) 

drop *_t

// Calculate top-up statistics by year (2017-2020)

sort tppr_acct_num trns_yr

forval x = 2017/2020 {

	by tppr_acct_num trns_yr: g topup_all_num_`x'_t = _N if trns_yr == `x'
	by tppr_acct_num : egen topup_all_num_`x' = max(topup_all_num_`x'_t) 
	
	by tppr_acct_num trns_yr: egen topup_all_amt_tot_`x'_t = total(topup_amt) if trns_yr == `x'
	by tppr_acct_num : egen topup_all_amt_tot_`x' = max(topup_all_amt_tot_`x'_t) 
	
	g topup_all_amt_mean_`x' = topup_all_amt_tot_`x' / topup_all_num_`x'

} 

forval x = 2017/2020 {

	by tppr_acct_num trns_yr: g topup_hard_num_`x'_t_o = _N if trns_yr == `x' & hardcopy == 1 
	by tppr_acct_num trns_yr: g topup_soft_num_`x'_t_o = _N if trns_yr == `x' & hardcopy == 0 

	by tppr_acct_num trns_yr: egen topup_hard_amt_tot_`x'_t_o = total(topup_amt) if trns_yr == `x' & hardcopy == 1
	by tppr_acct_num trns_yr: egen topup_soft_amt_tot_`x'_t_o = total(topup_amt) if trns_yr == `x' & hardcopy == 0
	
	foreach y in hard soft {
		by tppr_acct_num : egen topup_`y'_num_`x'_o = max(topup_`y'_num_`x'_t_o) 
		by tppr_acct_num : egen topup_`y'_amt_tot_`x'_o = max(topup_`y'_amt_tot_`x'_t_o) 
		g topup_`y'_amt_mean_`x'_o = topup_`y'_amt_tot_`x'_o / topup_`y'_num_`x'_o
	}

} 

// New method for top-up statistics calculation
forval x = 2017/2020 {

	bys tppr_acct_num trns_yr hardcopy : g topup_hard_num_`x'_t = _N if trns_yr == `x' & hardcopy == 1 
	bys tppr_acct_num trns_yr hardcopy: g topup_soft_num_`x'_t = _N if trns_yr == `x' & hardcopy == 0 

	bys tppr_acct_num trns_yr: egen topup_hard_amt_tot_`x'_t = total(topup_amt) if trns_yr == `x' & hardcopy == 1
	bys tppr_acct_num trns_yr: egen topup_soft_amt_tot_`x'_t = total(topup_amt) if trns_yr == `x' & hardcopy == 0
	
	foreach y in hard soft {
		bys tppr_acct_num : egen topup_`y'_num_`x' = max(topup_`y'_num_`x'_t) 
		bys tppr_acct_num : egen topup_`y'_amt_tot_`x' = max(topup_`y'_amt_tot_`x'_t) 
		g topup_`y'_amt_mean_`x' = topup_`y'_amt_tot_`x' / topup_`y'_num_`x'
	}
}

// GIRO by year calculation
forval x = 2017/2020 {

	bys tppr_acct_num trns_yr hard_giro : g topup_giro_num_`x'_t = _N if trns_yr == `x' & hard_giro == 1 
	bys tppr_acct_num trns_yr hard_ngiro: g topup_ngiro_num_`x'_t = _N if trns_yr == `x' & hard_ngiro == 0 

	bys tppr_acct_num trns_yr: egen topup_giro_amt_tot_`x'_t = total(topup_amt) if trns_yr == `x' & hard_giro == 1
	bys tppr_acct_num trns_yr: egen topup_ngiro_amt_tot_`x'_t = total(topup_amt) if trns_yr == `x' & hard_ngiro == 0
	
	foreach y in giro ngiro {
		bys tppr_acct_num : egen topup_`y'_num_`x' = max(topup_`y'_num_`x'_t) 
		bys tppr_acct_num : egen topup_`y'_amt_tot_`x' = max(topup_`y'_amt_tot_`x'_t) 
		g topup_`y'_amt_mean_`x' = topup_`y'_amt_tot_`x' / topup_`y'_num_`x'
	}
}
drop *_t

sort tppr_acct_num trns_dte 
by tppr_acct_num : g tag = (_n==_N)
keep if tag == 1

by tppr_acct_num: g dup = _N
tab dup 
drop dup tag
save temp\topup_indivv2, replace

