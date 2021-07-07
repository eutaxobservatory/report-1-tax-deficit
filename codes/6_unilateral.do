*******************************************************************************
//6_unilateral

/*This do-file edits the data on unrelated party revenue given in the OECD CbCR data. Using 
the tax deficit of the multilateral case (5_2021uprate) and a sales-based tax deficit apportioned 
proportional to sales in the country, the unilateral/first-mover revenue potential of
a 25% minimum tax is calculated. */

set more off
clear

****************************************************************************************
// extract data on sales of MNEs in partner countries (basis for sales apportionment) //

insheet using "${data}\CBCR_TABLEI_positive.csv", clear

// data edit
	* sample restriction
	keep if grouping == "Sub-Groups with positive profits"

	* only relevant variables
	drop pan grouping variable yea flagcodes flags
	keep if cbc== "UPR" // unrelated party revenue 

	* reshape
	reshape wide value, j(cbc) i(cou jur) string
	ren value* *
	ren cou parent
	ren jur partner
	ren *, lower

	* exclude statesless entities
	tab partnerjurisdiction
	drop if partnerjurisdiction == "Stateless" 

	* keep only the foreign totals for parent that do not have more detailed partners
	by parent, sort: gen help = _N
	br parent partner help if help ==2
	drop if partnerjurisdiction == "Foreign Jurisdictions Total" & help >2 // only if foreign jurisdiction is a summary variable


// calculate apportionment based on unrelated party revenue
	
	* calculate the total of unrelated party revenues by parent
	by parent, sort: egen double total_upr = total(upr)

	* calculate the sales percentage in each partner
	gen sales_perc = upr/total_upr
	by parent, sort : egen check = sum(sales_perc)
	sum check
	drop check

	
//further data edits
	keep parent partner sales_perc
	* retrieve ISO for merges
	kountry parent, from(iso3c) to(iso2c)
	ren _ISO2C_ salesmne
	kountry partner, from(iso3c) to(iso2c)
	ren _ISO2C_ salesloc
	replace salesloc= "GG" if partner == "GGY"
	replace salesloc= "IM" if partner == "IMN"
	replace salesloc= "JE" if partner == "JEY"
	replace salesloc= "CW" if partner == "CUW"
	replace salesloc= "BV" if partner == "BVT"
	replace salesloc = partner if salesloc == ""
	sort salesloc

	* EU & OECD indicators
	gen eu= 2
	replace eu = 1 if salesloc == "AT" | salesloc == "BE" | salesloc == "BG" | salesloc == "HR" | salesloc == "CY" | ///
			salesloc == "CZ" | salesloc == "DK" | salesloc == "EE" | salesloc == "FI" | salesloc == "FR" | ///
			salesloc == "DE" | salesloc == "GR" | salesloc == "HU" | salesloc == "IE" | salesloc == "IT" | ///
			salesloc == "LV" | salesloc == "LT" | salesloc == "LU" | salesloc == "MT" | salesloc == "NL" | ///
			salesloc == "PL" | salesloc == "PT" | salesloc == "RO" | salesloc == "SK" | salesloc == "SI" | ///
			salesloc == "ES" | salesloc == "SE" 
			
	gen OECD = 0
	replace OECD =1 if salesloc == "AU" | salesloc == "BR" | salesloc == "CA" | salesloc == "CL" | salesloc == "CN" ///
						| salesloc == "ID" | salesloc == "IN" | salesloc == "JP" | salesloc == "KR" | salesloc == "MX" ///
						| salesloc == "NO" | salesloc == "US" | salesloc == "ZA" | salesloc == "SG" | salesloc == "BM"

// output sales shares for later			
	sort salesloc
	drop parent partner
	gen parent = salesmne
	save "${dta}/sales_perc.dta", replace

// merge tax deficits
	merge m:1 parent using "${dta}/td_etrc_2021.dta", keepusing(parent parentname td25c)
	keep if _merge ==3 //drop all countries that are not in OECD data as we do not have infos about their sales
	drop _merge		
//take out sales in domestic market (e.g.Fr MNEs in FR)	
	drop if salesloc == salesmne	
	order salesloc salesmne sales_perc parent* td25c

