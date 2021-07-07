*******************************************************************************
// 3b_imputation

/* This file further integrates and aligns OECD CbCR data and TWZ data, imputes the
tax deficit for non-havens and domestically for parent countries which are only 
covered in TWZ(2019). The tax deficit data is converted from 2016 USD to 2016 EUR. */


set more off


********************************************************************************
// Preparation ECB market exchange rates

use "${dta}/usdeur_xrate.dta", clear

sum usd if year == 2016
scalar usdavg16 = r(mean)
di r(mean)


*********************************************************************************
// MAIN COMPUTATION: Integration of OECD and TWZ data + imputation 				//
*********************************************************************************

// Input full dataset with all ETRs 
foreach etr in c 1 3  {

	use "${dta}/tax_deficit_full.dta",  clear


	keep dset parent* partition  td15`etr' td21`etr' td25`etr' td30`etr' profit


**********************************************************************************
// IMPUTATION of Non-tax havens and domestic tax deficit for TWZ 2019, 2020


// drop SE OECD data because seems bad quality - imputed from TWZ
		drop if parent == "SE" & dset== "OECD"

// Merge tax haven dummy
		merge m:1 parent using "${dta}/th.dta", keepus(TH_TWZ)
		drop if _merge ==2
		drop _merge
		sort dset parent partition

// Dummy for countries without partition to take them out of comp
		gen fjt = 0
		replace fjt = 1  if (parent == "AT" | parent == "NO"  | parent == "NL" | ///
		parent == "FI" | parent == "IE" | parent == "KR" | parent == "SI") & dset == "OECD"
		
// EU-27 Dummy
		gen eu= 2
		replace eu = 1 if parent == "AT" | parent == "BE" | parent == "BG" | parent == "HR" | parent == "CY" | ///
			parent == "CZ" | parent == "DK" | parent == "EE" | parent == "FI" | parent == "FR" | ///
			parent == "DE" | parent == "GR" | parent == "HU" | parent == "IE" | parent == "IT" | ///
			parent == "LV" | parent == "LT" | parent == "LU" | parent == "MT" | parent == "NL" | ///
			parent == "PL" | parent == "PT" | parent == "RO" | parent == "SK" | parent == "SI" | ///
			parent == "ES" | parent == "SE" 
			

// Imputation of nontax havens for TWZ(2019) countries: 
		foreach mint in 15 21 25 30 {
		*Sum of profits booked of EU non-haven countries in nonhavens
			sum profit if dset == "OECD" & partition == 1 & fjt ==0 & TH_TWZ ==. & eu==1 // non-tax havens sum tax deficit
			di "Profit booked in non-havens `r(sum)'"
			scalar nonth = r(sum)
		*Sum of profits booked of EU non-haven countries in havens
			sum profit if dset == "OECD" & partition == 2 & fjt ==0  & TH_TWZ ==. & eu==1 // tax havens' summed tax deficit
			di "Profit booked in havens: `r(sum)'"
			scalar th = r(sum)

			//uprate factor ((min tax rate - 20%)* non-haven profits) / ((min tax rate - 10%) * tax haven profits)
			scalar imp`mint' = ((`mint'/100 - 20/100)* `=nonth') / ((`mint'/100 - 10/100) * `=th')
			di "factor nonhavens / havens, `mint': `=imp`mint''"  
		}
		
		scalar imp15 = 0 // no tax deficit if we assume mean tax rate of 20% in nonTH


// Preparation of Imputation: Expand for non-tax haven observations in TWZ(2019)
	// Create dummy for OECD covered countries (which are not expanded)
		gen help= 0
		replace help = 1 if dset == "OECD"
		sort parent
		by parent, sort: egen OECD = max(help)
		drop help

// Expansion of TWZ observations + Imputation NON-HAVENS
			expand 2 if dset == "TWZ2019" & partition == 2 & OECD == 0, gen(ex) // only non OECD covered ones get imputation
			sort dset parent ex
			replace partition = 1 if ex ==1 // reclassify as non-havens
			//insert imputed values from scalars
			foreach mint in 15 21 25 30 {
				replace td`mint'`etr' = td`mint'`etr' * `=imp`mint'' if dset == "TWZ2019" & partition ==1  & OECD == 0
			} //mint
			drop ex 

	
// Correction for 15 % minimum tax rate: We take the ratio of tax deficits between 25% and 15%
		sum td15`etr' if dset == "OECD" & partition == 1 & fjt ==0 // non tax havens
		di r(sum)
		scalar nTHtd15 = r(sum)		
		sum td25`etr' if dset == "OECD" & partition == 1  & fjt ==0  // non tax havens
		di r(sum)
		scalar nTHtd25 = r(sum)
		scalar nonTH1525 = `=nTHtd15' / `=nTHtd25'
		di `=nonTH1525'
//replace 15% values for TWZ2019 
		sum td15`etr' if eu ==1
		di r(sum)
		replace td15`etr' = td25`etr' * `=nonTH1525' if strpos(dset, "TWZ2019") > 0 & partition ==1
		sum td15`etr' if eu ==1
		di r(sum)
		
	
********************************************************************************	
// Imputation of Domestic Tax deficit for TWZ datasets (TWZ2020, Table A6, uprated to 2016)
	
	//load edited dataset
		merge m:1 parent using "${dta}/twz_locfirms2016.dta"
		drop if _merge ==2
		drop _merge
	//expand TWZ obs to integrate domestic TD
		expand 2 if dset == "TWZ2019" & partition ==2 & OECD == 0, gen(ex) 
		sort dset parent ex
		replace partition = 0 if ex ==1
		foreach mint in 15 21 25 30 {
				replace td`mint'`etr' = (`mint'/100 - locetr)* locprofits if dset == "TWZ2019" & partition ==0 & ex==1
				replace td`mint'`etr' = 0 if td`mint' <0 & dset == "TWZ2019" & partition ==0 & ex==1
		}
			drop ex
			
	drop TH_TWZ locetr locprofits
	
//END Imputations
******************************************************************************

// Conversion from 2016 USD TO 2016 EUR

		gen usdavg16 = `=usdavg16'
		foreach var in td15`etr' td21`etr' td25`etr' td30`etr' profit {
			replace `var' = `var' / usdavg16
		}
		drop usdavg16

		
******************************************************************************		
// Dataset Integration: deciding for observations on overlapping countries

// 1. keep overlap, OECD & European TWZ2019 countries
		keep if (dset == "OECD") | (dset == "TWZ2019" & OECD ==1) | (dset == "TWZ2019" & eu == 1)
		sort eu parent dset partition, stable
		order parent parent1 partition td15 td21 td25 td30 dset
		ren parent1 parentname
		ren partition partner


// 2. Selection TWZ vs. OECD, benchmark in Table 1: since both dataset suffer from blind spots: keep higher tax deficit for tax havens
	//differences in tax deficit: OECD - TWZ2019 --> subsitute OECD data for tax havens by TWZ if diff <0
		sort  parent partner dset, stable
		foreach val in 15 21 25 30 {
				gen diff`val'`etr' = td`val'`etr'[_n] - td`val'`etr'[_n+1] if parent[_n] == parent[_n+1] & dset[_n+1] == "TWZ2019" ///
				& dset[_n]== "OECD" & partner[_n] ==2 & partner[_n+1] >=2
				replace diff`val'`etr' = td`val'`etr'[_n] - td`val'`etr'[_n-1] if parent[_n] == parent[_n-1] & dset[_n-1] == "TWZ2019" ///
				& dset[_n]== "OECD" & partner[_n] ==3 & partner[_n-1] ==2
			}	
	// set cases of lower tax deficit in TH to .
		sort  parent partner dset, stable
		foreach mint in 15 21 25 30 {
				replace td`mint'`etr' = . if diff`mint'`etr' <0 & diff`mint'`etr' !=. & fjt ==0 
				replace td`mint'`etr' = . if diff`mint'`etr'[_n-1] >0 & diff`mint'`etr'[_n-1] !=. & fjt ==0 & parent[_n] == parent[_n-1]
				// for aggregate data no substitution because not comparable
				replace td`mint'`etr' = . if  fjt[_n+1] ==1 & partner[_n] ==2 & partner[_n+1] ==3 & dset[_n] == "TWZ2019" & dset[_n+1] == "OECD"  & parent[_n] == parent[_n+1]
		}
			
	
		drop if td21`etr' ==. & td25`etr' ==. & td30`etr' ==. 
		drop diff* fjt 
					
********************************************************************************
// Output: Table 1 in 2016 bn EUR	

	sort eu parent dset partner, stable
	keep parent parentname partner td* dset

	save "${dta}/table1_oecdtwz2016_etr`etr'.dta", replace
				


}	

