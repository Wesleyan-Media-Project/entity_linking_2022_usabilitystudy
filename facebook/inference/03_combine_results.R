# Post-processing for the entity linking results
# Gather up all detected entities from different fields and put them all together

library(data.table)
library(dplyr)
library(tidyr)
library(stringr)

# Paths
# In
path_detected_entities <- "../data/entity_linking_results_fb22_notext.csv.gz"
# Out
path_finished_enties <- "../data/detected_entities_fb22.csv.gz"
path_finished_enties_for_ad_tone <- "../data/detected_entities_fb22_for_ad_tone.csv.gz"

# Read in Spacy's detected entities
el <- fread(path_detected_entities)

# Transform the Python-based detected entities field into an R list
transform_pylist <- function(x){
  x <- str_remove_all(x, "\\[|\\]|\\'")
  x <- str_remove_all(x, " ")
  return(x)
}
el$text_detected_entities <- transform_pylist(el$text_detected_entities)
# Remove all ads with no detected entities
el <- el %>% filter(text_detected_entities != "")
# For ad tone, remove disclaimer and page_name
el_at <- el %>% filter(!field %in% c("page_name", "disclaimer"))
# Aggregate over fields, then clean up and put things back into a list
el <- aggregate(el$text_detected_entities, by = list(el$ad_id), c)
el$x <- lapply(el$x, paste, collapse = ",")
el$x <- str_split(el$x, ",")
names(el) <- c("ad_id", "detected_entities")
# Same for ad tone
el_at <- aggregate(el_at$text_detected_entities, by = list(el_at$ad_id), c)
el_at$x <- lapply(el_at$x, paste, collapse = ",")
el_at$x <- str_split(el_at$x, ",")
names(el_at) <- c("ad_id", "detected_entities")

# Save version with combined fields
fwrite(el, path_finished_enties)
fwrite(el_at, path_finished_enties_for_ad_tone)
