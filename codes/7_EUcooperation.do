*******************************************************************************
//7_EUcooperation

/*This do-file calculates the tax deficit for the case of all EU countries adopting a
25% minimum tax on their headquartered firms + collecting a sales-based share of the tax
deficit of non-EU multinationals. */

set more off
clear

****************************************************************************************
// extract data on sales of MNEs in partner countries (basis for sales apportionment) //

// use sales apportionment from 6_unilateral
	use "${dta}/sales_perc.dta", clear

// merge tax deficits
	merge m:1 parent using "${dta}/td_etrc_2021.dta", keepusing(parent parentname td25c)
	keep if _merge ==3 | salesloc== "EUROP" | salesloc == "OTE" //drop all countries that are not in OECD data as we do not have infos about their sales
	drop _merge	
//take out sales in domestic market (e.g.Fr MNEs in FR)	
	drop if salesloc == salesmne	
	order salesloc salesmne sales_perc parent* td25c

//gen foreign sales tax deficit
	gen salestd25c = sales_perc*td25c
//take out sales-based TD of European countries
//take out European countries
	drop eu
	gen eu= 0
	replace eu = 1 if salesmne == "AT" | salesmne == "BE" | salesmne == "BG" | salesmne == "HR" | salesmne == "CY" | ///
		salesmne == "CZ" | salesmne == "DK" | salesmne == "EE" | salesmne == "FI" | salesmne == "FR" | ///
		salesmne == "DE" | salesmne == "GR" | salesmne == "HU" | salesmne == "IE" | salesmne == "IT" | ///
		salesmne == "LV" | salesmne == "LT" | salesmne == "LU" | salesmne == "MT" | salesmne == "NL" | ///
		salesmne == "PL" | salesmne == "PT" | salesmne == "RO" | salesmne == "SK" | salesmne == "SI" | ///
		salesmne == "ES" | salesmne == "SE" 
	replace salestd25c =0 if eu==1
// set other Europe sales to 0, when we expect them to be non-EU or tax havens
	replace salestd25c =0 if (salesloc == "OTE") & (salesmne == "LU" | salesmne == "US" | salesmne == "IT" | salesmne == "DK" | salesmne == "BE")

*collapse and output
collapse (sum) salestd25c , by(salesloc)
gen parent = salesloc
save "${dta}/salestd25_eucoop.dta", replace

***********************************************************************************
// Integrate headquarter tax deficit & sales-based TD, 2021 numbers

// load headquarter TD
use "${dta}/table1_oecdtwz_2021_etrc_min25.dta", clear
keep parent* td25c
replace td25c = . if parent == "BG" | parent == "HR" | parent == "LT"  | parent == "RO" 

// merge sales-based TD
merge 1:1 parent using "${dta}/salestd25_eucoop.dta"
keep if _merge ==3 | salesloc== "EUROP" | salesloc == "OTE"
drop _merge

//uprate salesTD (ass.: several big exporters are missing)
gen salestd25c_imp = salestd25c *2 if salesloc!= "EUROP" & salesloc != "OTE"
replace salestd25c_imp = salestd25c if salesloc== "EUROP" | salesloc == "OTE"

// gen sum of headquarter & sales-based TD
gen unitd25c = td25c + salestd25c_imp
replace unitd25c = salestd25c if salesloc== "EUROP" | salesloc == "OTE"
drop salesloc

