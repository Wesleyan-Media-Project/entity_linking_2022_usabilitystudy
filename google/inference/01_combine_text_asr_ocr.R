library(tidyverse)
library(data.table)
library(dplyr)
library(tidyr)

# NOTE: The paths below are written with the assumption that you are running
# from the entity_linking_2022 directory. If you are running from elsewhere,
# they may need to be adjusted.

# Input files
# GET FIGSHARE LINK
path_ads <- "../google_2022/g2022_adid_01062021_11082022_text.csv.gz"
# Output files
path_prepared_ads <- "google/data/inference_all_google22_ads.csv.gz"

df <- fread(path_ads, encoding = "UTF-8")

df2 <- df %>%
  select(c(
    ad_id, ad_title, google_asr_text, aws_ocr_video_text,
    aws_ocr_img_text, advertiser_name, ad_text, description
  ))

# Aggregate
df3 <- df2 %>%
  pivot_longer(-ad_id) %>%
  filter(value != "") %>%
  mutate(id = paste(ad_id, name, sep = "__")) %>%
  select(-c(ad_id, name))

# Add the concatenation step
df4 <- df3 %>%
  group_by(value) %>%
  summarize(id = paste(id, collapse = " | ")) %>%
  ungroup()

names(df4) <- c("text", "id")

# Save
fwrite(df4, path_prepared_ads)
