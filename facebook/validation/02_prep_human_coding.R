library(data.table)
library(stringr)
library(readxl)
library(haven)
library(reshape2)
library(dplyr)

# Input files
path_val <- "../datasets/facebook/fb_2022_train.xlsx" # This is the human coded training data for Facebook 2022
path_kb <- "facebook/data/entity_kb.csv"
# Output files
path_output_kb <- "facebook/data/eval_ready_kb.rdata"

#----
kb <- fread(path_kb, colClasses = "character", encoding = "UTF-8") %>%
  select(id, name)

# Validated data
val <- read_excel(path_val)

val$ad_id <- val$adid

val2 <- val %>% select(ad_id, CAND1, CAND2, CAND3, CAND4, CAND5, CAND6, CAND7, CAND8)

# Step 1: Add a unique ID column to val2 to ensure alignment later
val2$id <- 1:nrow(val2)

# Step 2: Reshape the data from wide to long
cols <- c("CAND1", "CAND2", "CAND3", "CAND4", "CAND5", "CAND6", "CAND7", "CAND8")

val2_long <- melt(val2, measure.vars = cols, variable.name = "Candidate", value.name = "full_name")

# Step 3: Convert the candidate names and full_name column to lowercase
val2_long$full_name <- tolower(val2_long$full_name)
kb$full_name <- tolower(kb$name)

# Step 4: Merge val2_long with allcands2 based on the candidate names
val2_long_kb <- merge(val2_long, kb, by = "full_name", all.x = TRUE)

# Step 5: Group by ad_id and summarize the wmpid values into a list
val3_kb <- val2_long_kb %>%
  group_by(ad_id) %>%
  summarize(val_all = list(na.omit(unique(id.y)))) %>%
  ungroup()

save(val3_kb, file = path_output_kb)

