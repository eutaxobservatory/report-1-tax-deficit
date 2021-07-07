*************************************************************************
// 1b_statrates

// This do-file prepares KPMG statutory rates for replacing missing ETRs in the OECD
// data.

import excel using "${data}\KPMG_statutoryrates.xlsx" , clear 

//data editing

// keep year 2016
keep A H
drop if _n==1
ren A partner
ren H statrate

drop if partner ==""
replace statrate = "" if statrate == "-"
destring statrate, replace 
 
// drop duplicates 
duplicates tag partner, gen(dup)
drop if dup ==1 & dup[_n-1]==1 & partner == partner[_n-1]
drop dup

// edit world region partner country names to match OECD
replace partner = "EUROP" if partner == "EUROPE"
replace partner = "AMER" if partner == "AMERICA"
replace partner = "AFRIC" if partner == "AFRICA"
replace partner = "ASIAT" if partner == "ASIA"
// foreign jurisdictions total
replace partner = "FJT" if partner == "GLOBAL" 

// other jurisdictions to match OECD countries
*Other Africa = average African stat rate
expand 2 if partner == "AFRIC", gen(ex)
replace partner = "OAF" if ex==1 // other africa
drop ex
*Other Asia = average Asian stat rate
expand 2 if partner == "ASIAT", gen(ex)
replace partner = "OAS" if ex==1 
drop ex
*Other EUROPE = average European stat rate
expand 2 if partner == "EUROP", gen(ex)
replace partner = "OTE" if ex==1 
drop ex
*Other America
expand 2 if partner == "AMER", gen(ex)
replace partner = "OAM" if ex==1 
drop ex
*Other Groups
expand 2 if partner == "FJT", gen(ex)
replace partner = "GRPS" if ex==1 
drop ex


replace statrate = statrate / 100


save "${dta}\stat.dta", replace
