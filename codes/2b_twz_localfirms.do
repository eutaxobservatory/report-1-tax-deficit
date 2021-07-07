************************************************************************
// 2b_twz_localfirms

/*This file edits the data by TWZ(2018, data appendix updated 2020, Sheet Table A6) on 
profits and effective tax rates of domestic firms for further calculations. */

set more off
clear

********************************************************************************
// extract nominal USD GDP growth rates from 2015 to 2016

use "${dta}/gdpgrowth.dta", clear

// nominal USD GDP growth rates
sum uprusd1615 if CountryGroupName == "World"
scalar world_upr16 = r(mean)
sum uprusd1615 if CountryGroupName == "European Union"
scalar eu_upr16 = r(mean)

*******************************************************************************

//load TWZ 2018/2020
import excel using "${data}/TWZ2020AppendixTables.xlsx", clear sheet("TableA6")

// data edit
keep A K L 
drop if _n>=90
drop if _n<=9

ren A countryname
ren K locprofits
ren L locetr
destring loc*, replace

//retrieve iso2 from countrynames
merge 1:1 countryname using "${data}/iso-country.dta"
replace iso = "US" if countryname == "United States"
replace iso = "SX" if countryname == "Sint Maarten"
replace iso = "MO" if countryname == "Macau"
replace iso = "GI" if countryname == "Gribraltar"
replace iso = "LC" if countryname == "St. Lucia"
replace iso = "RU" if countryname == "Russia"
replace iso = "VC" if countryname == "St. Vincent and the Grenadines"
replace iso = "TC" if countryname == "Turks and Caicos"
replace iso = "IM" if countryname == "Isle of man"
replace iso = "BQ" if countryname == "Bonaire"
replace iso = "VG" if countryname == "BVI"
replace iso = "KN" if countryname == "St. Kitts and Nevis"
drop if iso ==""
rename iso parent
drop if _merge ==2
drop _merge

// gen EU-27 indicator
gen eu= 2
replace eu = 1 if parent == "AT" | parent == "BE" | parent == "BG" | parent == "HR" | parent == "CY" | ///
		parent == "CZ" | parent == "DK" | parent == "EE" | parent == "FI" | parent == "FR" | ///
		parent == "DE" | parent == "GR" | parent == "HU" | parent == "IE" | parent == "IT" | ///
		parent == "LV" | parent == "LT" | parent == "LU" | parent == "MT" | parent == "NL" | ///
		parent == "PL" | parent == "PT" | parent == "RO" | parent == "SK" | parent == "SI" | ///
		parent == "ES" | parent == "SE" 
tab eu, mis

		
// inflation of profits to 2016 USD
replace locprofits = locprofits * `=eu_upr16' if eu ==1	
replace locprofits = locprofits * `=world_upr16' if eu ==2	

keep parent locprofits locetr

//FIX Germany ETR (taken from OECD's CBCR average ETR)
replace locetr = 0.2275 if parent == "DE"

save "${dta}/twz_locfirms2016.dta", replace
