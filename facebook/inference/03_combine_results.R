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


# Read in Spacy's detected entities
el <- fread(path_detected_entities)

# Transform the Python-based detected entities field so it can be split later
el$text_detected_entities <- str_remove_all(el$text_detected_entities, "\\[|\\]|\\'")
el$text_detected_entities <- str_remove_all(el$text_detected_entities, " ")
# Remove all ads with no detected entities
el <- el %>% filter(text_detected_entities != "")
# Split the Python-based id field
el$id <- str_split(el$id, "\\|")
# Remove the ad field, we only care about ad id here
el$id <- lapply(el$id, str_remove, "__(.*?)$")
# Keep only ad id and detected entities
el <- el %>% select(id, text_detected_entities)
# Unnest, this makes each row belong to separate ads
# "Re-hydrate" in WMP lingo
el <- unnest(el, cols = id)
# Combine the detected entities from different fields of each ad
el <- aggregate(el$text_detected_entities, by = list(el$id), c)
el$x <- lapply(el$x, paste, collapse = ",")
el$x <- str_split(el$x, ",")
names(el) <- c("ad_id", "detected_entities")

# Save version with combined fields
fwrite(el, path_finished_enties)

