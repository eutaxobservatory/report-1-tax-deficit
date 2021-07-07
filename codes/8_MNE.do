*******************************************************************************
//8_MNE

/*This do-file calculates the tax deficit for 16 non-bank multinationals under a 
25% minimum tax. Data is based on 2019 reports and uprated to 2021 current EUR. */

set more off
clear

********************************************************************************
// Load nominal GDP growth rate in EUR 2019-2021

use "${dta}/gdpgrowth.dta", clear

sum upreur2119 if CountryGroupName == "European Union"
scalar EU_upr21 = r(mean)
di r(mean)

********************************************************************************
// load MNE data
import excel using "${data}\MNE_cbcr2019.xlsx", sheet("MNE") firstrow clear

keep Year Profitlossbeforetax  Corporateincometaxespaidref Thlist ///
Partnercountrycode Headquartercountrycode Company Headquartercountrycode
     
// data edit 
encode(Partnercountrycode), gen(countrycode)
encode(Company), gen(MNEs)
encode(Headquartercountrycode), gen(parentcode)
// restrict to positive profits
drop if Profitlossbeforetax<0
**currency in millions of euros:
ren Profitlossbeforetax EBT 
ren Corporateincometaxespaidref TAX


**ETR calculation:

//merge stat rates KPMG
gen partner = Partnercountrycode
merge m:1 partner using  "${dta}/stat.dta"
drop if _merge ==2
drop _merge

gen ETR=TAX/EBT
replace ETR = statrate if ETR==.
// manual fixes
replace ETR = 0.1 if Partnercountrycode=="TLS" & ETR ==. // tax summaries PWC (https://taxsummaries.pwc.com/timor-leste/corporate/taxes-on-corporate-income#:~:text=The%20income%20of%20companies%20is,a%20flat%20rate%20of%2010%25.)
replace ETR = 0.3 if Partnercountrycode=="GAB" & ETR ==.  //OECD corporate tax statistics database
// winsorize outliers
winsor2(ETR),cut(5 95)

***Calculate the tax deficit: 
	foreach r in 15 21 25 30 {
    **Tax difference : (minium tax - ETR) 
	gen T`r'_ETR= `r'/100 - ETR_w	
	**drop negative tax differences
	replace T`r'_ETR = 0 if T`r'_ETR < 0	
    **Tax deficit : multiply difference in tax rates by profits booked
     gen TD_`r'_ETR= T`r'_ETR* EBT
	}
	
	
//collapse: sum tax deficit & tax paid by MNE
	collapse (sum) TD_15_ETR (sum) TD_21_ETR (sum) TD_25_ETR (sum) TD_30_ETR ///
				(sum) TAX (firstnm) Company (firstnm) Headquartercountrycode , by(MNEs) 
	 
	
	** Uprate from 2019 to 2021 (nominal GDP growth in EUR)
	di `=EU_upr21'
	foreach r in 15 21 25 30 {
		gen TD21_`r' = TD_`r'_ETR*`=EU_upr21'
	}
	gen taxpaid21 = TAX * `=EU_upr21'

	**TOTALS : corporate taxes overall
 	egen taxpaid19total=total( TAX )
	egen taxpaid21total=total(taxpaid21)
    **TOTALS: TD totals
    foreach r in 15 21 25 30 {
		egen TD19total`r' = total(TD_`r'_ETR) 
		egen TD21total`r' = total(TD21_`r') 
    }
		
	**Tax deficit as share of  of taxes paid (2019 numbers)
  foreach r in 15 21 25 30 {
	gen td_ratio`r'= TD_`r'_ETR/ TAX
	replace td_ratio`r'= . if TAX<=0

  ** overal TD as share of corptax
	gen ratiototal`r' = TD19total`r'/ taxpaid19total
  }
	
   //gen indicator for sorting
	gen sort =1
	
	// insert SUM of MNE line 
	expand 2 if Company == "Telefonica", gen(ex)
	replace MNEs = 100 if ex== 1
	replace Company = "Total" if ex== 1
	replace Headquartercountrycode = "" if ex== 1
	replace sort = 1.5 if ex== 1
  foreach r in 15 21 25 30 {
  		sum ratiototal`r'
		replace td_ratio`r' = r(mean) if ex== 1
  
		sum TD21total`r'
		replace TD21_`r' = r(mean) if ex== 1
   }	
	sum taxpaid21total
	replace taxpaid21 = r(mean) if ex== 1
	
	// last data edit  
	drop taxpaid21total ratiototal* TD21total* ex
	ren Company bankmne
	ren Headquartercountrycode parent
		
	
	keep TD21_* taxpaid21 td_ratio* parent bankmne sort
	
	// retrieve parent country
	kountry parent, from(iso3c) to(iso2c)
	ren _ISO2C_ iso
	merge m:1 iso using "${data}/iso-country.dta"
	drop if _merge ==2
	drop _merge
	drop parent iso
	ren countryname parent
	
	order bankmne parent TD21* taxpaid21 td_ratio*
	
	save "${dta}/mne.dta", replace

	