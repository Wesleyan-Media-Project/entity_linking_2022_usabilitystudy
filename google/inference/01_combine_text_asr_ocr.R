library(data.table)
library(dplyr)
library(tidyr)

# Input files
path_ads <- "../../../google_2022/g2022_adid_01062021_11082022_text_clean.csv.gz"
# Output files
path_prepared_ads <- "../data/inference_all_google22_ads.csv.gz"

# Ads
df <- fread(path_ads, encoding = "UTF-8")

# Aggregate
df <- df %>% 
  pivot_longer(-ad_id) %>%
  filter(value != "") %>%
  mutate(id = paste(ad_id, name, sep = "__")) %>%
  select(-c(ad_id, name))
df <- aggregate(df$id, by = list(df$value), c)
names(df) <- c("text", "id")

# Save
fwrite(df, path_prepared_ads)
