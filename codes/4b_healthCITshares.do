*******************************************************************************
// 4b_healthCITshares

/*This file computes the share of tax deficit in the health expenditure and corporate
income tax revenue of each country and for the EU. Aggregates were edited in 4a_CITrevenue.do.
Share are based on tax deficits in 2016 EUR and health expenditure and CIT revenue aggregates
in 2016 EUR.*/


set more off 
clear 


foreach etr in c 1 3 {

		//load TD in bn 2016 EUR	
			use "${dta}/table1_oecdtwz2016_etr`etr'.dta", clear
			
			
		// merge health expenditure in 2016 bn EUR 
			merge m:1 parent using "${dta}/health.dta"	
			keep if _merge ==3  
			drop _merge
		// merge CIT revenue in 2016 bn EUR (TWZ directly)	
			merge m:1 parent using "${dta}/citrev.dta", nogen
			

		// compute share of tax deficit in health exp. & CIT revenue 
			foreach min in 15 21 25 30 {
			//sum all tax deficit per parent
				by parent, sort: egen std`min' = sum(td`min')

			//shares health
				*by parent partner
				gen shealth`min' = td`min'/ health
				*sum by parent
				gen sshealth`min' = std`min'/ health

				// shares CIT
				gen sCIT_TWZ`min' = td`min' / CIT_TWZ
				gen ssCIT_TWZ`min' = std`min' / CIT_TWZ
			} // min
	
	
		// EU -27 dummy
			gen eu= 2
			replace eu = 1 if parent == "AT" | parent == "BE" | parent == "BG" | parent == "HR" | parent == "CY" | ///
				parent == "CZ" | parent == "DK" | parent == "EE" | parent == "FI" | parent == "FR" | ///
				parent == "DE" | parent == "GR" | parent == "HU" | parent == "IE" | parent == "IT" | ///
				parent == "LV" | parent == "LT" | parent == "LU" | parent == "MT" | parent == "NL" | ///
				parent == "PL" | parent == "PT" | parent == "RO" | parent == "SK" | parent == "SI" | ///
				parent == "ES" | parent == "SE" 
			by parent, sort: gen help = _n	
			sum eu if eu ==1 & help ==1 // only 23 EU countries in dataset
			di r(sum)
			

			// Aggregate CIT revenue EU-23 (all EU countries in dset)
			sum CIT_TWZ if eu ==1  & help ==1
			gen CITTWZ_EU23 = r(sum) 
			di "CIT TWZ EU23: `r(sum)'"
			
			//Aggregate tax deficit in EU-23 (all EU countries in dset)
			foreach min in 15 21 25 30 {
				sum td`min'`etr' if eu ==1
				gen std`min'EU23 = r(sum)
				di "Sum Tax Deficit, min rate `min'% EU23: `r(sum)'"
			}
			
			//Aggregate of health expenditure in EU-23 (all EU countries in dset)
			sum health if eu ==1 & help ==1
			gen health_EU23 = r(sum)
			di "Health expenditure EU23: `r(sum)'"
				
			//share in CIT revenue, entire EU23		
			foreach min in 15 21 25 30 {
					gen td`min'_shCIT = std`min'EU23 /CITTWZ_EU23
				}

			//share in health expenditure, entire EU23
			foreach min in 15 21 25 30 {
					gen td`min'_shhealth = std`min'EU23 /health_EU23
			}
				
			
			
			keep parent partner shealth* sshealth* sCIT_TWZ* ssCIT_TWZ* td**_shCIT ///
			td**_shhealth  dset

			save "${dta}/table1_shares_2016_etr`etr'.dta", replace

		}