foreach var in td25c salestd25c salestd25c_imp unitd25c {
	replace `var' = . if parent == "BG" | parent == "HR" | parent == "LT"  | parent == "RO" 
}
order parent* td25c salestd* unitd*

save "${dta}/td25c_unilat21_eucoop.dta", replace

*********************************************************************************
// Recompute CIT and health exp. shares based on 2016 data

// load benchmark TD in 2016 EUR
use "${dta}/table1_oecdtwz2016_etrc.dta", clear

// data edit & keep only benchmark
keep parent partner td25c
duplicates tag parent partner, gen(dup)
drop if td25c ==. & dup ==1 
drop dup

// collapse by parent 
collapse (sum) td25c , by(parent)

//merge sales percentages 
merge 1:m parent using "${dta}/sales_perc.dta"
keep if _merge ==3 | salesloc== "EUROP" | salesloc == "OTE"
drop _merge

// drop domestic sales-based TD
drop if salesloc == salesmne	
order salesloc salesmne sales_perc parent* td25c

// gen sales-based TD in 2016 EUR
gen salestd25c = sales_perc*td25c
// set sales-based TD of EU countries to 0
replace salestd25c =0 if eu==1
// set other Europe sales to 0, when we expect them to be non-EU or tax havens
replace salestd25c =0 if (salesloc == "OTE") & (salesmne == "LU" | salesmne == "US" | salesmne == "IT" | salesmne == "DK" | salesmne == "BE")

//collapse & output
collapse (sum) salestd25c , by(salesloc /*us*/)
gen parent = salesloc
save "${dta}/salestd25_2016_eucoop.dta", replace


********************************************************************************
// Integrate headquarter tax deficit & sales-based TD, 2016 numbers


use "${dta}/table1_oecdtwz2016_etrc.dta", clear // no BG, RO, etc

// data edit & restrict to benchmark
keep parent partner td25c
duplicates tag parent partner, gen(dup)
drop if td25c ==. & dup ==1 
drop dup

// sum TD by parent
collapse (sum) td25c , by(parent)

// merge sales-based TD
merge 1:1 parent using "${dta}/salestd25_2016_eucoop.dta"
keep if _merge ==3 | salesloc== "EUROP" | salesloc == "OTE"
drop _merge

order parent* salesloc td25c salestd*

//uprate salesTD (ass.: several big exporters are missing)
gen salestd25c_imp = salestd25c *2 if salesloc!= "EUROP" & salesloc != "OTE"
replace salestd25c_imp = salestd25c if salesloc== "EUROP" | salesloc == "OTE"

// gen sum of headquarter & sales-based TD, 2016 EUR
gen unitd25c = td25c + salestd25c_imp
replace unitd25c = salestd25c if salesloc== "EUROP" | salesloc == "OTE"

// Computation of health and CIT shares

	* merge health and CIT aggregates
	merge m:1 parent using "${dta}/health.dta"	
	keep if _merge ==3 | salesloc== "EUROP" | salesloc == "OTE"
	drop _merge
	* merge CIT revenue in 2016 bn EUR (TWZ directly)	
	merge m:1 parent using "${dta}/citrev.dta"
	keep if _merge ==3 | salesloc== "EUROP" | salesloc == "OTE" | parent == "ID"
	drop _merge
	
	*shares health
	gen shealthunitd25c= unitd25c/ health
	* shares CIT	
	gen sCIT_TWZunitd25c = unitd25c / CIT_TWZ

	// EU dummy
	gen eu= 2
	replace eu = 1 if parent == "AT" | parent == "BE" | parent == "BG" | parent == "HR" | parent == "CY" | ///
				parent == "CZ" | parent == "DK" | parent == "EE" | parent == "FI" | parent == "FR" | ///
				parent == "DE" | parent == "GR" | parent == "HU" | parent == "IE" | parent == "IT" | ///
				parent == "LV" | parent == "LT" | parent == "LU" | parent == "MT" | parent == "NL" | ///
				parent == "PL" | parent == "PT" | parent == "RO" | parent == "SK" | parent == "SI" | ///
				parent == "ES" | parent == "SE" 
	by parent, sort: gen help = _n	
	sum eu if eu ==1 & help ==1
	di r(sum) //23 countries

	// EU23 unilateral TD
	sum unitd25c if eu ==1 | salesloc== "EUROP" | salesloc == "OTE"
	gen unistd25_EU23 = r(sum)
	di "Sum Unilateral Tax Deficit, min rate EU23: `r(sum)'"
	//check 
	sum td25c if eu==1
	di "Cooperation tax deficit: `r(sum)'"
		
	// health share			
	sum health if eu ==1 & help ==1
	gen health_EU23 = r(sum)
	di "Health expenditure EU23: `r(sum)'"
	
	// EU23 CIT
	sum CIT_TWZ if eu ==1  & help ==1
	gen CITTWZ_EU23 = r(sum) 
	di "CIT TWZ EU23: `r(sum)'"

	// calc CIT share			
	gen unitd25_shCIT = unistd25_EU23 /CITTWZ_EU23
	//calc health share
	gen unitd25_shhealth  = unistd25_EU23 /health_EU23 
				
						
	keep parent unitd25_shCIT* 	unitd25_shhealth* eu shealthunitd25c sCIT_TWZunitd25c
	
// merge TD in 2021 EUR		
	merge 1:1 parent using "${dta}/td25c_unilat21_eucoop.dta"	
	drop if parent == "BM"  | parent == "SG"
	keep if _merge ==3 | parent== "EUROP" | parent == "OTE"
	drop _merge
	

// collapse EUROP and other Europe sales-based TD to 1 line
replace parentname = "Unallocated" if parent == "EUROP" | parent == "OTE"
collapse (sum) td25c   (sum) salestd25c  (sum) salestd25c_imp ///
 (sum) unitd25c (sum) shealthunitd25c (sum) sCIT_TWZunitd25c ///
(sum) unitd25_shCIT (sum) unitd25_shhealth (sum) eu (firstnm) parent, by(parentname)



//insert sums for EU	
			expand 2 if parent == "AT", gen(ex)
			replace parentname = "EU total" if ex== 1
			replace parent = "EU" if ex== 1
			replace eu = 1.5 if ex== 1
			sum unitd25_shhealth
			replace shealthunitd25c = r(mean) if ex== 1
			sum unitd25_shCIT 
			replace sCIT_TWZunitd25c = r(mean) if ex== 1
			drop unitd25_shhealth unitd25_shCIT  ex
			foreach var in td25c salestd25c salestd25c_imp unitd25c {
				sum `var' if eu ==1 | eu ==4
				replace `var' = r(sum) if parent == "EU"
			}	
	
drop if eu==2	
drop salestd25c
order parent parentname td25c salestd25c_imp unitd25c shealthunitd25c sCIT_TWZunitd25c 

replace eu = 3 if eu ==2
replace eu = 2 if parent== "EUROP" | parent == "OTE"
replace eu = 2.5 if parent == "EU"
sort eu parent, stable	
drop eu										

export excel using "${dta}/Results_benchmark.xlsx", sheetreplace first(var) sheet("EUcooperation_min25")
putexcel set "${dta}/Results_benchmark.xlsx", modify sheet("EUcooperation_min25")
putexcel (C2:E26), nformat(#0.0)
putexcel (F2:G26), nformat(percent)
putexcel (A1:G1), bold
putexcel (A1:B26), bold
putexcel (A1:A26), border("left", "medium", "black")
putexcel (B1:B26), border("left", "medium", "black")
putexcel (G1:G26), border("right", "medium", "black")
putexcel (A1:G1), border("bottom", "medium", "black")
putexcel (A25:G25), border("bottom", "medium", "black")
putexcel (A26:G26), border("bottom", "medium", "black")
putexcel (A1:G1), border("top", "medium", "black")
