*******************************************************************************
//5_2021uprate

/*This do-file rates the tax deficit in 2016 current EUR up to 2021 current EUR assuming
that profits and thus the tax deficit has grown proportionally to nominal GDP. Further, it merges
the tax deficits in 2021 EUR with the shares of tax deficit in CIT revenue and health
expenditure and produces the output tables of the report which are based on macro data.*/



set more off
clear


********************************************************************************
// Load nominal GDP growth rate in EUR

use "${dta}/gdpgrowth.dta", clear

sum upreur2116 if CountryGroupName == "World"
scalar world_upr21 = r(mean)
di r(mean)


*************************************************************************************
//2016 dataset ready for uprate: Table 1

foreach etr in c 1 3 {

	// Load data in 2016 EUR
		use "${dta}/table1_oecdtwz2016_etr`etr'.dta", clear
	
		// EU-27 dummy
		gen eu= 2
		replace eu = 1 if parent == "AT" | parent == "BE" | parent == "BG" | parent == "HR" | parent == "CY" | ///
				parent == "CZ" | parent == "DK" | parent == "EE" | parent == "FI" | parent == "FR" | ///
				parent == "DE" | parent == "GR" | parent == "HU" | parent == "IE" | parent == "IT" | ///
				parent == "LV" | parent == "LT" | parent == "LU" | parent == "MT" | parent == "NL" | ///
				parent == "PL" | parent == "PT" | parent == "RO" | parent == "SK" | parent == "SI" | ///
				parent == "ES" | parent == "SE" 
				

	// 2021 uprate with world nominal GDP in EUR (ass.: profits and tax deficit have risen with the global GDP growth rate)
		foreach min in 15 21 25 30 {
			replace td`min'`etr' = td`min'`etr' * `=world_upr21' 
		}
				
	//merge share of health exp & CIT revenue from 2016
		merge 1:1 parent partner dset using "${dta}/Table1_shares_2016_ETR`etr'.dta", nogen 
		
	// add BG, HR, LT, RO to the output tables	
		expand 2 if parent == "AT", gen(ex)
		replace parent = "BG" if ex==1 & partner == 0
		replace parent = "RO" if ex==1 & partner == 3
		drop ex
		expand 2 if parent == "AT", gen(ex)
		replace parent = "LT" if ex==1 & partner == 0
		replace parent = "HR" if ex==1 & partner == 3
		drop ex
		
		foreach min in 15 21 25 30 {
			replace td`min'`etr' = . if parent == "BG" | parent == "HR" | parent == "LT"  | parent == "RO"
		}
		
		ds *health* *CIT* partner td* 
		foreach v in `r(varlist)' {   
			replace `v' = . if parent == "BG" | parent == "HR" | parent == "LT"  | parent == "RO"
		}
		replace parentname = "Bulgaria" if parent == "BG" 
		replace parentname = "Croatia" if parent == "HR" 
		replace parentname = "Lithuania" if parent == "LT"  
		replace parentname = "Romania" if parent == "RO"
		replace dset = "" if parent == "BG" | parent == "HR" | parent == "LT"  | parent == "RO"
		replace eu = 1 if parent == "BG" | parent == "HR" | parent == "LT"  | parent == "RO"

		//flag countries with TWZ haven data
		preserve
			gen TWZ`etr' = 0
			replace TWZ`etr'= 1 if dset== "TWZ2019"
			collapse (sum) TWZ`etr', by(parent parentname)
			save "${dta}/twz_etr`etr'.dta", replace
		restore
			
		sort eu parent dset partner, stable
		keep parent parentname partner td**`etr' ssCIT_TWZ* sCIT_TWZ* sshealth* shealth* ///
		eu td**_shCIT td**_shhealth dset
	
	
	//save for unilateral computations
		preserve
			keep parent* partner td**`etr'
			collapse (sum) td25`etr' (sum) td15`etr'  (sum) td21`etr' (sum) td30`etr', by(parent parentname)
			save "${dta}/td_etr`etr'_2021.dta", replace
		restore	
	
	//drop BM & SG for main tables
		drop if parent == "BM" | parent == "SG"

