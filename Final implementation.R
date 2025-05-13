#------------------------------------- Load Required Libraries -------------------------------------#
library(readr)
library(dplyr)
library(tidyr)
library(ggplot2)
library(GGally)
library(caret)
library(e1071)
library(randomForest)
library(forecast)
library(tseries)

#------------------------------------- Load and Prepare Data -------------------------------------#
data <- read_csv("USA_Inflation_Filtered_Data.csv")
data$Date <- as.Date(data$Date)
data <- data[complete.cases(data), ]
summary(data)

#------------------------------------- Boxplot for Scaled Data -------------------------------------#
data_scaled <- data %>%
  mutate(across(c(Inflation, Unemployment, GDP, InterestRate, M2, Oil), 
                ~ scale(.)[,1], .names = "{.col}_scaled")) %>%
  select(Date, ends_with("_scaled")) %>%
  pivot_longer(cols = -Date, names_to = "Variable", values_to = "Value")

ggplot(data_scaled, aes(x = Variable, y = Value, fill = Variable)) +
  geom_boxplot() +
  theme_minimal() +
  labs(title = "Standardized Boxplot of Economic Indicators",
       x = "Variable", y = "Standardized Value") +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

#------------------------------------- Outlier Detection and Removal -------------------------------------#
remove_outliers <- function(df) {
  for (col in names(df)[sapply(df, is.numeric)]) {
    Q1 <- quantile(df[[col]], 0.25)
    Q3 <- quantile(df[[col]], 0.75)
    IQR_val <- Q3 - Q1
    df <- df[df[[col]] >= Q1 - 1.5 * IQR_val & df[[col]] <= Q3 + 1.5 * IQR_val, ]
  }
  return(df)
}

data_clean <- remove_outliers(data)
scaled_data <- data_clean
scaled_data[sapply(scaled_data, is.numeric)] <- scale(scaled_data[sapply(scaled_data, is.numeric)])


#--------------------------Code for scatter pliots------------------------------------------------#
# Load required library
library(GGally)

# Remove the Date column for plotting
data_for_plot <- data_filtered[, -1]  # Remove Date column

# Generate scatter plot matrix
ggpairs(data_for_plot,
        title = "Scatter Plot Matrix of Economic Indicators",
        upper = list(continuous = wrap("cor", size = 3)),
        lower = list(continuous = wrap("points", alpha = 0.6, size = 1)),
        diag = list(continuous = wrap("densityDiag")))  # Histogram or density on diagonal


#------------------------------------- Train-Test Split -------------------------------------#
set.seed(123)
train_index <- createDataPartition(scaled_data$Inflation, p = 0.8, list = FALSE)
train_data <- scaled_data[train_index, ]
test_data <- scaled_data[-train_index, ]

#------------------------------------- Feature Selection -------------------------------------#
control <- rfeControl(functions = rfFuncs, method = "cv", number = 5)
rfe_result <- rfe(train_data[, -which(names(train_data) == "Inflation")],
                  train_data$Inflation, sizes = 1:5, rfeControl = control)
best_vars <- predictors(rfe_result)

train_data <- train_data[, c(best_vars, "Inflation")]
test_data <- test_data[, c(best_vars, "Inflation")]

#------------------------------------- ARIMA with Exogenous Variables (ARIMAX) -------------------------------------#
inflation_ts <- ts(train_data$Inflation, frequency = 4)
xreg_train <- as.matrix(sapply(train_data[, best_vars], as.numeric))
xreg_test <- as.matrix(sapply(test_data[, best_vars], as.numeric))

arima_model <- auto.arima(inflation_ts, xreg = xreg_train)
forecast_values <- forecast(arima_model, xreg = xreg_test, h = nrow(test_data))
arima_pred <- as.numeric(forecast_values$mean)
arima_mse <- mean((test_data$Inflation - arima_pred)^2)

#------------------------------------- SVM Model -------------------------------------#
svm_model <- svm(Inflation ~ ., data = train_data)
svm_pred <- predict(svm_model, newdata = test_data)
svm_mse <- mean((test_data$Inflation - svm_pred)^2)

