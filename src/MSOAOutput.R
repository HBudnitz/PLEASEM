library(dplyr)
library(data.table)
#upload lookup files to include LSOA and MSOA 2021 codes then LSOA 2011 codes for fleet data
Lookup21 <- read.csv("../data/raw_data/LookupLtoMSOA21.csv") #43501obs
Lookup2011 <- read.csv("../data/raw_data/LSOA_(2011)_to_LSOA_(2021)_to_Local_Authority_District_(2022)_Lookup_for_England_and_Wales.csv")
Lookup2011 <- Lookup2011[,c(1,3,5:6)]
names (Lookup2011)[1] <- "LSOA11CD"
Lookup <- left_join(Lookup21, Lookup2011) #43621obs
#Total Hholds by LSOA
#data from census: https://www.nomisweb.co.uk/query/select/getdatasetbytheme.asp
#select census 2021, Table 041 number of households, geography: all 2021 super output areas - lower layer 
HHolds <- read.csv("../data/raw_data/HHoldNumbers.csv")
HHolds$X2021.super.output.area...lower.layer <- 
        substr(HHolds$X2021.super.output.area...lower.layer,1,9)
names(HHolds) <- c("LSOA21CD","TotHhold")
HHolds$TotHhold <- as.numeric(HHolds$TotHhold)
LSOAoutput <- left_join(Lookup, HHolds)
#Add Car registration rates by LSOA
#Table veh0125: https://www.gov.uk/government/statistical-data-sets/vehicle-licensing-statistics-data-files
#Columns 1, 3, 4, 5, and 6 extracted to reduce size to save to Github
AllVehReg <- fread("../data/raw_data/df_VEH0125_col13456.csv")
AllVehReg$LicenceStatus <- as.factor(AllVehReg$LicenceStatus)
#remove 'SORN' as are registered as such if broken, untaxed, etc - not allowed on road
AllVehReg <- AllVehReg[which(AllVehReg$LicenceStatus == "Licensed"),]
names(AllVehReg)[1] <- "LSOA11CD" 
AllVehReg$BodyType <- as.factor(AllVehReg$BodyType)
AllVehReg$Keepership <- as.factor(AllVehReg$Keepership)
#BodyType include Cars only, not Motorcycles or Other body types
#Keepership include private and company, as company cars a key form of car ownership, esp for EVs
AllVehReg <- AllVehReg[which(AllVehReg$BodyType == "Cars"),] 
AllVehReg <- AllVehReg[which(AllVehReg$Keepership == "Total"),] #42620 obs - extra LSOAs because include Scotland / NI?
AllVehReg$`2024 Q2` <- as.numeric(AllVehReg$`2024 Q2`)
#Keep only latest quarter and LSOA11 code
AllVehReg <- AllVehReg[,c(1,5)]
names(AllVehReg)[2] <- "VehsReg2024Q2"
LSOAoutput <- left_join(LSOAoutput, AllVehReg)
LSOAoutput <- LSOAoutput[!is.na(LSOAoutput$VehsReg2024Q2),] #remove Scotland - 34753 obs
#round 53 LSOA outliers to account for where there are car rental businesses, fleets registered, etc 
#double max hholds per LSOA is 3954, so maximum capped at 4k registered cars per LSOA
LSOAoutput$VehsReg2024Q2 <- if_else(LSOAoutput$VehsReg2024Q2 > 4000, 
                                        4000, LSOAoutput$VehsReg2024Q2)
#Rates of cars registered by total households 
LSOAoutput$CarOwnRates <- LSOAoutput$VehsReg2024Q2 / LSOAoutput$TotHhold
#EV registrations by LSOA - all plug-in vehicles, inc hybrids and Range extended
#Table veh0145: https://www.gov.uk/government/statistical-data-sets/vehicle-licensing-statistics-data-files
#Columns 1, 3, 4, and 5 extracted to reduce size to save to Github
EVReg <- fread("../data/raw_data/df_VEH0145_col1345.csv")
names(EVReg)[1] <- "LSOA11CD" 
EVReg$Fuel <- as.factor(EVReg$Fuel)
EVReg$Keepership <- as.factor(EVReg$Keepership)
#include only fully electric but company or private ownership
EVReg <- EVReg[which(EVReg$Fuel == "Battery electric"),] 
EVReg <- EVReg[which(EVReg$Keepership == "Total"),] 
EVReg <- EVReg[,c(1,4)]
EVReg$`2024 Q2` <- as.numeric(EVReg$`2024 Q2`)
names(EVReg)[2] <- "EV2024Q2"
EVReg$EV2024Q2 <- if_else(is.na(EVReg$EV2024Q2),0,EVReg$EV2024Q2)
LSOAoutput <- left_join(LSOAoutput,EVReg)
#round 17 outliers as did with total vehs - double max hholds per LSOA is 3954, so rounded to 4k
LSOAoutput$EV2024Q2 <- if_else(LSOAoutput$EV2024Q2 > 4000, 
                                   4000, LSOAoutput$EV2024Q2)
LSOAoutput$EVRate <- (LSOAoutput$EV2024Q2/LSOAoutput$VehsReg2024Q2)
#LSOA reduction in car ownership rates
LSOAoutput$CCCarOwn <- (LSOAoutput$VehsReg2024Q2 - 9)/LSOAoutput$TotHhold
LSOAoutput$CCredCarOwn <- (LSOAoutput$CCCarOwn - LSOAoutput$CarOwnRates)
#LSOA changes in EV uptake
LSOAoutput$EVincCC <- (LSOAoutput$EV2024Q2 + 9)
LSOAoutput$EVRateincCC <- (LSOAoutput$EVincCC/(LSOAoutput$VehsReg2024Q2-8))
LSOAoutput$ChangeEVuptake <- (LSOAoutput$EVRateincCC - LSOAoutput$EVRate)*100
#aggregate populations, total households, car ownership and EV uptake by MSOA into new df
TotHholdMSOA <- summarise(group_by(LSOAoutput, MSOA21CD), 
                          sum(TotHhold, na.rm = T))
