library(dplyr)
#data on mileage on upper tier authority on all roads within that authority
#https://roadtraffic.dft.gov.uk/downloads (Local authority traffic)
Traffic <- read.csv("../dashboard/data/raw_data/local_authority_traffic.csv")
Traffic <- Traffic[which(Traffic$year == 2023),c(2:3,5:8)]
names(Traffic)[1:2]<-c("Local Authority","Local Authority Code")
#data on vehicle fleet makeup by upper and lower tier local authority
#Table veh0105: https://www.gov.uk/government/statistical-data-sets/vehicle-licensing-statistics-data-tables
#extract data for all (private and company) cars (body type) by fuel type
VehFleet <- read.csv("../dashboard/data/raw_data/VehReg.csv")
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
#Data on full EVs and plug in hybrids
#Table veh0142: https://www.gov.uk/government/statistical-data-sets/vehicle-licensing-statistics-data-tables
#extract data for all (private and company) cars (body type) by fuel type
Electric <- read.csv("../dashboard/data/raw_data/PiEVReg.csv")
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
#Cumbria split into Cumberland (Allderdale, Copeland, Carlisle) and
#Westmorland and Furness (South Lakeland, Eden, Barrow in Furness)
#create new row for each, sum districts fleet make-up
#code may no longer be needed if data updates have also updated authority codes
Cumberland <- VehFleet[which(VehFleet$`Local Authority Code` == 
                        "E07000026" | VehFleet$`Local Authority Code` == 
                        "E07000028" | VehFleet$`Local Authority Code` == 
                        "E07000029"),]
Cumberland2 <- c("E06000063", colSums(Cumberland[,2:6]))
VehFleet <- rbind(VehFleet, Cumberland2)
WestmorlandFurness <- VehFleet[which(VehFleet$`Local Authority Code` == 
                         "E07000027" | VehFleet$`Local Authority Code` == 
                         "E07000030" | VehFleet$`Local Authority Code` == 
                                       "E07000031"),]
WestmorlandFurness <- WestmorlandFurness %>% mutate_at(c(2:6), as.numeric)
WestmorlandFurness2 <- c("E06000064", colSums(WestmorlandFurness[,2:6]))
VehFleet <- rbind(VehFleet, WestmorlandFurness2)
VehFleet <- VehFleet %>% mutate_at(c(2:6), as.numeric)
#Calculate total cars and percentages to determine 'average car' per upper tier LA
VehFleet$TotalCars <- rowSums(VehFleet[2:6], na.rm = T)
VehFleet$Petrol <- VehFleet$Petrol2024Q2/VehFleet$TotalCars
VehFleet$Diesel <- VehFleet$Diesel2024Q2/VehFleet$TotalCars
VehFleet$Hybrid <- VehFleet$Hybrid2024Q2/VehFleet$TotalCars
VehFleet$BEV <- VehFleet$BEV2024Q2/VehFleet$TotalCars
VehFleet$PHEV <- VehFleet$PHEV2024Q2/VehFleet$TotalCars
TrafficFleet <- left_join(VehFleet, Traffic) #423 upper and lower tier authorities
#Clean dataframe and prepare for joining to geojson
#4 upper tier LAs have different codes in VehFleet files that are in Mileage files
#Somerset and North Yorkshire (changed lower tier code to upper tier code)
TrafficFleet$`Local Authority Code` <- if_else(TrafficFleet$`Local Authority Code` == "E10000027", 
                                               "E06000066", TrafficFleet$`Local Authority Code`)
TrafficFleet$`Local Authority Code` <- if_else(TrafficFleet$`Local Authority Code` == "E10000023", 
                                               "E06000065", TrafficFleet$`Local Authority Code`)
#Three authorities have different names on the geojson
TrafficFleet$`Local Authority` <- if_else(TrafficFleet$`Local Authority` == "Herefordshire", 
                                   "Herefordshire, County of", TrafficFleet$`Local Authority`)
TrafficFleet$`Local Authority` <- if_else(TrafficFleet$`Local Authority` == "Bristol", 
                                          "Bristol, City of", TrafficFleet$`Local Authority`)
TrafficFleet$`Local Authority` <- if_else(TrafficFleet$`Local Authority` == "Kingston upon Hull", 
                                          "Kingston upon Hull, City of", TrafficFleet$`Local Authority`)
#remove 215 NAs - 208 upper tier LAs
TrafficFleet <- TrafficFleet[!is.na(TrafficFleet$cars_and_taxis),]
#calculate mileage and emissions by car type per upper tier LA
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
#sum baseline CO2e and baseline CO2e and mileage for per vehicle in LA fleet
TrafficFleet$BaseCO2e <- rowSums(TrafficFleet[,23:27], na.rm = TRUE)
TrafficFleet$pCarBaseCO2e <- TrafficFleet$BaseCO2e/TrafficFleet$TotalCars
TrafficFleet$pCarAnnMile <- TrafficFleet$cars_and_taxis/TrafficFleet$TotalCars
#use mileage in fleet to create conversion factors for CO2 emissions reductions per CC car
TrafficFleet$pBEVAnnCO2e <- TrafficFleet$pCarAnnMile*0.07015+(TrafficFleet$pCarAnnMile*0.00620)
TrafficFleet$pHyVAnnCO2e <- TrafficFleet$pCarAnnMile*0.20288
TrafficFleet$reduceCO2pBEVcc <- TrafficFleet$pCarBaseCO2e - TrafficFleet$pBEVAnnCO2e
TrafficFleet$reduceCO2pHyVc <- TrafficFleet$pCarBaseCO2e - TrafficFleet$pHyVAnnCO2e
#output to use in mapping
write.csv(TrafficFleet, "../dashboard/data/processed_data/LAoutputFleet.csv")
