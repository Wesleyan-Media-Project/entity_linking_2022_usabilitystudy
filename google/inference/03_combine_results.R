# Post-processing for the entity linking results
library(tidyverse)
library(data.table)
library(dplyr)
library(tidyr)
library(stringr)

df <- fread("google/data/entity_linking_results_google_2022.csv.gz")
#----
# Combine fields
df2 <- df %>%
  select(ad_id, ends_with('detected_entities'), field) %>% 
  mutate(across(ends_with('detected_entities'), function(x){str_remove_all(x, "\\[|\\]|\\'")}))

df2[df2 == ""] <- NA

df3 <- df2 %>% 
  unite(col = detected_entities, ends_with('detected_entities'), sep = ", ", na.rm = T)

# Remove all ads with no detected entities
df4 <- df3 %>% filter(detected_entities != "")

# For ad tone, remove disclaimer and page_name
df4_at <- df4 %>% filter(!field %in% c("advertiser_name"))

# Aggregate based on ad_id
df5 <- df4 %>%
  group_by(ad_id) %>%
  summarize(
    detected_entities = paste(unique(detected_entities), collapse = ", "),
    field = paste(unique(field), collapse = ", ")
  )


df5_at <- df4_at %>%
  group_by(ad_id) %>%
  summarize(
    detected_entities = paste(unique(detected_entities), collapse = ", "),
    field = paste(unique(field), collapse = ", ")
  )


# Save version with combined fields
fwrite(df5, "google/data/entity_linking_results_google_2022_notext_combined.csv.gz")
fwrite(df5_at, "google/data/entity_linking_results_google_2022_notext_combined_for_ad_tone.csv.gz")
