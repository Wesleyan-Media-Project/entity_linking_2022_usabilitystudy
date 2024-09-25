library(data.table)
library(dplyr)
library(tidyr)
library(stringr)

# Input files
path_ner_4k <- "facebook/validation/fb_2022_sample.csv"
# Output files
path_ner_4k_prepared <- "facebook/data/detected_entities_sample_separate.csv"


df <- fread(path_ner_4k, colClasses = "character", encoding = "UTF-8") %>%
  select(ad_id, detected_entities, aws_face)

# Function to combine and clean columns
combine_entities <- function(detected, aws) {
  # Split by commas and trim whitespace, remove NA values
  detected_list <- unlist(strsplit(ifelse(is.na(detected), "", detected), ","))
  aws_list <- unlist(strsplit(ifelse(is.na(aws), "", aws), ","))
  
  # Combine both lists, remove empty strings, and return unique values
  combined <- unique(c(detected_list, aws_list))
  
  # If combined list is empty, return empty list else return as vector
  if (length(combined) == 0 || all(combined == "")) {
    return("[]")
  } else {
    return(paste0("['", paste(combined, collapse = "', '"), "']"))
  }
}

# Apply the function to both columns
df$combined_entities <- mapply(combine_entities, df$detected_entities, df$aws_face)

df2 <- df %>%
  select(ad_id, combined_entities)

fwrite(df2, path_ner_4k_prepared)

