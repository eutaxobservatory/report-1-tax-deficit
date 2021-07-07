************************************************************************
// 1b_thlist

// This file loads the tax haven list used by TWZ(2019, 2020). See Appendix

import excel using "${data}\TH_list.xlsx" , ///
 clear first sheet("TWZ_TH")
 
 
// convert from iso3 to iso2 
 kountry code_TWZ, from(iso3c) to(iso2c)
 ren _ISO2C_ partner
// manual fixes 
 replace partner = "IM" if ListoftaxhavensTWZ == "Isle of man"
 replace partner = "JY" if ListoftaxhavensTWZ == "Jersey"
 replace partner = "SX" if ListoftaxhavensTWZ == "Sint Maarten"
 replace partner = "GG" if ListoftaxhavensTWZ == "Guernsey"
replace partner = "CW" if ListoftaxhavensTWZ == "Curacao"


drop Listof* code_TWZ
gen parent = partner


save "${dta}/th.dta", replace