*********************************************************************************
// OUTPUT
		
	//Table 1: 25% absolute TD, % CIT, % health, no partition
	foreach min in  25 15 21 30 {
			preserve
			
			keep parent* partner td`min'`etr' sshealth`min' ssCIT_TWZ`min' eu td`min'_shCIT td`min'_shhealth
			
			collapse (sum) td`min'`etr' (mean) sshealth`min' (mean) ssCIT_TWZ`min' (mean) eu ///
			(mean) td`min'_shCIT (mean) td`min'_shhealth, by(parent parentname)
			
		//insert sums for EU	
			expand 2 if parent == "AT", gen(ex)
			replace parentname = "EU total" if ex== 1
			replace parent = "EU" if ex== 1
			replace eu = 1.5 if ex== 1
			sum td`min'_shhealth
			replace sshealth`min' = r(mean) if ex== 1
			sum td`min'_shCIT
			replace ssCIT_TWZ`min' = r(mean) if ex== 1
			sum td`min'`etr' if eu ==1
			replace td`min'`etr' = r(sum) if ex== 1
			drop td`min'_shCIT td`min'_shhealth ex
			
			replace td`min'`etr' = . if parent == "BG" | parent == "HR" | parent == "LT"  | parent == "RO"

			order parent* td`min'`etr' sshealth`min' ssCIT_TWZ`min', first
			sort eu parent, stable
			drop eu
		
			if `min' == 25 & "`etr'" == "c" {
				save "${dta}/table1_oecdtwz_2021_etr`etr'_min`min'.dta", replace
			}
			if "`etr'" == "c" {
			export excel using "${dta}/Results_benchmark.xlsx", sheetreplace firstrow(var) sheet("Table1_2021_min`min'")
				putexcel set "${dta}/Results_benchmark.xlsx", modify sheet("Table1_2021_min`min'")	
			}
			if "`etr'" != "c" {
			export excel using "${dta}/Results_ETR`etr'.xlsx", sheetreplace firstrow(var) sheet("Table1_2021_min`min'")
				putexcel set "${dta}/Results_ETR`etr'.xlsx", modify sheet("Table1_2021_min`min'")	
			 }	
				putexcel (C2:I150), nformat(#0.0)
				putexcel (D2:E150), nformat(percent)
				putexcel (A1:I1), bold
				putexcel (A1:B42), bold
				putexcel (A1:A42), border("left", "medium", "black")
				putexcel (B1:B42), border("left", "medium", "black")
				putexcel (E1:E42), border("right", "medium", "black")
				putexcel (B1:B42), border("right", "thin", "black")
				putexcel (C1:C42), border("right", "thin", "black")
				putexcel (A28:E28), border("bottom", "medium", "black")
				putexcel (A29:E29), border("bottom", "medium", "black")
				putexcel (A42:E42), border("bottom", "medium", "black")
				putexcel (A1:E1), border("top", "medium", "black")
				putexcel (A1:E1), border("bottom", "medium", "black")
			restore
		} //min

		
	//Table A1 reshaped: 25% absolute TD, partition
		foreach min in 25 15 21 {
			preserve
			keep parent* partner td`min'`etr' eu
			
			by eu partner, sort: egen EUtd`min'`etr' = sum(td`min'`etr')
			replace EUtd`min'`etr' = . if eu ==2
			replace EUtd`min'`etr' = . if (parent == "BG" | parent == "HR" | parent == "LT"  | parent == "RO")

			
			drop if td`min'`etr'==. & partner == 2 // Brazil
			replace partner = 3 if partner == .
			reshape wide td`min'`etr' EUtd`min'`etr' , i(eu parent parentname) j(partner)
			
			//insert sums for EU	
			expand 2 if parent == "AT", gen(ex)
			replace parentname = "EU total" if ex== 1
			replace parent = "EU" if ex== 1
			replace eu = 1.5 if ex== 1
			forval i = 0/3 {
				sum EUtd`min'`etr'`i' if EUtd`min'`etr'`i' !=.
				replace td`min'`etr'`i' = r(mean) if ex== 1
			}
			drop ex EUtd*
			
			//rename
			ren td`min'`etr'0 td`min'`etr'domestic
			ren td`min'`etr'1 td`min'`etr'nonhaven
			ren td`min'`etr'2 td`min'`etr'taxhaven
			ren td`min'`etr'3 td`min'`etr'aggregate
			
			order parent parentname td**c* eu
			sort eu parent, stable
			drop eu
			
			if "`etr'" == "c" {
			export excel using "${dta}/Results_benchmark.xlsx", sheetreplace firstrow(var) sheet("TableA1_min`min'")
				putexcel set "${dta}/Results_benchmark.xlsx", modify sheet("TableA1_min`min'")	
			}	
			if "`etr'" != "c" {
				export excel using "${dta}/Results_ETR`etr'.xlsx", sheetreplace firstrow(var) sheet("TableA1_min`min'")
				putexcel set "${dta}/Results_ETR`etr'.xlsx", modify sheet("TableA1_min`min'")	
			}	
				putexcel (C2:F42), nformat(#0.0)
				putexcel (A1:F1), bold
				putexcel (A1:B108), bold
				putexcel (A1:A42), border("left", "medium", "black")
				putexcel (B1:B42), border("left", "medium", "black")
				putexcel (F1:F42), border("right", "medium", "black")
				putexcel (A28:F28), border("bottom", "medium", "black")
				putexcel (A29:F29), border("bottom", "medium", "black")
				putexcel (A42:F42), border("bottom", "medium", "black")
				putexcel (A1:F1), border("top", "medium", "black")
				putexcel (A1:F1), border("bottom", "medium", "black")
				restore
			} // min
	
	//Table 2: TD of all rates in bn EUR	
		preserve
		
		keep parent* partner td**`etr' eu
		collapse (sum) td15`etr' (sum) td21`etr' (sum) td25`etr' (sum) td30`etr' (mean) eu, by(parent parentname)	
		
		foreach r in 15 21 25 30 {
			by eu, sort: egen EUtd`r'`etr' = sum(td`r'`etr')
			replace EUtd`r'`etr' = . if eu ==2		
		}
		//insert sums for EU	
			expand 2 if parent == "AT", gen(ex)
			replace parentname = "EU total" if ex== 1
			replace parent = "EU" if ex== 1
			replace eu = 1.5 if ex== 1
			foreach i in 15 21 25 30 {
				sum EUtd`i'`etr' if EUtd`i'`etr' !=.
				replace td`i'`etr' = r(mean) if ex== 1
			}
			drop ex EUtd*
		
		
		order parent* td15`etr' td21`etr' td25`etr' td30`etr', first
		sort eu parent, stable
		drop eu
		
		save "${dta}/table2_oecdtwz_2021_etr`etr'.dta", replace
		if "`etr'" == "c" {
		export excel using "${dta}/Results_benchmark.xlsx", sheetreplace firstrow(var) sheet("Table2")
			putexcel set "${dta}/Results_benchmark.xlsx", modify sheet("Table2")
		}	
		if "`etr'" != "c" {
			export excel using "${dta}/Results_ETR`etr'.xlsx", sheetreplace firstrow(var) sheet("Table2")
			putexcel set "${dta}/Results_ETR`etr'.xlsx", modify sheet("Table2")
		}	
			putexcel (C2:F42), nformat(#0.0)
			putexcel (A1:F1), bold
			putexcel (A1:B42), bold
			putexcel (A1:A42), border("left", "medium", "black")
			putexcel (B1:B42), border("left", "medium", "black")
			putexcel (F1:F42), border("right", "medium", "black")
			putexcel (B1:B42), border("right", "thin", "black")
			putexcel (A28:F28), border("bottom", "medium", "black")
			putexcel (A29:F29), border("bottom", "medium", "black")
			putexcel (A42:F42), border("bottom", "medium", "black")
			putexcel (A1:F1), border("top", "medium", "black")
			putexcel (A1:F1), border("bottom", "medium", "black")
		restore
	
	
	
	//Table A2: TD in % of CIT revenue & health of all rates in bn EUR	
		preserve
		
		keep parent* partner sshealth* ssCIT_TWZ* td**_shCIT td**_shhealth eu

		collapse (mean) ssCIT_TWZ15 (mean) ssCIT_TWZ21 (mean) ssCIT_TWZ25 (mean) ssCIT_TWZ30 ///
		(mean) sshealth15 (mean) sshealth21 (mean) sshealth25 (mean) sshealth30 (mean) eu ///
		(mean) td15_shCIT (mean) td21_shCIT (mean) td25_shCIT (mean) td30_shCIT ///
		(mean) td15_shhealth (mean) td21_shhealth (mean) td25_shhealth (mean) td30_shhealth , by(parent parentname)
		
		//insert sums for EU	
			expand 2 if parent == "AT", gen(ex)
			replace parentname = "EU total" if ex== 1
			replace parent = "EU" if ex== 1
			replace eu = 1.5 if ex== 1
			foreach min in 15 21 25 30 {
				sum td`min'_shhealth
				replace sshealth`min' = r(mean) if ex== 1
				sum td`min'_shCIT
				replace ssCIT_TWZ`min' = r(mean) if ex== 1
			}
			drop td**_shCIT td**_shhealth ex
		
		sort eu, stable
		drop eu

		if "`etr'" == "c" {
			export excel using "${dta}/Results_benchmark.xlsx", sheetreplace firstrow(var) sheet("TableA2")
			putexcel set "${dta}/Results_benchmark.xlsx", modify sheet("TableA2")
		}
		if "`etr'" != "c" {
			export excel using "${dta}/Results_ETR`etr'.xlsx", sheetreplace firstrow(var) sheet("TableA2")
			putexcel set "${dta}/Results_ETR`etr'.xlsx", modify sheet("TableA2")
		}
			putexcel (C2:S42), nformat(percent)
			putexcel (A1:S1), bold
			putexcel (A1:B42), bold
			putexcel (A1:A42), border("left", "medium", "black")
			putexcel (B1:B42), border("left", "medium", "black")
			putexcel (J1:J42), border("right", "medium", "black")
			putexcel (F1:F42), border("right", "medium", "black")
			putexcel (B1:B42), border("right", "thin", "black")
			putexcel (A28:J28), border("bottom", "medium", "black")
			putexcel (A29:J29), border("bottom", "medium", "black")
			putexcel (A42:J42), border("bottom", "medium", "black")
			putexcel (A1:J1), border("top", "medium", "black")
			putexcel (A1:J1), border("bottom", "medium", "black")
		restore	
		
	
	//Table maps: 25% absolute TD, partition +  shares (basis for Figure1)
	foreach min in 25 15 21 30 {
		preserve
		keep parent* partner td`min'`etr' shealth`min' sCIT_TWZ`min' eu  td`min'_shCIT td`min'_shhealth
		
		keep parent* partner td`min'`etr'  shealth`min'  sCIT_TWZ`min' eu
		drop if td`min'`etr'==. & partner == 2 // Brazil
		replace partner = 3 if partner == .
		reshape wide td`min'`etr' shealth`min' sCIT_TWZ`min' , i(eu parent parentname) j(partner)
		
		//sum of foreign & rename
		foreach var in td`min'`etr' shealth`min' sCIT_TWZ`min' {
			gen `var'foreign = `var'1 + `var'2
			replace `var'foreign = `var'3 if `var'foreign ==.
			ren `var'0 `var'domestic
			drop `var'1 `var'2 `var'3
		}
		

		order parent* td`min'`etr'* shealth`min'* sCIT_TWZ`min'* 
		sort eu parent, stable
		drop eu
		
	if "`etr'" == "c" {
		export excel using "${dta}/Results_benchmark.xlsx", sheetreplace firstrow(var) sheet("TableMaps_min`min'")
			putexcel set "${dta}/Results_benchmark.xlsx", modify sheet("TableMaps_min`min'")
	}
	if "`etr'" != "c" {
		export excel using "${dta}/Results_ETR`etr'.xlsx", sheetreplace firstrow(var) sheet("TableMaps_min`min'")
			putexcel set "${dta}/Results_ETR`etr'.xlsx", modify sheet("TableMaps_min`min'")
	}
			putexcel (C2:D41), nformat(#0.0)
			putexcel (E2:H41), nformat(percent)
			putexcel (A1:H1), bold
			putexcel (A1:B41), bold
			putexcel (A1:A41), border("left", "medium", "black")	
			putexcel (B1:B41), border("left", "medium", "black")
			putexcel (B1:B41), border("right", "thin", "black")
			putexcel (D1:D41), border("right", "medium", "black")
			putexcel (F1:F41), border("right", "medium", "black")
			putexcel (H1:H41), border("right", "medium", "black")
			putexcel (A41:H41), border("bottom", "medium", "black")
			putexcel (A1:H1), border("top", "medium", "black")
			putexcel (A1:H1), border("bottom", "medium", "black")
	
			restore	
		} // min
		
		
					
			
} // End ETR	



