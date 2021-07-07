*******************************************************************************
//9_banks

/*This do-file calculates the tax deficit for the EU systemic banks, appends the 
tax deficit of 16 non-bank MNEs and outputs the results.
Data is based on 2019 reports and uprated to 2021 current EUR. */

set more off
clear

********************************************************************************
// Load nominal GDP growth rate in EUR 2019-2021

use "${dta}/gdpgrowth.dta", clear

sum upreur2119 if CountryGroupName == "European Union"
scalar EU_upr21 = r(mean)
di r(mean)

********************************************************************************
// load bank data
import excel using "${data}\data_bank2019_juneupgrade.xlsx", firstrow clear

keep code bank homecode earningsbeforecorporatetax exchtoeur corporatetax ETRavg6yrs_w

//data edit
encode(code), gen(countrycode)
encode(bank), gen(banquecode)
encode(homecode), gen(parentcode)
//sample restriction: positive profits
drop if earningsbeforecorporatetax<0

//Currency conversion: currency in millions of euros:
gen EBT=earningsbeforecorporatetax*exchtoeur
gen corptax=corporatetax*exchtoeur

**ETR calculation:

gen ETR=corptax/EBT
//replace ETR with 6 year average if ETR ==.
replace ETR = ETRavg6yrs_w if ETR==.
replace ETR = ETRavg6yrs_w if ETR<0
// winsorize outliers
winsor2(ETR),cut(5 95)

***Calculate the tax deficit: 

	foreach r in 15 21 25 30 {
	    **Tax difference : (min tax- ETR) 
		gen T`r'_ETR= `r'/100 - ETR_w
		**drop negative tax differences
		replace T`r'_ETR = 0 if T`r'_ETR < 0
		**Tax deficit : multiply difference in tax rate by EBT
		gen TD_`r'_ETR= T`r'_ETR* EBT
	}	
	 
//collapse: sum tax deficit & tax paid by bank
	collapse (sum) TD_15_ETR (sum) TD_21_ETR (sum) TD_25_ETR (sum) TD_30_ETR ///
				(sum) corptax (firstnm) bank (firstnm) homecode , by(banquecode) 
	 
  ** Uprate from 2019 to 2021 (using nominal GDP growth)
	di `=EU_upr21'
	foreach r in 15 21 25 30 {
		gen TD21_`r'= TD_`r'_ETR * `=EU_upr21'
	}
	gen taxpaid21 = corptax * `=EU_upr21'

  
  **TOTALS : corporate taxes overall
  egen taxpaid19total=total(corptax)
  egen taxpaid21total=total(taxpaid21)
  **TOTALS: TD totals
  foreach r in 15 21 25 30 {
		egen TD19total`r' = total(TD_`r'_ETR) 
		egen TD21total`r' = total(TD21_`r') 
  }


	**share tax deficit in taxes paid (2019 numbers)
	  foreach r in 15 21 25 30 {
			gen td_ratio`r'= TD_`r'_ETR/corptax
			replace td_ratio`r'= . if corptax <=0
			** overal TD as share of corptax
			gen ratiototal`r' = TD19total`r'/ taxpaid19total
	   }
	   
	//gen indicator for sorting
	gen sort =2
	
	// insert Totals line
	expand 2 if bank == "Belfius", gen(ex)
	replace banquecode = 100 if ex== 1
	replace bank = "Total" if ex== 1
	replace homecode = "" if ex== 1
	replace sort = 2.5 if ex== 1
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
	ren bank bankmne
	ren homecode parent

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
	
// Append MNE data	
	append using "${dta}/mne.dta"
	sort sort bankmne
	


	
/* ADD OUTPUT TABLE 4*/

