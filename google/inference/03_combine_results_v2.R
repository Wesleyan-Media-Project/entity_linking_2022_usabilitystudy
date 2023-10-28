# Post-processing for the entity linking results
# First, fix Dartanyon Williams by making him a House, not Senate candidate
# Then, save that result as it is, with separate fields
# Finally, gather up all detected entities from different fields and put them all together
library(tidyverse)
library(data.table)
library(dplyr)
library(tidyr)
library(stringr)

combined <- read_csv("./google/data/new_entity_linking_results_google_2022.csv")

#----
# Combine fields
combined2 <- combined %>%
  select(ad_id, ends_with('detected_entities')) %>% 
  mutate(across(ends_with('detected_entities'), function(x){str_remove_all(x, "\\[|\\]|\\'")}))

combined2[combined2 == ""] <- NA

combined3 <- combined2 %>% 
  unite(col = detected_entities, ends_with('detected_entities'), sep = ", ", na.rm = T)

# Save version with combined fields
write_csv(combined3, "./google/data/new_entity_linking_results_google_2022_notext_combined_20231025.csv")

