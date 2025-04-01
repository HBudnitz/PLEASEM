rootfolder <- strsplit(rstudioapi::getSourceEditorContext()$path, 'code')[[1]][1]

library(dplyr)
library(data.table)
#upload lookup files to include LSOA and MSOA codes inc LSOA 2011 for fleet data
LookupPC <- fread("LookupLtoMSOA21.csv")
LookupPC <- LookupPC[,c(8:9)]
names(LookupPC)[1] <- "LSOA21CD"
names(LookupPC)[2] <- "MSOA21CD"
LookupPC <- distinct(LookupPC) #43501obs
Lookup2011 <- read.csv("../LSOA_(2011)_to_LSOA_(2021)_to_Local_Authority_District_(2022)_Lookup_for_England_and_Wales.csv")
Lookup2011 <- Lookup2011[,c(1,3,5:6)]
names (Lookup2011)[1] <- "LSOA11CD"
Lookup <- left_join(LookupPC, Lookup2011) #43621obs
#Total Hholds and type by LSOA
HHoldVars <- read.csv(file.path(rootfolder, 'data',"HHoldAccommodationType.csv")
HHoldVars$X2021.super.output.area...lower.layer <- 
        substr(HHoldVars$X2021.super.output.area...lower.layer,1,9)
names(HHoldVars)[1] <- "LSOA21CD"
HHoldVars <- HHoldVars[,1:2]
HHoldVars$Total.hholds <- as.numeric(HHoldVars$Total.hholds)
MSOAoutput <- left_join(Lookup, HHoldVars)
#Add Car registration rates by LSOA
AllVehReg <- fread("../df_VEH0125_col13456.csv")
AllVehReg <- AllVehReg[,c(1,3:6)]
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
AllVehReg <- AllVehReg[,c(1,5)]
names(AllVehReg)[2] <- "VehsReg2024Q2"
MSOAoutput <- left_join(MSOAoutput, AllVehReg)
MSOAoutput <- MSOAoutput[!is.na(MSOAoutput$VehsReg2024Q2),]
#round 53 LSOA outliers to account for where there are car rental businesses, fleets, etc 
#double max hholds per LSOA is 3954, so rounded to 4k
MSOAoutput$VehsReg2024Q2 <- if_else(MSOAoutput$VehsReg2024Q2 > 4000, 4000, MSOAoutput$VehsReg2024Q2)
#Rates of cars registered by total households 
MSOAoutput$CarOwnRates <- MSOAoutput$VehsReg2024Q2 / MSOAoutput$Total.hholds
#EV registrations by LSOA - all plug-in vehicles, inc hybrids and Range extended
EVReg <- fread("../df_VEH0145_col1345.csv")
EVReg <- EVReg[,c(1,3:5)]
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
MSOAoutput <- left_join(MSOAoutput,EVReg)
#round 17 outliers as did with total vehs - double max hholds per LSOA is 3954, so rounded to 4k
MSOAoutput$EV2024Q2 <- if_else(MSOAoutput$EV2024Q2 > 4000, 4000, MSOAoutput$EV2024Q2)
MSOAoutput$EVRate <- (MSOAoutput$EV2024Q2/MSOAoutput$VehsReg2024Q2)
MSOAoutput$ICErate <- MSOAoutput$CarOwnRates - MSOAoutput$EVRate
#LSOA reduction in car ownership rates
MSOAoutput$CCCarOwn <- (MSOAoutput$VehsReg2024Q2 - 9)/MSOAoutput$Total.hholds
MSOAoutput$CCredCarOwn <- (MSOAoutput$CCCarOwn - MSOAoutput$CarOwnRates)
#LSOA changes in EV uptake
MSOAoutput$EVincCC <- (MSOAoutput$EV2024Q2 + 9)
MSOAoutput$EVRateincCC <- (MSOAoutput$EVincCC/(MSOAoutput$VehsReg2024Q2-8))
MSOAoutput$ChangeEVuptake <- (MSOAoutput$EVRateincCC - MSOAoutput$EVRate)*100
#aggregate populations, total households, car ownership and EV uptake by MSOA
TotHholdMSOA <- summarise(group_by(MSOAoutput, MSOA21CD), 
                          sum(Total.hholds, na.rm = T))
names(TotHholdMSOA)[2] <- "TotHholdMSOA"
MSOAoutput <- left_join(MSOAoutput, TotHholdMSOA)
VehsRegMSOA <- summarise(group_by(MSOAoutput, MSOA21CD), 
                           sum(VehsReg2024Q2, na.rm = T))
names(VehsRegMSOA)[2]<- "VehsRegMSOA"
MSOAoutput <- left_join(MSOAoutput, VehsRegMSOA)
MSOAoutput$MSOACarOwnRates <- MSOAoutput$VehsRegMSOA / MSOAoutput$TotHholdMSOA
EVRegMSOA <- summarise(group_by(MSOAoutput, MSOA21CD), 
                       sum(EV2024Q2, na.rm = T))
names(EVRegMSOA)[2]<-"EVRegMSOA"
MSOAoutput <- left_join(MSOAoutput, EVRegMSOA)
MSOAoutput$EVRateMSOA <- (MSOAoutput$EVRegMSOA/MSOAoutput$VehsRegMSOA)
#MSOA reduction in car ownership
MSOAoutput$CarRedincCC <- (MSOAoutput$VehsRegMSOA - 9)
MSOAoutput$CCCarOwnMSOA <- MSOAoutput$CarRedincCC/MSOAoutput$TotHholdMSOA
MSOAoutput$CCredCarOwnMSOA <- (MSOAoutput$CCCarOwnMSOA - MSOAoutput$MSOACarOwnRates)
#MSOA changes in EV uptake
MSOAoutput$MSOAEVincCC <- (MSOAoutput$EVRegMSOA + 9)
MSOAoutput$MSOAEVRateincCC <- (MSOAoutput$MSOAEVincCC/(MSOAoutput$VehsRegMSOA-8))
MSOAoutput$MSOAChangeEVuptake <- (MSOAoutput$MSOAEVRateincCC - MSOAoutput$EVRateMSOA)*100
#aggregate total households, car ownership and EV uptake by LAD
TotHholdLAD <- summarise(group_by(MSOAoutput, LAD22CD), 
                          sum(Total.hholds, na.rm = T))
names(TotHholdLAD) [2] <- "TotHholdLAD"
MSOAoutput <- left_join(MSOAoutput, TotHholdLAD)
VehsRegLAD <- summarise(group_by(MSOAoutput, LAD22CD), 
                         sum(VehsReg2024Q2, na.rm = T))
names(VehsRegLAD)[2]<- "VehsRegLAD"
MSOAoutput <- left_join(MSOAoutput, VehsRegLAD)
MSOAoutput$LADCarOwnRates <- MSOAoutput$VehsRegLAD / MSOAoutput$TotHholdLAD
EVRegLAD <- summarise(group_by(MSOAoutput, LAD22CD), 
                       sum(EV2024Q2, na.rm = T))
names(EVRegLAD)[2]<-"EVRegLAD"
MSOAoutput <- left_join(MSOAoutput, EVRegLAD)
MSOAoutput$EVRateLAD <- (MSOAoutput$EVRegLAD/MSOAoutput$VehsRegLAD)
#LAD reduction in car ownership
MSOAoutput$LADCarRedincCC <- (MSOAoutput$VehsRegLAD - 9)
MSOAoutput$CCCarOwnLAD <- MSOAoutput$LADCarRedincCC/MSOAoutput$TotHholdLAD
MSOAoutput$CCredCarOwnLAD <- (MSOAoutput$CCCarOwnLAD - MSOAoutput$LADCarOwnRates)
#MSOA changes in EV uptake
MSOAoutput$LADEVincCC <- (MSOAoutput$EVRegLAD + 9)
MSOAoutput$LADEVRateincCC <- (MSOAoutput$LADEVincCC/(MSOAoutput$VehsRegLAD-8))
MSOAoutput$LADChangeEVuptake <- (MSOAoutput$LADEVRateincCC - MSOAoutput$EVRateLAD)*100
write.csv(MSOAoutput, "MSOAOutput.csv")
LADoutput <- MSOAoutput[,c(5:6,29:39)]
LADoutput <- distinct(LADoutput)
write.csv(LADoutput,"LADoutput.csv")