preserve
	keep bankmne parent TD21_25 taxpaid21 td_ratio25 sort
	sort sort bankmne, stable
	drop sort
	export excel using "${dta}/Results_BankMNE.xlsx", sheetreplace firstrow(var) sheet("Table4")
	putexcel set "${dta}/Results_BankMNE.xlsx", modify sheet("Table4")	
	putexcel (C2:D57), nformat(#0.0)
	putexcel (E2:E57), nformat(percent)
	putexcel (A1:E1), bold
	putexcel (A1:B57), bold
	putexcel (A1:A57), border("left", "medium", "black")
	putexcel (E1:E57), border("right", "medium", "black")
	putexcel (B1:B57), border("right", "thin", "black")
	putexcel (A1:A57), border("right", "thin", "black")
	putexcel (A17:E17), border("bottom", "medium", "black")
	putexcel (A18:E18), border("bottom", "medium", "black")
	putexcel (A56:E56), border("bottom", "medium", "black")
	putexcel (A57:E57), border("bottom", "medium", "black")
	putexcel (A1:E1), border("top", "medium", "black")
	putexcel (A1:E1), border("bottom", "medium", "black")
restore


/* ADD OUTPUT TABLES D.2*/

preserve
	keep bankmne parent TD21_** td_ratio* sort
	
	// insert line for % in tax paid, banks
	expand 2 if bank == "Belfius", gen(ex)
	replace bankmne = "Share in tax paid" if ex== 1
	replace parent = "" if ex==1
	replace sort = 2.7 if ex== 1
  foreach r in 15 21 25 30 {
  		sum td_ratio`r' if sort== 2.5
		replace TD21_`r' = r(mean) if ex== 1
   }	
	drop ex
	
	// insert line for % in tax paid, non-banks
	expand 2 if bank == "Belfius", gen(ex)
	replace bankmne = "Share in tax paid" if ex== 1
	replace parent = "" if ex==1
	replace sort = 1.7 if ex== 1
  foreach r in 15 21 25 30 {
  		sum td_ratio`r' if sort== 1.5
		replace TD21_`r' = r(mean) if ex== 1
   }
	drop td_ratio* ex
	
	sort sort bankmne, stable
	drop sort
	
	export excel using "${dta}/Results_BankMNE.xlsx", sheetreplace firstrow(var) sheet("TableD2")
	putexcel set "${dta}/Results_BankMNE.xlsx", modify sheet("TableD2")	
	putexcel (C2:F58), nformat(#0.0)
	putexcel (C19:F19), nformat(percent)
	putexcel (C59:F59), nformat(percent)
	putexcel (A1:F1), bold
	putexcel (A1:B59), bold
	putexcel (A1:A59), border("left", "medium", "black")
	putexcel (F1:F59), border("right", "medium", "black")
	putexcel (B1:B59), border("right", "thin", "black")
	putexcel (A1:A59), border("right", "thin", "black")
	putexcel (A17:F17), border("bottom", "medium", "black")
	putexcel (A19:F19), border("bottom", "medium", "black")
	putexcel (A57:F57), border("bottom", "medium", "black")
	putexcel (A59:F59), border("bottom", "medium", "black")
	putexcel (A1:F1), border("top", "medium", "black")
	putexcel (A1:F1), border("bottom", "medium", "black")
restore

/* ADD OUTPUT TABLES D.3*/

preserve
	keep bankmne parent td_ratio* sort
	sort sort bankmne, stable
	drop sort
	export excel using "${dta}/Results_BankMNE.xlsx", sheetreplace firstrow(var) sheet("TableD3")
	putexcel set "${dta}/Results_BankMNE.xlsx", modify sheet("TableD3")	
	putexcel (C2:F57), nformat(percent)
	putexcel (A1:F1), bold
	putexcel (A1:B57), bold
	putexcel (A1:A57), border("left", "medium", "black")
	putexcel (F1:F57), border("right", "medium", "black")
	putexcel (B1:B57), border("right", "thin", "black")
	putexcel (A1:A57), border("right", "thin", "black")
	putexcel (A17:F17), border("bottom", "medium", "black")
	putexcel (A18:F18), border("bottom", "medium", "black")
	putexcel (A56:F56), border("bottom", "medium", "black")
	putexcel (A57:F57), border("bottom", "medium", "black")
	putexcel (A1:F1), border("top", "medium", "black")
	putexcel (A1:F1), border("bottom", "medium", "black")
restore


