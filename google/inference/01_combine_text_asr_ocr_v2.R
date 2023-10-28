library(tidyverse)
library(data.table)
library(dplyr)
library(tidyr)

# Input files
path_ads <- "../../google_2022/google2022_adidlevel_text.csv"
# Output files
path_prepared_ads <- "../data/inference_all_google22_ads_20231028.csv.gz"

df_new <- fread(path_ads, encoding = "UTF-8")

# 5148 unique advertiser_id
# 5134 unique advertiser_name
# 5276 unique combination of the two

# Aggregate
df_new3 <- df_new %>% 
  pivot_longer(-ad_id) %>%
  filter(value != "") %>%
  mutate(id = paste(ad_id, name, sep = "__")) %>%
  select(-c(ad_id, name))

# Add the concatenation step
df_new4 <- df_new3 %>%
  group_by(value) %>%
  summarize(id = paste(id, collapse = " | ")) %>%
  ungroup()

names(df_new4) <- c("text", "id")

# Save
fwrite(df_new4, path_prepared_ads)
