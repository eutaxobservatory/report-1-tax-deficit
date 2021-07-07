********************************************************************************
// Preparation ECB market exchange rates USD/EUR

insheet using "${data}/eurofxref-hist.csv", delimit(,) clear

keep date usd

keep if strpos(date, "2015") >0 | strpos(date, "2016")>0 | strpos(date, "2017")>0 ///
| strpos(date, "2018")>0 | strpos(date, "2019")>0 | strpos(date, "2020")>0 ///
| strpos(date, "2021")>0

gen year =.
forval y = 2015(1)2021 {
	replace year = `y' if strpos(date, "`y'") >0
}

gen type = "average" 
collapse usd , by(year) 

//build scalar to feed in later
forval y = 2015(1)2021 {
	sum usd if year == `y'
	scalar usd`y' = r(mean)
	di r(mean)
}

save "${dta}/usdeur_xrate.dta",  replace


************************************************************************
// Preparation World Economic Outlook data on nominal GDP growth

import excel using "${data}/WEOApr2021group.xlsx", clear firstrow

keep if CountryGroupName == "European Union" | CountryGroupName == "World"
keep if SubjectDescriptor == "Gross domestic product, current prices"
keep if Units == "U.S. dollars"

keep CountryGroupName Units y2015-y2021

destring y*, replace

// calc GDP in current EUR
foreach y in 15 16 17 18 19 20 21 {
	gen eurgdp20`y' = y20`y' / `=usd20`y'' // conversion to current EUR
}

// create growth factors for nom gdp growth in USD & EUR
foreach y in 16 17 18 19 20 21 {
	local x = `y' - 1
	gen uprusd`y'`x' = y20`y' / y20`x' 
	gen upreur`y'`x' = eurgdp20`y' /eurgdp20`x' 
}

// 2016 to 2021 nominal GDP growth
	gen uprusd2116 = y2021 /y2016
	gen upreur2116 = eurgdp2021 /eurgdp2016
// 2019 to 2021 nominal GDP growth	
	gen uprusd2119 = y2021 /y2019
	gen upreur2119 = eurgdp2021 /eurgdp2019	



keep CountryGroupName upreur* uprusd*

** output
save "${dta}/gdpgrowth.dta", replace