//Table Appendix: TD for other ETRs	

	//merge different ETR specifications
		use "${dta}/table2_oecdtwz_2021_etrc.dta", clear
		
		merge 1:1 parent parentname using "${dta}/table2_oecdtwz_2021_etr1.dta", nogen
		merge 1:1 parent parentname using "${dta}/table2_oecdtwz_2021_etr3.dta", nogen
		
	//integrate indicator for TWZ substitution
	foreach etr in c 1 3 {
		merge 1:1 parent parentname using "${dta}/twz_etr`etr'.dta"
		drop if _merge ==2
		drop _merge
	}

	//keep only OECD CBCR countries (only relevant for those)			
		gen OECD = 0
		replace OECD = 1 if parent == "AT" | parent == "BE" | parent == "AU" | parent == "BM" ///
		| parent == "BR" | parent == "CA" | parent == "CL" | parent == "CN" | parent == "DK" ///
		| parent == "FI" | parent == "FR" | parent == "IN" | parent == "ID" | parent == "IE" ///
		| parent == "IT" | parent == "JP" | parent == "KR" | parent == "LU" | parent == "MX" ///
		| parent == "NL" | parent == "NO" | parent == "SG" | parent == "SI" /*| parent == "SE"*/ ///
		| parent == "US" | parent == "ZA" 
		
		keep if OECD==1 
		
	// EU-27 dummy
		gen eu= 2
		replace eu = 1 if parent == "AT" | parent == "BE" | parent == "BG" | parent == "HR" | parent == "CY" | ///
				parent == "CZ" | parent == "DK" | parent == "EE" | parent == "FI" | parent == "FR" | ///
				parent == "DE" | parent == "GR" | parent == "HU" | parent == "IE" | parent == "IT" | ///
				parent == "LV" | parent == "LT" | parent == "LU" | parent == "MT" | parent == "NL" | ///
				parent == "PL" | parent == "PT" | parent == "RO" | parent == "SK" | parent == "SI" | ///
				parent == "ES" | parent == "SE" 	
		
	//final editing
		ren *c *cash
		ren *1 *avgETR
		ren *3 *stat

		sort eu parent, stable
		drop OECD eu

		
			export excel using "${dta}/Results_benchmark.xlsx", sheetreplace firstrow(var) sheet("TableA3_min`min'")
			putexcel set "${dta}/Results_benchmark.xlsx", modify sheet("TableA3_min`min'")
				putexcel (C2:N24), nformat(#0.0)
				putexcel (A1:Q1), bold
				putexcel (A1:B24), bold
				putexcel (A1:A24), border("left", "medium", "black")
				putexcel (B1:B24), border("left", "medium", "black")
				putexcel (B1:B24), border("right", "medium", "black")
				putexcel (F1:F24), border("right", "medium", "black")
				putexcel (J1:J24), border("right", "medium", "black")
				putexcel (N1:N24), border("right", "medium", "black")
				putexcel (Q1:Q24), border("right", "medium", "black")
				putexcel (B1:B24), border("right", "thin", "black")
				putexcel (A24:Q24), border("bottom", "medium", "black")
				putexcel (A1:Q1), border("top", "medium", "black")
				putexcel (A1:Q1), border("bottom", "medium", "black")
			

