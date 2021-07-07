********************************************************************************
// 3a_oecd_cbcr

/* This file edits the OECD's (2020) CbCR data, calculate effective tax rates and appends
 the tax deficit estimations for tax-haven partners based on TWZ(2019) from 2a_twz_foreign.do. 
We only use the positive profits sample.*/

set more off

insheet using "${data}\CBCR_TABLEI_positive.csv", clear

********************************************************************************
**1) sample restriction and cleaning

// sample restriction: only positive profits sample
keep if grouping == "Sub-Groups with positive profits"

// keep only relevant variables
drop pan grouping variable yea flagcodes flags
keep if cbc== "TAX_PAID" | cbc == "TAX_ACCRUED" | cbc == "PROFIT" //| cbc =="CBCR_COUNT"

// reshape to wide
reshape wide value, j(cbc) i(cou jur) string
ren value* *
ren cou parent
ren jur partner
ren *, lower

// exclude statesless entities
drop if partnerjurisdiction == "Stateless" 

//drop Foreign Jurisdiction Totals when more detailed information available
by parent, sort: gen help = _N
br parent partner help if help ==2
drop if partnerjurisdiction == "Foreign Jurisdictions Total" & help >2 

//integrate statutory rates
merge m:1 partner using "${dta}/stat.dta"
drop if _merge == 2
drop _merge

********************************************************************************
**2) compute ETRs	
//benchmark: pairwise ETRs, tax paid (cash-based)											

//  if tax paid (cash-based) missing replaced by tax accrued
replace tax_paid = tax_accrued if tax_paid ==.

gen ETRc = tax_paid / profit 
//replace with statutory rate if missing
replace ETRc = statrate if ETRc ==. //& _merge !=2

//winsorize outliers
winsor2(ETRc), cut(6 94) 
drop ETRc
ren ETRc_w ETRc
sum ETRc


// b) Alternative (Appendix ETR1): ETR based on aggregates with partner jurisdiction

// Dummy for cases where one component is missing
	gen dum = 0
	replace dum = 1 if  (tax_paid ==. & profit !=.) |  (tax_paid !=. & profit ==.) 

//  sum taxes paid and profits; only zero or positive income taxes included
	foreach v in profit tax_paid {
		gen p`v' = 0
		replace p`v' = `v'  if `v' >= 0
		by partner dum, sort: egen part1_`v' = sum(p`v')
	}
	drop pprofit ptax_paid

	gen ETR1 = part1_tax_paid /part1_profit
	sort partner dum, stable
// fix for CAN which has missing profit or tax_paid
	replace ETR1 = ETR1[_n-1] if dum==1 & partner[_n] == partner[_n-1] 
//FIX for countries with only FJT - since already average -> not averaged again
	replace ETR1 = tax_paid / profit if help ==2 & partner == "FJT" 
// for entire continent as partner, assumption: already averaged -> no averaged
	replace ETR1 = tax_paid / profit if partner == "AFRIC" & parent != "CAN" // for CAN tax_paid missing
	replace ETR1 = tax_paid / profit if partner == "AMER" 
	replace ETR1 = tax_paid / profit if partner == "ASIAT" 
	replace ETR1 = tax_paid / profit if partner == "EUROP" 
// "Other Africa/Europe", since very different countries averaged -> also not averaged again
	replace ETR1 = tax_paid / profit if partner == "OAF" | partner == "OTE" | partner == "OAM" | partner == "GRPS" | partner == "OAS"
// winsorize outliers
	winsor2(ETR1), cut(2 98)
	drop ETR1
	ren ETR1_w ETR1
	replace ETR1 = 0 if ETR1 <0
	drop dum

// c) Alternative: statutory rate minus 5% (Appendix)
	gen ETR3 = statrate - 0.05 
	replace ETR3 = 0 if ETR3 <0


drop help
ren ultimateparentjurisdiction parent1
replace parent1 = "China" if strpos(parent1, "China")


*********************************************************************************
**3. Add TWZ2019  					



* 3a. formating to fit with TWZ2019

keep parent* partner* ETR* profit
gen year = 2016


//parent conversion to iso2
kountry parent, from(iso3c) to(iso2c)
br parent parent1 _ISO2C_ if _ISO2C_==""
drop parent
ren _ISO2C_ parent
replace parent1 = "United States" if parent == "US" 

//Partner conversion to iso2
kountry partner, from(iso3c) to(iso2c)
br partner partnerjurisdiction _ISO2C_ if _ISO2C_==""
replace _ISO2C_ = "JY" if partner== "JEY" //
replace _ISO2C_ = "IM" if partnerjurisdiction== "Isle of Man"
replace _ISO2C_ = "GG" if partner== "GGY" //
replace _ISO2C_ = "BV" if partner== "BVT" //
replace _ISO2C_ = "CW" if partner== "CUW" //
replace _ISO2C_ = partner if _ISO2C_ == "" //
drop partner
ren _ISO2C_ partner
ren partnerjurisdiction partner1
replace partner1 = "United States" if partner == "US" 


order parent* partner* profit ETR*
sort parent partner
gen dset = "OECD"


// 3b computing the tax deficit for OECD

// Estimating the tax deficit in bn 2016USD for OECD countries

// all to bn USD
replace profit = profit / 1000000000 if dset == "OECD"
foreach min in 15 21 25 30 {
	foreach i in c 1 3 { /*3 variants*/
		gen td`min'`i' = ((`min'/100 - ETR`i') *  profit) 
		replace td`min'`i' = 0 if td`min'`i' <0

	}
}


**3c Create grouping of partner jurisdiction into domestic, tax haven, non haven

//merge tax haven indicator
merge m:1 partner using "${dta}/th.dta", keepus(TH_TWZ)
drop if _merge==2
drop _merge

// Dummy for countries without partition
gen fjt = 0
replace fjt = 1  if (parent == "AT" | parent == "SE"  | parent == "NO"  ///
| parent == "NL" | parent == "FI" | parent == "IE" | parent == "KR" | parent == "SI") & dset == "OECD"

// create partner country partition: domestic, tax haven, non-haven
gen partition = 0
replace partition = 1 if parent != partner & TH_TWZ ==.
replace partition = 2 if parent != partner & TH_TWZ ==1
replace partition = 2 if parent != partner & partner == "TX"
replace partition = 3  if fjt ==1 & parent != partner
label var partition "Domestic vs. foreign tax deficit"
label define partition 0 "Domestic" 1 "Foreign, non-tax havens" 2 "Foreign, tax havens" 3 "Aggregate partner data"
label value partition partition


**3d) append TWZ (2019): (10% rate for all TH + sum of positive profits)

append using "${dta}/twzsimple.dta"
replace partition = 2 if dset == "TWZ2019"

*fill all columns for TWZ 2019 with same TD
foreach min in 15 21 25 30 {
	foreach i in 1 3 {
		replace td`min'`i' = td`min'c if dset == "TWZ2019"
	}
}


//* c) Collapse by parent and partner partitions
sort dset parent partition partner

collapse (sum) td15c (sum) td151 (sum) td153  ///
		(sum) td21c  (sum) td211 (sum) td213  ///
		(sum) td25c  (sum) td251 (sum) td253  ///
		(sum) td30c  (sum) td301 (sum) td303  (firstnm) parent1 (sum) profit, by(dset parent partition)

// last formatting for output
order dset parent partition, first
sort dset parent partition


// OUTPUT: dataset with full dataset of OECD and TWZ2019 and both TWZ2019 variants + all ETR variants
save "${dta}/tax_deficit_full.dta",  replace
