//------------------------------------------------------------------------------
// Housekeeping: Clear previous variables and set session parameters
//------------------------------------------------------------------------------
clear all
set more off

// Set working directory to relative path for portability
cd "project_folder\data"

//------------------------------------------------------------------------------
// Data Processing of Member Data
//------------------------------------------------------------------------------
// Files are large so data is processed by year
forval y = 2013/2020{
	// Reset frames and load member data for the current year
	frames reset
	use raw\topup_mbr_`y', clear 
			
	// Date conversion and formatting
	g date = date(perd_id, "DMY")
	format date %td
	drop if perd_id == ""
	drop perd_id 
	order date, first
	sort mbr_num date 
	by mbr_num: g order = _n
	by mbr_num: g dup = _N
	
	// Copy frame to hold constant member information
	frame rename default mbr_constant 
	frame copy mbr_constant mbr_varying
	
	//------------------------------------------------------------------------------
	// Clean constant member variables (Vars that shouldn't change over time)
	//------------------------------------------------------------------------------
	pwf
	keep date mbr_num brth_dte gndr_cde rc_grp_cde ctzn_grp_cde dth_dte order dup
	
	// Keep only the latest observation for each member
	keep if order == dup 
	g birth_date = date(brth_dte, "DMY")
	g death_date = date(dth_dte, "DMY")
	format birth_date death_date %td
	drop brth_dte dth_dte						
	
	// Gender
	g male = 1 if gndr_cde == "M"
	replace male = 0 if gndr_cde == "F"
	
	// Race
	g race = 1 if rc_grp_cde == "02"
	replace race = 2 if rc_grp_cde == "00"
	replace race = 3 if rc_grp_cde == "04"
	replace race = 4 if rc_grp_cde == "O"
	lab def race_lab 1 "Chinese" 2 "Malay" 3 "Indian" 4 "Others"
	lab val race race_lab
	
	// Citizenship
	g ctz = 1 if ctzn_grp_cde == "S"
	replace ctz = 2 if ctzn_grp_cde == "P"
	replace ctz = 3 if ctzn_grp_cde == "F"
	lab def ctz_lab 1 "SC" 2 "PR" 3 "Foreigner"
	lab val ctz ctz_lab
	
	save temp\mbr_constant_`y', replace
	
	//------------------------------------------------------------------------------
	// Clean varying member variables (Vars that change over time)
	//------------------------------------------------------------------------------
	frame change mbr_varying 
	pwf
	
	// Drop redundant variables
	drop brth_dte gndr_cde rc_grp_cde ctzn_grp_cde dth_dte
	
	// Convert variables that contain codes to string
	tostring empl_sts_cde ee_cum_sem_tag adrs_ovrs_tag lst_con_dte, replace
	
	// Employment status
	g emp_status = 1 if empl_sts_cde == "A"
	replace emp_status = 2 if empl_sts_cde == "S"
	replace emp_status = 3 if empl_sts_cde == "I"
	lab def emp_status_lab 1 "Active" 2 "Self-Emp" 3 "Inactive"
	lab val emp_status emp_status_lab
	drop empl_sts_cde
	
	g ee_cum_sem = 1 if ee_cum_sem_tag == "Y"
	replace ee_cum_sem = 0 if ee_cum_sem_tag == "N"
	drop ee_cum_sem_tag 
	
	// Overseas address flag
	g ad_overseas = 1 if adrs_ovrs_tag == "Y"
	replace ad_overseas = 0 if adrs_ovrs_tag == "N"
	drop adrs_ovrs_tag 
	
	// Closest center tag
	rename adrs_sctr_cde postal_2d
	g cpf_centre = 1 if postal_2d == 6 | postal_2d == 4 | postal_2d == 5 | postal_2d == 7 | postal_2d == 1 
	replace cpf_centre = 2 if postal_2d == 52 
	replace cpf_centre = 3 if postal_2d == 57
	replace cpf_centre = 4 if postal_2d == 60
	replace cpf_centre = 5 if postal_2d == 73
	lab def cpf_centre_lab 1 "Maxwell" 2 "Tampines" 3 "Bishan" 4 "Jurong" 5 "Woodlands"
	lab val cpf_centre cpf_centre_lab
	
	// Last contribution date
	g lst_con_date = date(lst_con_dte, "DMY")
	order lst_con_date, after(lst_con_dte)
	format lst_con_date %td
	drop lst_con_dte
	
	g mth = month(date)
	g yr = year(date)
	
	drop order dup 
	save temp\mbr_varying_`y', replace

}
	
// Combine yearly constant and varying member data
frames reset 
use temp\mbr_constant_2013
forval y = 2014(1)2020{
	append using temp\mbr_constant_`y'
}
drop order dup 
sort mbr_num date 
by mbr_num: g order = _n
by mbr_num: g dup = _N
keep if order == dup 

