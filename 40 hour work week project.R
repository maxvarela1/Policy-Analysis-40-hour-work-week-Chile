library(tidyverse)
library(survey)
options(scipen = 999)
#load up file with databases across years
datafiles <- list.files(path = "/Users/max/Desktop/ESI",
                   pattern = "esi_202.*csv",
                   full.names = T,
                   recursive = F)

#download files and combine while fixing one faulty column
dataset <- datafiles |> map(~read_csv(.x, col_types = cols(b5 = col_number()))) |> list_rbind()

#Clean data

dataset <- dataset |>
  mutate(
    habituales = if_else(habituales %in% c(888, 999), NA, habituales),
    efectivas = if_else(efectivas %in% c(888, 999), NA, efectivas),
    ocup_honorarios = if_else(ocup_honorarios %in% 77, NA, ocup_honorarios),
  )

#Filtering for working age and working
dataset<- dataset |> filter(edad <= 65 & edad >= 15 & ocup_ref == 1)

#Defining population groups and separating strata by year

dataset <- dataset |>
  mutate(
    group = case_when (
      categoria_ocupacion == 3 & ocup_honorarios != 1 ~ "treated_private",
      categoria_ocupacion == 4 & ocup_honorarios != 1 ~ "control_public",
      ocup_honorarios == 1 & !(categoria_ocupacion %in% c(3,4)) ~ "control_honorarios",
      T ~ NA
    ),
    post = if_else(ano_encuesta >= 2024, 1,0),
    unique_strata = paste(ano_encuesta, estrato, sep = "_"),
    unique_cluster = paste(ano_encuesta, estrato, conglomerado_correlativo, sep = "_")
  )

#Implementing survey design from code manual

design <- svydesign(
  id = ~unique_cluster,
  strata = ~unique_strata,
  weights = ~fact_cal_esi,
  check.strata = T,
  data = dataset,
)
options(survey.lonely.psu = "remove")

#Calculation 1

normalized_diff <- function(design, covariate, group_var, treated_label, control_label, year_val, year_var = "ano_encuesta") {
  
  vars <- design$variables
  
  idx_t <- vars[[group_var]] == treated_label & vars[[year_var]] == year_val
  idx_c <- vars[[group_var]] == control_label & vars[[year_var]] == year_val
  
  sub_t <- design[idx_t, ]
  sub_c <- design[idx_c, ]
  
  formula_obj <- as.formula(paste0("~", covariate)) 
 
  mean_t <- coef(svymean(as.formula(formula_obj), sub_t, na.rm = T))
  mean_c <- coef(svymean(as.formula(formula_obj), sub_c, na.rm = T))
  var_t  <- coef(svyvar(as.formula(formula_obj), sub_t, na.rm = T))
  var_c  <- coef(svyvar(as.formula(formula_obj), sub_c, na.rm = T))
  
  (mean_t - mean_c) / sqrt((var_t + var_c) / 2)
}

years <- 2021:2025
covariates <- c("edad", "sexo") 

results_public <- expand.grid(year = years, covariate = covariates, stringsAsFactors = FALSE) |>
  mutate(nd = pmap_dbl(list(covariate, year), function(cov, yr) {
    normalized_diff(design, cov, "group", "treated_private", "control_public", yr)
  }))

results_public

results_honorarios <- expand.grid(year = years, covariate = covariates, stringsAsFactors = FALSE) |>
  mutate(nd = pmap_dbl(list(covariate, year), function(cov, yr) {
    normalized_diff(design, cov, "group", "treated_private", "control_honorarios", yr)
  }))

results_honorarios

library(readxl)

Inflation_rate <- read_excel("Desktop/IPC_EMP_2023.xlsx", 
                             skip = 2)
starting_year <- 2021

Inflation_rate <- Inflation_rate |> mutate(
  month = ((row_number() - 1) %% 12) + 1,
  ano_encuesta = starting_year + ((row_number() - 1) %/% 12)
) |> group_by(ano_encuesta) |>
  summarise(average_IPC = round(mean(`1. Índice IPC General`),2))

dataset <- dataset |>
  left_join(Inflation_rate, by = "ano_encuesta")

dataset <- dataset |>
  mutate(real_ing_t_p = ing_t_p * (99.67/average_IPC))

dataset$ocup_form_name <- factor(dataset$ocup_form, labels = c("formal", "informal"))

design <- svydesign(
  id = ~unique_cluster,
  strata = ~unique_strata,
  weights = ~fact_cal_esi,
  check.strata = T,
  nest = T,
  data = dataset)

#Calculation 2 (model)

#Setting 2023 as base year for calculation

dataset$year_ref <- relevel(factor(dataset$ano_encuesta), ref = "2023")

design <- svydesign(
  id = ~unique_cluster,
  strata = ~unique_strata,
  weights = ~fact_cal_esi,
  check.strata = T,
  nest = T,
  data = dataset)

#Calculating treated group with public sector (hours worked)
private_public <- design$variables$group %in% c("treated_private", "control_public")
design_public <- design[private_public, ]

model_hours_public <- svyglm(
  habituales ~ group * year_ref,
  design = design_public,
  family = gaussian()
)

summary(model_hours_public)

#Calculating treated group with honorarios (hours worked)
private_honorarios <- design$variables$group %in% c("treated_private", "control_honorarios")
design_honorarios <- design[private_honorarios, ]

