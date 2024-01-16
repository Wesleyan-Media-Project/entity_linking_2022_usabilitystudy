# Post-processing for the entity linking results

library(data.table)
library(dplyr)
library(tidyr)
library(stringr)

el <- fread("../data/entity_linking_results_google_2022.csv.gz")

#----
# Fix Dartanyon Williams by making him a House, not Senate candidate
el <- el %>% mutate(across(ends_with('detected_entities'), function(x){str_replace_all(x, "S0LA00329", "H0LA06052")}))

#----
# Save a version with all fields
fwrite(el, "../../../data/entity_linking_results_google_2020_notext_all_fields.csv.gz")

#----
# Combine fields
el <- el %>%
  select(ad_id, ends_with('detected_entities')) %>% 
  mutate(across(ends_with('detected_entities'), function(x){str_remove_all(x, "\\[|\\]|\\'")}))
el[el == ""] <- NA
el <- el %>% 
  unite(col = detected_entities, ends_with('detected_entities'), sep = ", ", na.rm = T)
# Save version with combined fields
fwrite(el, "../../../data/entity_linking_results_google_2022_notext_combined.csv.gz")