// Final check on date for the latest observation
tab date 

// Drop temporary variables and save final constant data
drop order dup date 
save temp\mbr_constant, replace

// Combine all varying member data for the years 2013-2020
use temp\mbr_varying_2013, clear
forval y = 2014/2020{
	append using temp\mbr_varying_`y'
}
save temp\mbr_varying, replace



//------------------------------------------------------------------------------
// Process Member Contribution Data  
//------------------------------------------------------------------------------
forval y = 2020/2020{
	frames reset
	use raw\topup_mbr_`y', clear 

	// Date conversion and formatting
	g date = date(perd_id, "DMY")
	format date %td
	drop if perd_id == ""
	drop perd_id 
	order date, first
	
	keep date mbr_num *lst_*
	drop lst_con_ern 
	
	// Contribution year and month extraction
	tostring lst_con_rm, replace
	g con_yr = substr(lst_con_rm, 1,4)
	g con_mth = substr(lst_con_rm, 5,2)
	destring con_yr con_mth, replace
	drop lst_con_dte
	
	// Handle missing wages when industry exists
	g miss_ssic = missing(lst_con_ssic)
	g miss_wg = missing(mltp_lst_con_wge)
	replace mltp_lst_con_wge = 0 if mltp_lst_con_wge ==. & miss_ssic ==0 
	
	// Replace wages to 0 when negative
	replace mltp_lst_con_wge = 0 if mltp_lst_con_wge < 0 
	
	// Drop duplicates
	duplicates drop mbr_num con_yr con_mth lst_con_ssic mltp_lst_con_wge, force 
	
	// Handle multiple industry codes in the same year-month
	bys mbr_num con_yr con_mth lst_con_ssic: g ssic_tag = (_n==1)
	by mbr_num con_yr con_mth: egen num_ssic = total(ssic_tag)
	tab num_ssic // Check for more than 1 industry
	
	// Keep latest industry code where there are multiple in same yr-mth 
	sort mbr_num con_yr con_mth ssic_tag date
	by mbr_num con_yr con_mth ssic_tag: g latest_ssic_obs = (_n==_N)
	keep if latest_ssic_obs == 1 & ssic_tag == 1 

	// Handle multiple wages in the same year-month
	bys mbr_num con_yr con_mth mltp_lst_con_wge: g wg_tag = (_n==1)
	by mbr_num con_yr con_mth: egen num_wg = total(wg_tag)
	tab num_wg // more than 1 
	
	// Keep latest wage where there are multiple wage in same yr-mth 
	sort mbr_num con_yr con_mth wg_tag date
	by mbr_num con_yr con_mth wg_tag: g latest_wg_obs = (_n==_N)
	keep if latest_wg_obs == 1 & wg_tag == 1 
	
	// Remove duplicates and retain only relevant variables
	by mbr_num con_yr con_mth: g dup = _N
	tab dup
	drop dup 
	keep mbr_num con_yr con_mth lst_con_ssic mltp_lst_con_wge 
	g year = `y'

	// Save the processed contribution data for the current year
	save temp\mbr_con`y', replace
}
	
// Combine all contributions data for the years 2013-2020
use temp\mbr_con2013 , clear

forval y = 2014/2020{
	append using temp\mbr_con`y'
}
bys mbr_num con_yr con_mth: g dup = _N
tab dup
drop dup 

// Final checks for industry and wage consistency
bys mbr_num con_yr con_mth lst_con_ssic: g ssic_tag = (_n==1)
by mbr_num con_yr con_mth: egen num_ssic = total(ssic_tag)
tab num_ssic // Check for more than 1 industry

// Keep latest industry code where there are multiple  in same yr-mth 
sort mbr_num con_yr con_mth ssic_tag year
by mbr_num con_yr con_mth ssic_tag: g latest_ssic_obs = (_n==_N)
keep if latest_ssic_obs == 1 & ssic_tag == 1

// Check for multiple wages in the same year-month
bys mbr_num con_yr con_mth mltp_lst_con_wge: g wg_tag = (_n==1)
by mbr_num con_yr con_mth: egen num_wg = total(wg_tag)
tab num_wg // more than 1 

// Keep latest wage where there are multiple wage in same yr-mth 
sort mbr_num con_yr con_mth wg_tag year
by mbr_num con_yr con_mth wg_tag: g latest_wg_obs = (_n==_N)
keep if latest_wg_obs == 1 & wg_tag == 1 

// Final cleanup and save the combined data
duplicates drop mbr_num con_yr con_mth lst_con_ssic mltp_lst_con_wge , force 
by mbr_num con_yr con_mth: g dup = _N
tab dup
drop dup 
keep mbr_num con_yr con_mth lst_con_ssic mltp_lst_con_wge 
rename (con_yr con_mth) (yr mth)
	
save temp\mbr_con, replace












	
	
	
	
	