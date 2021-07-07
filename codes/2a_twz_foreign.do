************************************************************************
// 2a_twz_foreign

/*This file edits the data by TWZ(2019) on profits booked in tax havens. We assume an
effective tax rate of 10% in tax havens to estimate the tax deficit. */

set more off
clear


************************************************************************
// 1. Booked profits data from TWZ(2019), TableC4, ultimate ownership


	import excel using "${data}/TWZ2019_2016update.xlsx", clear sheet("TableC4")

// keep only ultimate ownership
	keep A B N-X

// data cleaning
	drop if _n >=98 | _n <=5

	ren A country1
	ren B countryname
	foreach var in N O P Q R S T U V W X {
		replace `var' =subinstr(`var'," ","",.) if _n==1
		replace `var' =subinstr(`var',"-","",.) if _n==1
		rename `var' `=`var'[1]'
	}
	drop if _n<=2

// drop world regions & sums 
	drop if countryname == "World total" | countryname  == "Rest of world" | ///
		strpos(countryname , "OECD") >0 | countryname == "Main developing countries"

// edit countrynames		
	replace countryname = country1 if country1 == "Gibraltar"
	replace countryname = "British Virgin Islands" if countryname == "BVI"
	replace countryname = country1 if countryname == "Russia"
	drop country1

// create iso2
	merge 1:1 countryname using "${data}/iso-country.dta"
	br countryname iso if _merge ==1
	// manual fixes
	replace iso = "BQ" if countryname == "Bonaire"
	replace iso = "VG" if countryname == "British Virgin Islands"
	replace iso = "IM" if countryname == "Isle of man"
	replace iso = "MO" if countryname == "Macau"
	replace iso = "SX" if countryname == "Sint Maarten"
	replace iso = "KN" if countryname == "St. Kitts and Nevis"
	replace iso = "LC" if countryname == "St. Lucia"
	replace iso = "VC" if countryname == "St. Vincent and the Grenadines"
	replace iso =  "TC" if countryname == "Turks and Caicos"
	replace iso = "US" if countryname == "United States"
	drop if _merge ==2
	drop _merge

// drop parent countries without information
	drop if Allhavens == "" & EUhavens == "" & Belgium == "" & Cyprus == "" & ///
		Ireland == "" & Luxembourg == "" & Malta == "" & Netherlands == "" & ///
		NonEUtaxhavens == "" & Switzerland == "" & Rest == "" 
		
	destring Allhavens EUhavens Belgium Cyprus Ireland Luxembourg Malta Netherlands NonEUtaxhavens Switzerland Rest, replace

// checks
	gen check = Allhavens - (Belgium + Cyprus + Ireland + Luxembourg + Malta + Netherlands ///
	+ Switzerland + Rest)
	sum check
	gen checkEU = EUhavens - (Belgium + Cyprus + Ireland + Luxembourg + Malta + Netherlands)
	sum checkEU
	gen checknonEU = NonEUtaxhavens - (Switzerland + Rest)
	sum checknonEU


// build sum of positive profits
	foreach th in Belgium Cyprus Ireland Luxembourg Malta Netherlands Switzerland Rest {
		replace `th' =0 if `th'<0
	}
	gen profit = Belgium + Cyprus + Ireland + Luxembourg + Malta + Netherlands + Switzerland + Rest
// exclude domestically booked profits for CY and MT
	replace profit = Belgium + Ireland + Luxembourg + Malta + Netherlands + Switzerland + Rest if countryname == "Cyprus"
	replace profit = Cyprus + Belgium + Ireland + Luxembourg + Netherlands + Switzerland + Rest if countryname == "Malta"
// convert from million to bn 
	replace profit = profit /1000

	keep countryname profit iso
	ren iso parent
	ren countryname parent1

//computing the tax deficit assuming a tax rate of 10% in tax havens
	foreach min in 15 21 25 30 {
		gen td`min'c = ((`min'/100 - 0.1) *  profit)   // in bn
		replace td`min'c = 0 if td`min' <0
	}

	gen dset = "TWZ2019"
	gen partner = "ATX" 
	gen ETRc = 0.1

	
	save "${dta}/twzsimple.dta", replace