// gen sales-based tax deficit
	gen salestd25c = sales_perc*td25c

// set sales of partner = "Other Euope" to 0, if we expect them to be non-EU or tax havens
	replace salestd25c =0 if (salesloc == "OTE") & (salesmne == "LU" | salesmne == "US" | salesmne == "IT" | salesmne == "DK" | salesmne == "BE")

// last data edits
	
	*US dummy
	gen us = 0
	replace us = 1 if salesmne =="US"

	*collapse and reshape
	collapse (sum) salestd25c , by(salesloc us)
	reshape wide salestd25c, i(salesloc) j(us)
	ren salestd25c0 salestd25c_nonUS
	ren salestd25c1 salestd25c_US
	gen parent = salesloc

// output
save "${dta}/salestd25.dta", replace

***********************************************************************************
// Integrate headquarter tax deficit & sales-based TD, 2021 numbers

// load headquarter TD
use "${dta}/table1_oecdtwz_2021_etrc_min25.dta", clear
keep parent* td25c
replace td25c = . if parent == "BG" | parent == "HR" | parent == "LT"  | parent == "RO" 

// merge sales-based TD
merge 1:1 parent using "${dta}/salestd25.dta"
keep if _merge ==3 |  salesloc== "EUROP" | salesloc == "OTE" 
drop _merge

//uprate salesTD_non us (ass.: several big exporters are missing (DE, CH, UK, ES,...), the non-US sales-based TD is underestimated)
replace salestd25c_US = 0 if salestd25c_US ==.
gen salestd25c_nonUSimp = salestd25c_nonUS *2 if parent != "DE" & salesloc != "OTE" & salesloc != "EUROP"
replace  salestd25c_nonUSimp = salestd25c_nonUS *1.5 if parent == "DE"
replace salestd25c_nonUSimp = salestd25c_nonUS if salesloc == "OTE" | salesloc == "EUROP"

// gen sum of headquarter & sales-based TD
gen salestd25c = salestd25c_US + salestd25c_nonUSimp
gen unitd25c = td25c + salestd25c_US + salestd25c_nonUSimp
replace unitd25c =  salestd25c_US + salestd25c_nonUSimp if salesloc== "EUROP" | salesloc == "OTE"


