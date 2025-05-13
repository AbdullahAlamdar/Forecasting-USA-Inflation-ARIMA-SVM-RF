#-------------code for converting the frequency of gdp growth from quarterly to monthly-------------#

library(zoo)
library(dplyr)

# Assuming you have a GDP dataset with quarterly data
gdp$Date <- as.Date(gdp$Date)

# Create a new column for quarters
gdp$Quarter <- as.yearqtr(gdp$Date)

# Convert quarterly to monthly by repeating the value for 3 months
gdp_monthly <- gdp %>%
  mutate(Year = format(Date, "%Y"), 
         Quarter = as.yearqtr(Date, format = "%Y-%m")) %>%
  tidyr::uncount(3, .id = "month_offset") %>%  # Repeat for 3 months
  mutate(Date = as.Date(as.yearmon(Quarter)) + months(month_offset - 1)) %>%
  select(Date, GDP = GDP)

# Save the processed data to a CSV file
write.csv(gdp_monthly, "GdpGrowthRate.csv", row.names = FALSE)

# Check the first few rows of the processed data
head(gdp_monthly)

#----------------------------------------------------------------------------------------------#


#--------------------code for converting crude oil prices frequency from daily to monthly-----------------#

library(dplyr)
library(lubridate)

# Read the crude oil dataset
oil <- read.csv("CrudeOilPrices.csv") %>% 
  rename(Date = observation_date, Price = DCOILWTICO)

# Convert Date to actual Date type
oil$Date <- as.Date(oil$Date)

# Filter out NA prices
oil <- oil %>% filter(!is.na(Price))

# Group by year-month and calculate average price per month
oil_monthly <- oil %>%
  mutate(Month = floor_date(Date, "month")) %>%
  group_by(Month) %>%
  summarize(Oil_Price = mean(Price, na.rm = TRUE))

# Save the processed data to a CSV file
write.csv(oil_monthly, "CrudeOilPrices.csv", row.names = FALSE)

# View the first few rows
head(oil_monthly)


#---------------------------------Code for getting final data set by applying joins------------------#


# Read all CSVs
library(readr)

inflation <- read_csv("Inflation.csv") %>% #rename(Date = observation_date, Inflation = CPIAUCNS)
unemp     <- read_csv("UnemploymentRate.csv") %>% #rename(Date = observation_date, Unemployment = UNRATE)
gdp       <- read_csv("GdpGrowthRate.csv") #%>% rename(Date = observation_date, GDP = A191RL1Q225SBEA)
rate      <- read_csv("FedralFundsRate.csv") %>% #rename(Date = observation_date, InterestRate = FEDFUNDS)
m2        <- read_csv("M2SL.csv") %>% #rename(Date = observation_date, M2 = M2SL)
oil       <- read_csv("CrudeOilPrices.csv") #%>% rename(Date = observation_date, Oil = DCOILWTICO)

# Merge all
data_all <- inflation %>%
  left_join(unemp, by = "Date") %>%
  left_join(gdp, by = "Date") %>%
  left_join(rate, by = "Date") %>%
  left_join(m2, by = "Date") %>%
  left_join(oil, by = "Date")

# Remove NA rows (optional)
data_all <- na.omit(data_all)

# Save as final CSV
write_csv(data_all, "USA_Inflation_Data.csv")
#------------------------code for getting only 35 tuples of year2009 to 2024-----------------# 
data_filtered <- data_all[47:82, ]
write_csv(data_filtered, "USA_Inflation_Filtered_Data.csv")
