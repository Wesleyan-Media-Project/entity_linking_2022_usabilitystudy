# Post-processing for the entity linking results

library(tidyverse)
library(data.table)
library(dplyr)
library(tidyr)
library(stringr)

combined <- fread("google/data/entity_linking_results_google_2022.csv.gz")
#----
# Combine fields
combined2 <- combined %>%
  select(ad_id, ends_with('detected_entities'), field) %>% 
  mutate(across(ends_with('detected_entities'), function(x){str_remove_all(x, "\\[|\\]|\\'")}))

combined2[combined2 == ""] <- NA

combined3 <- combined2 %>% 
  unite(col = detected_entities, ends_with('detected_entities'), sep = ", ", na.rm = T)

# Remove all ads with no detected entities
combined4 <- combined3 %>% filter(detected_entities != "")

# For ad tone, remove disclaimer and page_name
combined4_at <- combined4 %>% filter(!field %in% c("advertiser_name"))

# Aggregate based on ad_id
combined5 <- combined4 %>%
  group_by(ad_id) %>%
  summarize(
    detected_entities = paste(unique(detected_entities), collapse = ", "),
    field = paste(unique(field), collapse = ", ")
  )


combined5_at <- combined4_at %>%
  group_by(ad_id) %>%
  summarize(
    detected_entities = paste(unique(detected_entities), collapse = ", "),
    field = paste(unique(field), collapse = ", ")
  )


# Save version with combined fields
fwrite(combined5, "google/data/entity_linking_results_google_2022_notext_combined.csv.gz")
fwrite(combined5_at, "google/data/entity_linking_results_google_2022_notext_combined_for_ad_tone.csv.gz")