#------------------------------------- Random Forest -------------------------------------#
rf_model <- randomForest(Inflation ~ ., data = train_data)
rf_pred <- predict(rf_model, newdata = test_data)
rf_mse <- mean((test_data$Inflation - rf_pred)^2)

#------------------------------------- Results Summary -------------------------------------#
results <- data.frame(
  Model = c("ARIMAX", "SVM", "Random Forest"),
  MSE = c(arima_mse, svm_mse, rf_mse)
)
print(results)

#------------------------------------- Visualization Function -------------------------------------#
plot_actual_vs_pred <- function(actual, predicted, title, color) {
  valid_data <- data.frame(Actual = actual, Predicted = predicted)
  valid_data <- valid_data[!is.na(valid_data$Actual) & !is.na(valid_data$Predicted), ]
  
  if (nrow(valid_data) > 0) {
    ggplot(valid_data, aes(x = 1:nrow(valid_data))) +
      geom_line(aes(y = Actual), color = "blue", size = 1.2) +
      geom_line(aes(y = Predicted), color = color, linetype = "dashed", size = 1.2) +
      labs(title = title, y = "Inflation") +
      theme_minimal()
  } else {
    warning("No valid data for plotting.")
  }
}

#------------------------------------- Plot Actual vs Predicted (Separate) -------------------------------------#
plot_actual_vs_pred(test_data$Inflation, arima_pred, "ARIMA: Actual vs Predicted", "red")
plot_actual_vs_pred(test_data$Inflation, svm_pred, "SVM: Actual vs Predicted", "green")
plot_actual_vs_pred(test_data$Inflation, rf_pred, "Random Forest: Actual vs Predicted", "darkorange")

#------------------------------------- ARIMA Summary -------------------------------------#
print(summary(arima_model))
library(lmtest)
coeftest(arima_model)

#------------------------------------- Combined Prediction Plot -------------------------------------#
comparison_df <- data.frame(
  Time = 1:length(test_data$Inflation),
  Actual = test_data$Inflation,
  ARIMAX = arima_pred,
  SVM = svm_pred,
  RandomForest = rf_pred
)

comparison_long <- pivot_longer(comparison_df, cols = -Time, names_to = "Model", values_to = "Value")

ggplot(comparison_long, aes(x = Time, y = Value, color = Model, linetype = Model)) +
  geom_line(size = 1.2) +
  labs(title = "Comparison of Actual vs Predicted Inflation Values",
       x = "Time Index", y = "Inflation") +
  scale_color_manual(values = c("Actual" = "black", "ARIMAX" = "red", "SVM" = "green", "RandomForest" = "orange")) +
  scale_linetype_manual(values = c("Actual" = "solid", "ARIMAX" = "dashed", "SVM" = "dashed", "RandomForest" = "dashed")) +
  theme_minimal()

#------------------------------------- Final MSE Summary -------------------------------------#
cat("---------- Final MSE Values ----------\n")
cat("ARIMAX MSE: ", round(arima_mse, 4), "\n")
cat("SVM MSE: ", round(svm_mse, 4), "\n")
cat("Random Forest MSE: ", round(rf_mse, 4), "\n")






#########################################################################
# Display the ARIMA model
summary(arima_model)

# Or print equation components
cat("ARIMA Model Equation:\n")
cat("Coefficients:\n")
print(coef(arima_model))
cat("\nOrder (p,d,q): ", paste(arimaorder(arima_model), collapse = ","), "\n")
#########################################################################
# Print full SVM model info
print(svm_model)

# Support vectors and coefficients
summary(svm_model)
svm_model$coefs       # Coefficients of support vectors
svm_model$SV          # Support vectors themselves
#########################################################################
importance(rf_model)
varImpPlot(rf_model)

# Print the structure of the first tree
print(getTree(rf_model, k = 1, labelVar = TRUE))


library(rpart)
tree_model <- rpart(Inflation ~ ., data = train_data)
rpart.plot::rpart.plot(tree_model)
#####################################residual plots##################################










