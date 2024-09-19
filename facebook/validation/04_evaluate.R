library(data.table)
library(stringr)
library(tidyr)
library(dplyr)

# Input files
path_val_ents <- "facebook/data/eval_ready.rdata"
path_pred_ents <- "facebook/data/detected_entities_sample_separate.csv"


#load validated entities
load(path_val_ents)

#load predicted entities
df_classified <- read.csv(path_pred_ents)
df_classified <- df_classified %>% select(ad_id, detected_entities) 

#Shape the classifier results into the same format
df_classified$detected_entities <- str_remove_all(df_classified$detected_entities, "[\\[\\'\\]]")
df_classified$detected_entities <- str_split(df_classified$detected_entities, ", ")
df_classified$detected_entities <- lapply(df_classified$detected_entities, unique)


# Remove the unwanted characters
df_classified$detected_entities2 <- gsub('c\\(|\\)|"', '', df_classified$detected_entities)

all_ad_ids <- df_classified %>% 
  select(ad_id) %>%
  distinct()

df_classified2 <- df_classified %>%
  filter(!is.na(detected_entities2) & detected_entities2 != "") %>%
  group_by(ad_id) %>%
  summarize(detected_entities2 = paste(unique(detected_entities2), collapse = ", "), .groups = 'drop')

df_classified3 <- all_ad_ids %>%
  left_join(df_classified2, by = "ad_id") %>%
  mutate(detected_entities2 = ifelse(is.na(detected_entities2), "", detected_entities2))

val3$val_all <- sapply(val3$val_all, function(x) if(length(x) == 0) "" else x)

# Merge both dfs
df_classified4 <- left_join(val3, df_classified3, by = c("ad_id" = "ad_id"))

df_classified4$detected_entities3 <- sapply(df_classified4$detected_entities2, function(x) unlist(strsplit(x, ",")))
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

# Remove specific IDs from clf predictions
in_clf_c <- in_clf_c[!in_clf_c %in% c("WMPID4", "WMPID7")]
in_clf_c <- in_clf_c[!in_clf_c %in% paste0("WMPID", 9:20)]

# Calculate metrics
TP <- length(in_both_c)
FP <- length(in_clf_c[in_clf_c!=""])
FN <- length(in_val_c[in_val_c!=""])

# Precision, recall, F1, and accuracy calculations
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
                  "F1: ", f1)

write(results, file = "performance.txt")

