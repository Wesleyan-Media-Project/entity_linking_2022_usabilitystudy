library(tidyverse)


#df_old <- read_csv("./google/data/g2022_adid_01062021_11082022_text_clean.csv")
df_new <- read_csv("C:/Users/a/Desktop/Wesleyan/CREATIVE/google_2022/google2022_adidlevel_text.csv")

# Count unique values in the 'Category' column
unique_count <- df_new %>%
  summarize(unique_values = n_distinct(wmp_creative_id))
# Print the result
print(unique_count)

unique_combinations <- df_new %>%
  distinct(advertiser_name, advertiser_id)
# Print the result
print(unique_combinations)

# 5148 unique advertiser_id
# 5134 unique advertiser_name
# 5276 unique combination of the two





#old_names <- colnames(df_old)
#new_names <- colnames(df_new)

#old_names
#new_names

#df_new2 <- df_new %>%
#  select(c('ad_id', 'advertiser_name', 'ad_title', 'ad_url',
#           'aws_ocr_video_text', 'google_asr_text', 'aws_ocr_video_text',
#           'aws_ocr_img_text'))

# Aggregate
df_new3 <- df_new %>% 
  pivot_longer(-ad_id) %>%
  filter(value != "") %>%
  mutate(id = paste(ad_id, name, sep = "__")) %>%
  select(-c(ad_id, name))

# Add the concatenation step
df_new4 <- df_new3 %>%
  group_by(value) %>%
  summarize(id = paste(id, collapse = " | ")) %>%
  ungroup()

names(df_new4) <- c("text", "id")

# Save
write_csv(df_new4, "new_inference_google22_ads.csv")