names(TotHholdMSOA)[2] <- "TotHhold"
VehsRegMSOA <- summarise(group_by(LSOAoutput, MSOA21CD), 
                           sum(VehsReg2024Q2, na.rm = T))
names(VehsRegMSOA)[2]<- "VehsReg"
MSOAoutput <- left_join(TotHholdMSOA, VehsRegMSOA)
MSOAoutput$CarOwnRates <- MSOAoutput$VehsReg / MSOAoutput$TotHhold
EVRegMSOA <- summarise(group_by(LSOAoutput, MSOA21CD), 
                       sum(EV2024Q2, na.rm = T))
names(EVRegMSOA)[2]<-"EVReg"
MSOAoutput <- left_join(MSOAoutput, EVRegMSOA)
MSOAoutput$EVRate <- (MSOAoutput$EVReg/MSOAoutput$VehsReg)
#MSOA reduction in car ownership unweighted by LSOA household numbers
MSOAoutput$CarRedincCC <- (MSOAoutput$VehsReg - 9)
MSOAoutput$CCCarOwn <- MSOAoutput$CarRedincCC/MSOAoutput$TotHhold
#MSOAoutput$CCredCarOwn <- (MSOAoutput$CCCarOwn - MSOAoutput$CarOwnRates)
#MSOA reduction in car ownership weighted by LSOA household numbers
W_CCredCarOwnMSOA <- summarise(group_by(LSOAoutput, MSOA21CD),
                              weighted.mean(CCredCarOwn, TotHhold))
names(W_CCredCarOwnMSOA)[2]<- "CCredCarOwn"
MSOAoutput <- left_join(MSOAoutput, W_CCredCarOwnMSOA)
#MSOA changes in EV uptake unweighted by LSOA household numbers
MSOAoutput$EVincCC <- (MSOAoutput$EVReg + 9)
MSOAoutput$EVRateincCC <- (MSOAoutput$EVincCC/(MSOAoutput$VehsReg - 8))
#MSOAoutput$ChangeEVuptake <- (MSOAoutput$EVRateincCC - MSOAoutput$EVRate)*100
#MSOA changes in EV uptake weighted by LSOA household numbers
W_CCEVuptakeMSOA <- summarise(group_by(LSOAoutput, MSOA21CD),
                             weighted.mean(ChangeEVuptake, TotHhold))
names(W_CCEVuptakeMSOA)[2]<- "ChangeEVuptake"
MSOAoutput <- left_join(MSOAoutput, W_CCEVuptakeMSOA)
write.csv(MSOAoutput, "../data/processed_data/df_msoa.csv")
#aggregate total households, car ownership and EV uptake by LAD into new df
TotHholdLAD <- summarise(group_by(LSOAoutput, LAD22CD), 
                          sum(TotHhold, na.rm = T))
names(TotHholdLAD) [2] <- "TotHhold"
VehsRegLAD <- summarise(group_by(LSOAoutput, LAD22CD), 
                         sum(VehsReg2024Q2, na.rm = T))
names(VehsRegLAD)[2]<- "VehsReg"
LADoutput <- left_join(TotHholdLAD, VehsRegLAD)
LADoutput$CarOwnRates <- LADoutput$VehsReg / LADoutput$TotHhold
EVRegLAD <- summarise(group_by(LSOAoutput, LAD22CD), 
                       sum(EV2024Q2, na.rm = T))
names(EVRegLAD)[2]<-"EVReg"
LADoutput <- left_join(LADoutput, EVRegLAD)
LADoutput$EVRate <- (LADoutput$EVReg/LADoutput$VehsReg)
#LAD reduction in car ownership unweighted by LSOA household numbers
LADoutput$CarRedincCC <- (LADoutput$VehsReg - 9)
LADoutput$CCCarOwn <- LADoutput$CarRedincCC/LADoutput$TotHhold
#LADoutput$CCredCarOwn <- (LADoutput$CCCarOwn - LADoutput$CarOwnRates)
#LAD reduction in car ownership weighted by LSOA household numbers
W_CCredCarOwnLAD <- summarise(group_by(LSOAoutput, LAD22CD),
                        weighted.mean(CCredCarOwn, TotHhold))
names(W_CCredCarOwnLAD)[2]<- "CCredCarOwn"
LADoutput <- left_join(LADoutput, W_CCredCarOwnLAD)
#LAD changes in EV uptake unweighted by LSOA household numbers
LADoutput$EVincCC <- (LADoutput$EVReg + 9)
LADoutput$EVRateincCC <- (LADoutput$EVincCC/(LADoutput$VehsReg-8))
#LADoutput$ChangeEVuptake <- (LADoutput$EVRateincCC - LADoutput$EVRate)*100
#LAD changes in EV uptake unweighted by LSOA household numbers
W_CCEVuptakeLAD <- summarise(group_by(LSOAoutput, LAD22CD),
                              weighted.mean(ChangeEVuptake, TotHhold))
names(W_CCEVuptakeLAD)[2]<- "ChangeEVuptake"
LADoutput <- left_join(LADoutput, W_CCEVuptakeLAD)
write.csv(LADoutput, "../data/processed_data/df_lad.csv")
