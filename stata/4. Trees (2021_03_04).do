//------------------------------------------------------------------------------
// Housekeeping: Clear previous variables and set session parameters
//------------------------------------------------------------------------------
clear all
set more off

// Set working directory to relative path for portability
cd "project_folder\data"

//------------------------------------------------------------------------------
// CART (Classification and Regression Trees): Fit CART models to the data
//------------------------------------------------------------------------------
use temp\topup_merged_analysis, clear

// Cart 1: Perform regression tree analysis including multiple variables
capture log close
log using log\cart_1720_cart1, replace 
forval x = 0(1)3 {
	display "crtrees hardcopy female race close_cpf  emp_status topup_all_num_cat  xtage  xttopup_all_amt_tot xtosra_bal_amt xtmltp_lst_con_wge, class gen(cart1_`x') seed(123) st_code tree rule(`x') tsample(cart1_`x'_tsample)"
	crtrees hardcopy female race close_cpf  emp_status topup_all_num_cat  xtage  xttopup_all_amt_tot xtosra_bal_amt xtmltp_lst_con_wge, class gen(cart1_`x') seed(123) st_code tree rule(`x') tsample(cart1_`x'_tsample)
	g cart1_`x'_sample = (e(sample) ==1)
}
log close

// Cart 2: Perform regression tree analysis without the race variable
capture log close
log using log\cart_1720_cart2, replace 
forval x = 0(1)3 {
	display "crtrees hardcopy female  close_cpf  emp_status topup_all_num_cat  xtage  xttopup_all_amt_tot xtosra_bal_amt xtmltp_lst_con_wge, class gen(cart2_`x') seed(123) st_code tree rule(`x') tsample(cart2_`x'_tsample)"
	crtrees hardcopy female  close_cpf  emp_status topup_all_num_cat  xtage  xttopup_all_amt_tot xtosra_bal_amt xtmltp_lst_con_wge, class gen(cart2_`x') seed(123) st_code tree rule(`x') tsample(cart2_`x'_tsample)
	g cart2_`x'_sample = (e(sample) ==1)
}
log close

save temp\topup_merged_cart, replace

//------------------------------------------------------------------------------
// Cart 2: Perform regression tree analysis without the race variable
//------------------------------------------------------------------------------
use temp\topup_merged_cart, clear 

// Define cart1_2_grp groups based on combinations of variables and conditions
// Note: cart1_2 == cart2_2
g cart1_2_grp = 0 
replace cart1_2_grp = 2 if xtage <=3 
replace cart1_2_grp = 6 if xtage ==4 & xttopup_all_amt_tot == 1
replace cart1_2_grp = 15 if xtage ==4 & inrange(xttopup_all_amt_tot,2,4) & inrange(topup_all_num_cat, 3,4)
replace cart1_2_grp = 56 if xtage ==4 & inrange(xttopup_all_amt_tot,2,4) & inrange(topup_all_num_cat,1,2) & emp_status == 1 & xtmltp_lst_con_wge == 1 
replace cart1_2_grp = 59 if xtage ==4 & xttopup_all_amt_tot == 4 & inrange(topup_all_num_cat,1,2) & inrange(emp_status,2,3) 
replace cart1_2_grp = 112 if xtage ==4 & xttopup_all_amt_tot == 2 & inrange(topup_all_num_cat,1,2) & inrange(emp_status,2,3) 
replace cart1_2_grp = 113 if xtage ==4 & xttopup_all_amt_tot == 3 & inrange(topup_all_num_cat,1,2) & inrange(emp_status,2,3) 
replace cart1_2_grp = 206 if xtage ==4 & inrange(xttopup_all_amt_tot,2,3) & inrange(topup_all_num_cat,1,2) & emp_status == 1 & inrange(xtosra_bal_amt,1,2) & inrange(xtmltp_lst_con_wge,2,4)
replace cart1_2_grp = 207 if xtage ==4 & xttopup_all_amt_tot == 4 & inrange(topup_all_num_cat,1,2) & emp_status == 1 & inrange(xtosra_bal_amt,1,2) & inrange(xtmltp_lst_con_wge,2,4)
replace cart1_2_grp = 208 if xtage ==4 & inrange(xttopup_all_amt_tot,2,4) & inrange(topup_all_num_cat,1,2) & emp_status == 1 & inrange(xtosra_bal_amt,3,4) & xtmltp_lst_con_wge == 2
replace cart1_2_grp = 209 if xtage ==4 & inrange(xttopup_all_amt_tot,2,4) & inrange(topup_all_num_cat,1,2) & emp_status == 1 & inrange(xtosra_bal_amt,3,4) & inrange(xtmltp_lst_con_wge,3,4)

// Create a sample indicator for learning and estimation
g cart1_2_learn_sample = (cart1_2_tsample ==0 & cart1_2_sample ==1)
g cart1_2_estimation_sample = cart1_2_sample
g cart1_2_full_sample = 1 

// Run summary statistics and frequency tables for each group
foreach x in learn estimation full  { 
	display "tabstat hardcopy if cart1_2_`x'_sample ==1, stat(n mean) by(cart1_2_grp)  "
	tabstat hardcopy if cart1_2_`x'_sample ==1, stat(n mean) by(cart1_2_grp)  
	display "tab cart1_2_grp hardcopy if cart1_2_`x'_sample ==1"
	tab cart1_2_grp hardcopy if cart1_2_`x'_sample ==1
}


// Modify group variable for further analysis
g cart1_2_grp2 = cart1_2_grp 
replace cart1_2_grp2 = 59 if cart1_2_grp == 113

// Repeat analysis for modified group variable
foreach x in full {
    display "tabstat hardcopy if cart1_2_`x'_sample == 1, stat(n mean) by(cart1_2_grp2)"
    tabstat hardcopy if cart1_2_`x'_sample == 1, stat(n mean) by(cart1_2_grp2)
    display "tab cart1_2_grp2 hardcopy if cart1_2_`x'_sample == 1"
    tab cart1_2_grp2 hardcopy if cart1_2_`x'_sample == 1
}

// Generate and display summary statistics for various variables by group
tab cart1_2_grp emp_status
tab cart1_2_grp yr
tab topper_emp_status
tabstat topup_all_amt_mean, stat(mean) by(cart1_2_grp2)
tabstat topup_all_amt_mean if cart1_2_grp2 == 59, stat(mean) by(hardcopy)
tabstat topup_amt_mean, stat(mean) by(hardcopy)
tabstat order_adj if cart1_1_grp == 2, stat(n median mean min max) by(hardcopy)
tab order_cat hardcopy if cart1_1_grp == 2
