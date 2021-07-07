********************************************************************************
/* Barake, Neef, Chouc, & Zucman(2021): Collecting the tax deficit of multinational
companies: Simulations for the European Union. 

Version: 07/2021*/
********************************************************************************

// Paths

// Insert you path where you saved the do-files
global do ""

// Input data path
global data ""

// Insert the path where the result tables are outputted
global dta ""



// Batch


*1) prepare auxiliary information and datasets

* exchange rates and nominal GDp growth
do "${do}/1a_eurgdpgrowth.do"
*statutory corporate tax rates by KPMG
do "${do}/1b_statrates.do"
*Tax haven list used by TWZ(2018)
do "${do}/1c_thlist.do"
 
*2) prepare TWZ data

*foreign booked profits & TD
do "${do}/2a_twz_foreign.do"
* local profits and tax deficit
do "${do}/2b_twz_localfirms.do"

*3) prepare OECD data and integrate OECD CbCR & TWZ(2019)

* edit OECD data & append TWZ(2019)
do "${do}/3a_oecd_cbcr.do"
* impute missing tax deficits for non-havens and integrate OECD CBCR with TWZ(2019)
do "${do}/3b_imputation.do"

*4) preparation of country-specific health and TWZ corporate income tax revenue

*prepare health and CIT aggregates
do "${do}/4a_CITrevenue.do"
*compute share based on 2016 data
do "${do}/4b_healthCITshares.do"

*5) uprate to 2021 EUR, merge with 2016-based CIT and health shares & output
do "${do}/5_2021uprate.do"

*6) first-mover/unilateral scenario
do "${do}/6_unilateral.do"

*7) EU-cooperation scenario
do "${do}/7_EUcooperation.do"

********************************************************************************
// FIRM-LEVEL ANALYSIS

*8) Reporting multinationals
do "${do}/8_MNE.do"


*8) Reporting Banks
do "${do}/9_banks.do"

********************************************************************************
// clean up: erase all intermediary files

di "${dta}"
local datafiles: dir "${dta}" files "*.dta"
*di `datafiles'
foreach datafile of local datafiles {
        rm "${dta}/`datafile'"
}

