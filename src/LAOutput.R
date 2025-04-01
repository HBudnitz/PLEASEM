library(dplyr)
#traffic by LTA
Traffic <- read.csv("../local_authority_traffic.csv")
Traffic <- Traffic[which(Traffic$year == 2023),c(2:3,5:8)]
names(Traffic)[1:2]<-c("Local Authority","Local Authority Code")
VehFleet <- read.csv("../VehReg.csv")
VehFleet <- VehFleet[,2:7]
VehFleet$BodyType <- as.factor(VehFleet$BodyType)
VehFleet$Fuel <- as.factor(VehFleet$Fuel)
VehFleet$Keepership <- as.factor(VehFleet$Keepership)
VehFleet$X2024.Q2 <- (as.numeric(VehFleet$X2024.Q2))*1000
VehFleet <- VehFleet[which(VehFleet$BodyType == "Cars"),]
VehFleet <- VehFleet[which(VehFleet$Keepership == "Total"),]
VehFleet <- VehFleet[which(VehFleet$Local.Authority.Code != "[z]"),]
Diesel <- VehFleet[which(VehFleet$Fuel == "Diesel"),c(4,6)]
names(Diesel)[2] <- "Diesel2024Q2"
Hybrid <- VehFleet[which(VehFleet$Fuel == "Hybrid electric (petrol)"),c(4,6)]
names(Hybrid)[2] <- "Hybrid2024Q2"
Petrol <- VehFleet[which(VehFleet$Fuel == "Petrol"),c(4,6)]
names(Petrol)[2] <- "Petrol2024Q2"
VehFleet <- left_join(Petrol, Diesel)
VehFleet <- left_join(VehFleet, Hybrid)
Electric <- read.csv("../PiEVReg.csv")
Electric <- Electric[,2:7]
Electric$BodyType <- as.factor(Electric$BodyType)
Electric$Fuel <- as.factor(Electric$Fuel)
Electric$Keepership <- as.factor(Electric$Keepership)
Electric$X2024.Q2 <- sub(",", "",Electric$X2024.Q2)
Electric$X2024.Q2 <- as.numeric(Electric$X2024.Q2)
Electric <- Electric[which(Electric$BodyType == "Cars"),]
Electric <- Electric[which(Electric$Keepership == "Total"),]
Electric <- Electric[which(Electric$Local.Authority.Code != "[z]"),]
BEV <- Electric[which(Electric$Fuel == "Battery electric"),c(4,6)]
names(BEV)[2] <- "BEV2024Q2"
BEV$BEV2024Q2 <- if_else(is.na(BEV$BEV2024Q2), 0,BEV$BEV2024Q2)
VehFleet <- left_join(VehFleet, BEV)
PHEV <- Electric[which(Electric$Fuel == "Plug-in hybrid electric (petrol)"),c(4,6)]
names(PHEV)[2] <- "PHEVpet"
PHEV$PHEVpet <- if_else(is.na(PHEV$PHEVpet), 0,PHEV$PHEVpet)
PHEV2 <- Electric[which(Electric$Fuel == "Plug-in hybrid electric (diesel)"),c(4,6)]
names(PHEV2)[2] <- "PHEVd"
PHEV2$PHEVd <- if_else(is.na(PHEV2$PHEVd), 0,PHEV2$PHEVd)
PHEV3 <- Electric[which(Electric$Fuel == "Range extended electric"),c(4,6)]
PHEV3$X2024.Q2 <- if_else(is.na(PHEV3$X2024.Q2), 0,PHEV3$X2024.Q2)
PHEV <- left_join(PHEV, PHEV2)
PHEV <- left_join(PHEV, PHEV3)
PHEV$PHEV2024Q2 <- rowSums(PHEV[2:4])
PHEV <- PHEV[,c(1,5)]
VehFleet <- left_join(VehFleet, PHEV)
names(VehFleet)[1]<-"Local Authority Code"
VehFleet$TotalCars <- rowSums(VehFleet[2:6], na.rm = T)
VehFleet$Petrol <- VehFleet$Petrol2024Q2/VehFleet$TotalCars
VehFleet$Diesel <- VehFleet$Diesel2024Q2/VehFleet$TotalCars
VehFleet$Hybrid <- VehFleet$Hybrid2024Q2/VehFleet$TotalCars
VehFleet$BEV <- VehFleet$BEV2024Q2/VehFleet$TotalCars
VehFleet$PHEV <- VehFleet$PHEV2024Q2/VehFleet$TotalCars
TrafficFleet <- left_join(VehFleet, Traffic) #421 upper and lower tier authorities
#4 LAs not included or have different codes in VehFleet files that are in Mileage files
#not inc: Somerset and North Yorkshire (lower tier included), Cumberland and Westmorland and Furness
#218 NAs
TrafficFleet$PetrolMile <- TrafficFleet$cars_and_taxis*TrafficFleet$Petrol
TrafficFleet$DieselMile <- TrafficFleet$cars_and_taxis*TrafficFleet$Diesel
TrafficFleet$HybridMile <- TrafficFleet$cars_and_taxis*TrafficFleet$Hybrid
TrafficFleet$BEVMile <- TrafficFleet$cars_and_taxis*TrafficFleet$BEV
TrafficFleet$PHEVMile <- TrafficFleet$cars_and_taxis*TrafficFleet$PHEV
TrafficFleet$PetrolCO2e <- TrafficFleet$PetrolMile*0.26473
TrafficFleet$DieselCO2e <- TrafficFleet$DieselMile*0.27334
TrafficFleet$HybridCO2e <- TrafficFleet$HybridMile*0.20288
TrafficFleet$BEVCO2e <- TrafficFleet$BEVMile*0.07015+(TrafficFleet$BEVMile*0.00620)
TrafficFleet$PHEVCO2e <- TrafficFleet$PHEVMile*(0.14989+0.02208+0.00195)
#add baseline CO2e in tons and baseline CO2e and mileage per vehicle in LA fleet
TrafficFleet$BaseCO2e <- rowSums(TrafficFleet[,23:27], na.rm = TRUE)
TrafficFleet$pCarBaseCO2e <- TrafficFleet$BaseCO2e/TrafficFleet$TotalCars
TrafficFleet$pCarAnnMile <- TrafficFleet$cars_and_taxis/TrafficFleet$TotalCars
#Use mileage in fleet to create conversion factors for CO2 emissions reductions per CC car
TrafficFleet$pBEVAnnCO2e <- TrafficFleet$pCarAnnMile*0.07015+(TrafficFleet$pCarAnnMile*0.00620)
TrafficFleet$pHyVAnnCO2e <- TrafficFleet$pCarAnnMile*0.20288
TrafficFleet$reduceCO2pBEVcc <- TrafficFleet$pCarBaseCO2e - TrafficFleet$pBEVAnnCO2e
TrafficFleet$reduceCO2pHyVc <- TrafficFleet$pCarBaseCO2e - TrafficFleet$pHyVAnnCO2e
write.csv(TrafficFleet, "LAoutputFleet.csv")

LATrafEmit <- left_join(LAemit,Traffic)
Co2Conv <- read.csv("../ghg-conversion-factors-2024-full_set__for_advanced_users__v1_1.csv")

#test if same mean annual mileage per vehicle
CarClubMileage <- read.csv("CClubBUA_OA.csv")
names (CarClubMileage) [15]<- "pCarAnnMile"
t.test(CarClubMileage$pCarAnnMile, LAOutput$pCarAnnMile)
#Welch Two Sample t-test

#data:  CarClubMileage$pCarAnnMile and LAOutput$pCarAnnMile
#t = 5.2262, df = 624.88, p-value = 2.362e-07
#alternative hypothesis: true difference in means is not equal to 0
#95 percent confidence interval:
#        1135.368 2502.218
#sample estimates:
#        mean of x mean of y 
#9280.615  7461.822