foreach var in td25c salestd25c_US salestd25c_nonUS salestd25c_nonUSimp salestd25c unitd25c {
replace `var' = . if parent == "BG" | parent == "HR" | parent == "LT"  | parent == "RO" 
}

drop salesloc
order parent* td25c salestd25c_US salestd25c_nonUS* salestd25c unitd*

save "${dta}/td25c_unilat21.dta", replace


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
drop if _merge !=3
drop _merge

// drop domestic sales-based TD
drop if salesloc == salesmne	
order salesloc salesmne sales_perc parent* td25c

// gen sales-based TD in 2016 EUR
gen salestd25c = sales_perc*td25c
// set sales of partner = "Other Euope" to 0, if we expect them to be non-EU or tax havens
replace salestd25c =0 if (salesloc == "OTE") & (salesmne == "LU" | salesmne == "US" | salesmne == "IT" | salesmne == "DK" | salesmne == "BE")

// further data edit
gen us = 0
replace us = 1 if salesmne =="US"

collapse (sum) salestd25c , by(salesloc us)
reshape wide salestd25c, i(salesloc) j(us)
ren salestd25c0 salestd25c_nonUS
ren salestd25c1 salestd25c_US
gen parent = salesloc

// output sales-based TD in 2016 EUR
save "${dta}/salestd25_2016.dta", replace

********************************************************************************
// Integrate headquarter tax deficit & sales-based TD, 2016 numbers

use "${dta}/table1_oecdtwz2016_etrc.dta", clear

// data edit & restrict to benchmark
keep parent partner td25c
duplicates tag parent partner, gen(dup)
drop if td25c ==. & dup ==1 
drop dup

// sum TD by parent
collapse (sum) td25c , by(parent)

// merge sales-based TD
merge 1:1 parent using "${dta}/salesTD25_2016.dta"
keep if _merge ==3 | salesloc== "EUROP" | salesloc == "OTE"
drop _merge

order parent* salesloc td25c salestd*

//uprate salesTD_non us (ass.: several big exporters are missing (DE, CH, UK, ES,...), the non-US sales-based TD is underestimated)
replace salestd25c_US = 0 if salestd25c_US ==.
gen salestd25c_nonUSimp = salestd25c_nonUS *2 if parent != "DE"
replace  salestd25c_nonUSimp = salestd25c_nonUS *1.5 if parent == "DE"
replace salestd25c_nonUSimp = salestd25c_nonUS if salesloc == "OTE" | salesloc == "EUROP"

// gen sum of headquarter & sales-based TD, 2016 EUR
gen unitd25c = td25c + salestd25c_US + salestd25c_nonUSimp
replace unitd25c =  salestd25c_US + salestd25c_nonUSimp if salesloc== "EUROP" | salesloc == "OTE"

// Computation of health and CIT shares


	* merge health expenditure in 2016 bn EUR 
	merge m:1 parent using "${dta}/health.dta"	
	keep if _merge ==3 | salesloc== "EUROP" | salesloc == "OTE"
	drop _merge
	* merge CIT revenue in 2016 bn EUR (TWZ directly)	
	merge m:1 parent using "${dta}/CITrev.dta"
	keep if _merge ==3  | salesloc== "EUROP" | salesloc == "OTE" | parent == "ID"
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
	di r(sum) //23 countries in data

	// EU23 unilateral TD
	sum unitd25c if eu ==1 | salesloc== "EUROP" | salesloc == "OTE"
	gen unistd25_EU23 = r(sum)
	di "Sum Unilateral Tax Deficit, min rate EU23: `r(sum)'"
	*check 
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
	merge 1:1 parent using "${dta}/TD25c_unilat21.dta"	
	drop if parent == "BM"  | parent == "SG"
	keep if _merge ==3 | parent == "EUROP" | parent == "OTE"
	drop _merge



// collapse EUROP and other Europe sales-based TD to 1 line
replace parentname = "Unallocated" if parent == "EUROP" | parent == "OTE"
collapse (sum) td25c (sum) salestd25c_US (sum) salestd25c_nonUS (sum) salestd25c_nonUSimp ///
(sum) salestd25c (sum) unitd25c (sum) shealthunitd25c (sum) sCIT_TWZunitd25c ///
(mean) unitd25_shCIT (mean) unitd25_shhealth (sum) eu (firstnm) parent, by(parentname)



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
			foreach var in td25c salestd25c_US salestd25c_nonUS salestd25c_nonUSimp salestd25c unitd25c {
				sum `var' if eu ==1 | eu== 4
				replace `var' = r(sum) if parent == "EU"
			}	
			foreach var in salestd25c_US salestd25c_nonUS salestd25c_nonUSimp salestd25c unitd25c td25c {
				replace `var' =. if parent == "EU"
			}

drop salestd25c_nonUS shealthunitd25c salestd25c
order parent parentname td25c salestd25c_US  salestd25c_nonUSimp unitd25c sCIT_TWZunitd25c 
 
replace eu = 3 if eu ==2
replace eu = 2 if parent== "EUROP" | parent == "OTE"
replace eu = 2.5 if parent == "EU"
sort eu parent, stable	
drop eu	
								

export excel using "${dta}/Results_benchmark.xlsx", sheetreplace first(var) sheet("Unilateral_min25")
putexcel set "${dta}/Results_benchmark.xlsx", modify sheet("Unilateral_min25")
putexcel (C2:F39), nformat(#0.0)
putexcel (G2:G39), nformat(percent)
putexcel (A1:G1), bold
putexcel (A1:B39), bold
putexcel (A1:A39), border("left", "medium", "black")
putexcel (B1:B39), border("left", "medium", "black")
putexcel (G1:G39), border("right", "medium", "black")
putexcel (G1:G39), border("right", "medium", "black")
putexcel (A39:G39), border("bottom", "medium", "black")
putexcel (A25:G25), border("bottom", "medium", "black")
putexcel (A26:G26), border("bottom", "medium", "black")
putexcel (A1:G1), border("top", "medium", "black")