model_hours_honorarios <- svyglm(
  habituales ~ group * year_ref,
  design = design_honorarios,
  family = gaussian()
)

summary(model_hours_honorarios)

#Calculating inflation rate

model_salary_public <- svyglm(
  real_ing_t_p ~ group * year_ref,
  design = design_public,
  family = gaussian()
)

summary(model_salary_public)

model_sa
lary_honorarios <- svyglm(
  real_ing_t_p ~ group * year_ref,
  design = design_honorarios,
  family = gaussian()
)
summary(model_salary_honorarios)

#Calculation 3 (DDD)

DDD <- design$variables$group %in% c("treated_private", "control_public")
design_ddd <- design[DDD,]


model_ddd_group <- svyglm(
  habituales ~ group*post*ocup_form_name,
  design = design_ddd,
  family = gaussian()
)

summary(model_ddd_group)

model_ddd_linear <- svyglm(
  habituales ~ group*year_ref*ocup_form_name,
  design = design_ddd,
  family = gaussian()
)

summary(model_ddd_linear)

#Calculation #4 (prediction)

coefs_hours <- coef(model_hours_public)

years <- c(2021, 2022, 2023, 2024, 2025)

get_control_mean <- function(year) {
  if (year == 2023) return(coefs_hours["(Intercept)"])
  term <- paste0("year_ref", year)
  coefs_hours["(Intercept)"] + coefs_hours[term]
}

get_treated_mean <- function(year) {
  base <- get_control_mean(year) + coefs_hours["grouptreated_private"]
  if (year == 2023) return(base)
  interaction_term <- paste0("grouptreated_private:year_ref", year)
  base + coefs_hours[interaction_term]
}

treated_actual <- sapply(years, get_treated_mean)
control_actual <- sapply(years, get_control_mean)

treated_2023 <- get_treated_mean(2023)
control_2023 <- get_control_mean(2023)

treated_counterfactual <- treated_2023 + (control_actual - control_2023)

treated_gap <- treated_actual - treated_counterfactual

plot_data <- data.frame(
  year = rep(2021:2025, 2),
  value = c(treated_actual, treated_counterfactual),
  type = rep(c("With policy", "Without Policy (counterfactual)"), each = 5)
)

ggplot(plot_data, aes(x= year, y= value, color= type)) +
  geom_line()+
  geom_vline(xintercept = 2024, linetype = "dotted", color = "black")+
  annotate("text", x = 2024.1, y = max(plot_data$value), label = "Policy takes effect", hjust = 0, size = 3)+
  labs(title = "Average of hours worked in private workers with policy vs without policy",
       x= "Year", y= "Weekly hours worked")

#Calculation 4 (salary)

coefs_salary <- coef(model_salary_public) 

control_2023_salary <- coefs_salary["(Intercept)"]
treated_2023_salary <- coefs_salary["(Intercept)"] + coefs_salary["grouptreated_private"]

get_control_salary <- function(year) {
  if (year == 2023) return(coefs_salary["(Intercept)"])
  coefs_salary["(Intercept)"] + coefs_salary[paste0("year_ref", year)]
}

get_treated_salary <- function(year) {
  base <- get_control_salary(year) + coefs_salary["grouptreated_private"]
  if (year == 2023) return(base)
  base + coefs_salary[paste0("grouptreated_private:year_ref", year)]
}

treated_actual_salary <- sapply(years, get_treated_salary)
control_actual_salary <- sapply(years, get_control_salary)

treated_counterfactual_salary <- treated_2023_salary + (control_actual_salary - control_2023_salary)

plot_data_salary <- data.frame(
  year = rep(2021:2025, 2),
  value = c(treated_actual_salary, treated_counterfactual_salary),
  type = rep(c("With policy", "Without Policy (counterfactual)"), each = 5)
)

ggplot(plot_data_salary, aes(x= year, y= value, color= type)) +
  geom_line()+
  geom_vline(xintercept = 2024, linetype = "dotted", color = "black")+
  annotate("text", x = 2024.1, y = max(plot_data_salary$value), label = "Policy takes effect", hjust = 0, size = 3)+
  scale_y_continuous(
    limits = c(750000, 1000000),
    breaks = seq(750000, 1000000, by = 50000),
    labels = seq(750000, 1000000, by = 50000)
  )+
  labs(title = "Average salary for private workers with policy vs without policy",
       x= "Year", y= "Average Wage (Chilean pesos)")

#Calculation 5 (Placebo test)

dataset$post_placebo <- if_else(dataset$ano_encuesta %in% c(2022, 2023), 1, 0)

design <- svydesign(
  id = ~unique_cluster,
  strata = ~unique_strata,
  weights = ~fact_cal_esi,
  check.strata = T,
  nest = T,
  data = dataset)

private_public <- design$variables$group %in% c("treated_private", "control_public")
design_public <- design[private_public, ]

placebo_years <- design_public$variables$ano_encuesta %in% c(2021, 2022, 2023)
design_public_placebo <- design_public[placebo_years, ]

options(survey.lonely.psu = "remove")

model_hours_public_placebo <- svyglm(
  habituales ~ group * post_placebo,
  design = design_public_placebo,
  family = gaussian()
)

summary(model_hours_public_placebo)
