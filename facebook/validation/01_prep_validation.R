library(data.table)
library(dplyr)
library(tidyr)
library(stringr)

# Input files
path_ner_4k <- "facebook/validation/fb_2022_sample.csv"
path_el <- "facebook/data/entity_linking_results_fb22_notext.csv.gz"
path_var <- "../data_post_production/fb_2022_adid_var.csv.gz"
# Output files
path_ner_4k_prepared <- "facebook/data/detected_entities_sample_separate.csv"


df <- fread(path_ner_4k, colClasses = "character", encoding = "UTF-8") %>%
  select(ad_id, detected_entities, aws_face)

var <- fread(path_var, colClasses = "character", encoding = "UTF-8") %>%
  select(ad_id, aws_face_federal)

el <- fread(path_el, colClasses = "character", encoding = "UTF-8") %>%
  dplyr::filter(field != "disclaimer" & field != "page_name")

# Keep only relevant ads
df2 <- merge(df, el, by = 'ad_id') %>%
  select(ad_id, text_detected_entities)

# Transform the Python-based detected entities field into an R list
transform_pylist <- function(x){
  x <- str_remove_all(x, "\\[|\\]|\\'")
  x <- str_remove_all(x, " ")
  return(x)
}

df2$detected_entities <- transform_pylist(df2$text_detected_entities)

df3 <- df2 %>%
  group_by(ad_id) %>%
  summarise(detected_entities_all = paste(na.omit(detected_entities[detected_entities != ""]), collapse = ","))
  
df4 <- merge(df3, var, by = 'ad_id')

df5 <- df4 %>%
  mutate(ent_all = ifelse(is.na(detected_entities_all) | detected_entities_all == "", 
                          aws_face_federal, 
                          ifelse(is.na(aws_face_federal) | aws_face_federal == "", 
                                 detected_entities_all, 
                                 paste(detected_entities_all, aws_face_federal, sep = ","))))

df5 <- df5 %>%
  select(ad_id, ent_all)

# Function to remove duplicates, reformat, and handle empty values
df6 <- df5 %>%
  mutate(combined_entities = sapply(strsplit(ent_all, ","), function(x) {
    unique_ids <- unique(x)                           
    unique_ids <- unique_ids[unique_ids != ""]        
    if (length(unique_ids) == 0) {
      return("[]")                                    
    } else {
      formatted_ids <- paste0("['", paste(unique_ids, collapse = "', '"), "']") 
      return(formatted_ids)
    }
  }))

df7 <- df6 %>%
  select(ad_id, combined_entities)

fwrite(df7, path_ner_4k_prepared)

