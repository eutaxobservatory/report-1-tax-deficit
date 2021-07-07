*******************************************************************************
//4a_CITrevenue

/*This do-file edits corporate income tax revenue & health expenditure aggregates. */


set more off
clear


********************************************************************************
// Load ECB market exchange rates

use "${dta}/usdeur_xrate.dta", clear

sum usd if year == 2016
scalar usd16 = r(mean)
di r(mean)


********************************************************************************


/// 1) TWZ(2019); CIT revenue in bn current USD

import excel using "${data}/TWZ2019_2016update.xlsx", clear sheet("Table U1")

//data edit
keep A-D
drop if _n >= 88
drop if _n <=7
ren A iso3
ren B countryname
ren C GDP_TWZ
ren D CIT_TWZ

//drop world region totals
drop if countryname == "World total" | countryname  == "Rest of world" | ///
		 countryname == "Main developing countries" | countryname == "Non-OECD tax havens"
		 
//edit countrynames & iso codes		
replace iso3 = "BHR" if countryname == "Bahrain"
replace iso3 = "MAC" if countryname == "Macau"
replace iso3 = "HKG" if countryname == "Hong Kong"
replace iso3 = "MHL" if countryname == "Marshall Islands"
replace iso3 = "VGB" if countryname == "British Virgin Islands"

kountry iso3, from(iso3c) to(iso2c)
ren _ISO2C_ partner
replace partner = "BQ" if countryname == "Bonaire"
replace partner = "IM" if countryname == "Isle of man"
replace partner = "JY" if countryname == "Jersey"
replace partner = "SX" if countryname == "Sint Maarten"
replace partner = "CW" if countryname == "Curacao"
replace partner = "GG" if countryname == "Guernsey"
replace partner = "TX" if countryname == "Non-OECD tax havens"
ren partner parent

destring GDP* CIT*, replace

// EU-27 dummy
gen eu= 0
replace eu = 1 if parent == "AT" | parent == "BE" | parent == "BG" | parent == "HR" | parent == "CY" | ///
		parent == "CZ" | parent == "DK" | parent == "EE" | parent == "FI" | parent == "FR" | ///
		parent == "DE" | parent == "GR" | parent == "HU" | parent == "IE" | parent == "IT" | ///
		parent == "LV" | parent == "LT" | parent == "LU" | parent == "MT" | parent == "NL" | ///
		parent == "PL" | parent == "PT" | parent == "RO" | parent == "SK" | parent == "SI" | ///
		parent == "ES" | parent == "SE" 

// OECD-CBCR dummy
gen OECD = 0
replace OECD =1 if parent == "AU" | parent == "BR" | parent == "CA" | parent == "CL" | parent == "CN" ///
					| parent == "ID" | parent == "IN" | parent == "JP" | parent == "KR" | parent == "MX" ///
					| parent == "NO" | parent == "US" | parent == "ZA" | parent == "SG" | parent == "BM"

// Sample restriction
keep if OECD ==1 | eu ==1
drop countryname

// convert to 2016 EUR
gen usdeur = `=usd16'
replace CIT_TWZ = CIT_TWZ / usdeur

//save
keep parent CIT_TWZ
order parent CIT_TWZ
save "${dta}/citrev.dta", replace
*export excel using "${dta}/citrev.xlsx", replace first(var)


*********************************************************************************
// Preparation: Reading in Health spending data

// health care expenditure & CIT Revenue in mln EUR
import excel using "${data}/CIT_revenues_and_health_expenditures.xlsx", sheet("Summary - 2016") clear

//data edit & format
drop if _n<=5
drop L M

// renaming
ren D country
ren E iso	
ren F health_EUROSTAT
ren G health_WHO
ren H CIT_GRD
ren I CIT_EUROSTAT
ren J CIT_OECD
ren K CIT_TWZ

drop if _n<=2
destring health*, replace force

// iso2 codes
kountry iso, from(iso3c) to(iso2c)
ren _ISO2C_ parent
replace parent = "JY" if iso == "JEY"
replace parent = "GG" if iso == "GGY"
replace parent = "IM" if iso  =="IMN"

// health expenditure data: mainly EUROSTAT and for non-EU countries WHO
gen health = health_EUROSTAT
replace health = health_WHO if health ==.

// m to bn
replace health = health / 1000 

// eliminate duplicates
duplicates tag parent, gen(dup)
sort parent, stable
replace dup = 0 if dup[_n] ==1 & dup[_n-1] & parent[_n] == parent[_n-1]
drop if dup ==1
drop dup

//save
keep parent health
save "${dta}/health.dta",  replace

