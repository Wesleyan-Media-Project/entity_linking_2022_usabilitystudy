library(data.table)
library(stringr)
library(tidyr)
library(dplyr)
library(readr)

# Input files
path_val_ents_kb <- "facebook/data/eval_ready_kb.rdata"
path_pred_ents <- "facebook/data/detected_entities_sample_separate.csv"
path_var <- "../data_post_production/fb_2022_adid_var.csv.gz"
path_ent <- "../datasets/wmp_entity_files/Facebook/2022/wmp_fb_2022_entities_v120122.csv"

#load var
var <- read.csv(path_var) %>%
  select(ad_id, pd_id)

#load entities file
ent <- read.csv(path_ent) %>%
  select(pd_id, wmp_office, wmp_spontype) %>%
  dplyr::filter(wmp_spontype == 'campaign' & (wmp_office == 'us senate' | wmp_office == 'us house'))

#load validated entities
#load(path_val_ents)
load(path_val_ents_kb)

# keep only the federal candidate ads for kb
val4_kb <- merge(val3_kb, var, by='ad_id')
val5_kb <- merge(val4_kb, ent, by='pd_id')

#load predicted entities
df_classified <- read.csv(path_pred_ents)

# keep only the federal candidate ads
df_classified2 <- merge(df_classified, var, by='ad_id')
df_classified3 <- merge(df_classified2, ent, by='pd_id')


#Shape the classifier results into the same format
df_classified3$combined_entities <- str_remove_all(df_classified3$combined_entities, "[\\[\\'\\]]")
df_classified3$combined_entities <- str_split(df_classified3$combined_entities, ", ")

# Remove the unwanted characters
df_classified3$combined_entities2 <- gsub('c\\(|\\)|"', '', df_classified3$combined_entities)

val5_kb$val_all <- sapply(val5_kb$val_all, function(x) if(length(x) == 0) "" else x)

# Merge both dfs (kb)
df_classified4 <- left_join(val5_kb, df_classified3, by = c("ad_id" = "ad_id"))

df_classified4$detected_entities3 <- sapply(df_classified4$combined_entities2, function(x) unlist(strsplit(x, ",")))
df_classified4$detected_entities4 <- sapply(df_classified4$detected_entities3, function(x) if(length(x) == 0) "" else x)

df_classified4$detected_entities <- lapply(df_classified4$detected_entities4, function(vec) unique(trimws(vec)))
df_classified4$val_all2 <- lapply(df_classified4$val_all, function(vec) unique(trimws(vec)))


df_classified5 <- df_classified4 %>%
  select(ad_id, val_all2, detected_entities)

#-------
# Check overlap between preds and validation
# Initialize lists to store overlap and differences
in_both <- list()
in_clf <- list()
in_val <- list()

#Create a list of people who are in our model but not human-coded 
cand <- read_csv("../datasets/candidates/wmpcand_120223_wmpid.csv")
kb <- read_csv("facebook/data/entity_kb.csv")

kb$wmpid <- kb$id

kb2 <- inner_join(cand, kb, by = "wmpid")

kb3 <- anti_join(kb, cand, by = "wmpid") %>%
  filter(!(name %in% c("Donald Trump", "Joe Biden", "Mike Pence", "Kamala Harris")))

# Save as a separate list
kb_exc <- as.list(kb3$wmpid)

# Loop through each row of the dataframe
for(i in 1:nrow(df_classified5)){
  try({
    # Calculate intersections and differences between predicted and true values
    in_both[[i]] <- intersect(df_classified5$detected_entities[[i]], df_classified5$val_all2[[i]])
    in_clf[[i]] <- setdiff(df_classified5$detected_entities[[i]], df_classified5$val_all2[[i]])
    in_val[[i]] <- setdiff(df_classified5$val_all2[[i]], df_classified5$detected_entities[[i]])
  })
}

# Unlist the results
in_both_c <- unlist(in_both)
in_clf_c <- unlist(in_clf)
in_val_c <- unlist(in_val)

# Remove specific IDs from clf predictions (non-candidates, except Biden, Harris, Trump, Pence)
in_clf_c <- in_clf_c[!in_clf_c %in% kb_exc]

# Calculate metrics
TP <- length(in_both_c)
FP <- length(in_clf_c[in_clf_c!=""])
FN <- length(in_val_c[in_val_c!=""])

# Precision, recall, and F1 calculations
precision <- TP / (TP + FP)
recall <- TP / (TP + FN)
f1 <- TP / (TP + 0.5 * (FP + FN))

# Output the results
print(paste0("Precision: ", precision))
print(paste0("Recall: ", recall))
print(paste0("F1: ", f1))

# Save the results to a text file
results <- paste0("Precision: ", precision, "\n", 
                  "Recall: ", recall, "\n", 
                  "F1: ", f1, "\n")

write(results, file = "performance.txt")



####(OPTIONAL - FALSE POSITIVE CHECK) Initialize a list to store the ad_ids for False Positives####
fp_ad_ids <- list()

# Loop through each row of the dataframe
for(i in 1:nrow(df_classified5)){
  try({
    # Calculate intersections and differences between predicted and true values
    in_both[[i]] <- intersect(df_classified5$detected_entities[[i]], df_classified5$val_all2[[i]])
    in_clf[[i]] <- setdiff(df_classified5$detected_entities[[i]], df_classified5$val_all2[[i]])
    in_val[[i]] <- setdiff(df_classified5$val_all2[[i]], df_classified5$detected_entities[[i]])
    
    # Check if there are False Positives (FP) and store the corresponding ad_id
    if(length(in_clf[[i]]) > 0) {
      fp_ad_ids[[i]] <- df_classified5$ad_id[i]
    }
  })
}

# Unlist and filter out empty ad_id values
fp_ad_ids <- unlist(fp_ad_ids)
fp_ad_ids <- fp_ad_ids[fp_ad_ids != ""]

# Save the ad_ids of False Positives to a text file
write(fp_ad_ids, file = "facebook/validation/false_positives_ad_ids.txt")

# Output the saved ad_ids for verification
print(fp_ad_ids)

text <- read.csv("../data_post_production/fb_2022_adid_text.csv.gz")

# Subset the dataframe to only include rows with ad_ids in fp_ad_ids
subset_df <- text %>%
  filter(ad_id %in% fp_ad_ids)

subset_df2 <- merge(subset_df, df_classified5, by = 'ad_id') %>%
  select(-c(ad_creative_bodies, ad_snapshot_url, ad_creative_link_captions,
            ad_creative_link_titles, ad_creative_link_descriptions,
            google_asr_status, aws_status_img, aws_status_vid, product_brand,
            product_name, product_description)) %>%
  mutate(across(where(is.list), ~ sapply(., function(x) paste(x, collapse = ", "))))

write_csv(subset_df2, "facebook/validation/false_positives_ads.csv")



