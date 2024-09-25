library(data.table)
library(stringr)
library(readxl)
library(haven)
library(reshape2)

# Input files
path_val <- "../datasets/fb_2022_train.xlsx" # This is the human coded training data for Facebook 2022
path_allcands <- "../datasets/candidates/wmpcand_120223_wmpid.csv"
# Output files
path_output <- "facebook/data/eval_ready.rdata"


#----
# Validated data
val <- read_excel(path_val)

val$ad_id <- val$adid

val2 <- val %>% 
  select(ad_id, CAND1, CAND2, CAND3, CAND4, CAND5, CAND6, CAND7, CAND8, MORETHAN8_TXT, 
         othercand1_txt, othercand2_txt, othercand3_txt, othercand4_txt, othercand5_txt)

#val2 <- val %>% select(ad_id, CAND1, CAND2, CAND3, CAND4, CAND5, CAND6, CAND7, CAND8)

allcands <- fread(path_allcands, data.table = F)
allcands2 <- allcands %>% select(wmpid, full_name)

# Step 1: Add a unique ID column to val2 to ensure alignment later
val2$id <- 1:nrow(val2)

# Step 2: Reshape the data from wide to long
cols <- c("CAND1", "CAND2", "CAND3", "CAND4", "CAND5", "CAND6", "CAND7", "CAND8",
          "MORETHAN8_TXT", "othercand1_txt", "othercand2_txt", "othercand3_txt", 
          "othercand4_txt", "othercand5_txt")

#cols <- c("CAND1", "CAND2", "CAND3", "CAND4", "CAND5", "CAND6", "CAND7", "CAND8")

val2_long <- melt(val2, measure.vars = cols, variable.name = "Candidate", value.name = "full_name")

# Step 3: Convert the candidate names and full_name column to lowercase
val2_long$full_name <- tolower(val2_long$full_name)
allcands2$full_name <- tolower(allcands2$full_name)

# Step 4: Merge val2_long with allcands2 based on the candidate names
val2_long <- merge(val2_long, allcands2, by = "full_name", all.x = TRUE)

# Step 5: Group by ad_id and summarize the wmpid values into a list
val3 <- val2_long %>%
  group_by(ad_id) %>%
  summarize(val_all = list(na.omit(unique(wmpid)))) %>%
  ungroup()

save(val3, file = path_output)

