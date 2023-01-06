library(data.table)
library(dplyr)
library(tidyr)
library(stringr)
library(stringi)

# Input files
path_fb22 <- "../../../datasets/facebook/fb2022_master_0905_1108.csv.gz"
path_fb22_asr <- "../../../datasets/facebook/fb2022_asr_1108.csv.gz"
# path_fb22_ocr <- ""
# Output files
path_prepared_ads <- "../data/inference_all_fb22_ads.csv.gz"


# OCR
# ocr <- 
#   fread(path_118m_ocr, colClasses = "character") %>%
#   select(ad_id, aws_text) %>%
#   rename(ocr = aws_text)
# ocr$ad_id <- paste0("x", ocr$ad_id)
# ocr <- filter(ocr, ocr != "")
# #replace all the semicolons with period space, since it messes with spacy
# ocr$ocr <- str_replace_all(ocr$ocr, ";", ". ")

# ASR
# still contains extraneous ads -- they get removed at the merge below
asr <- fread(path_fb22_asr, data.table = F)
asr <- asr %>% 
  select(ad_id, google_asr_text) %>% 
  rename(asr = google_asr_text)

# Text
text <- fread(path_fb22, colClasses = "character", encoding = "UTF-8")
text <- text %>% 
  rename(disclaimer = funding_entity) %>% 
  select(ad_id, pd_id, page_name, disclaimer, ad_creative_body,ad_creative_link_caption, ad_creative_link_title,ad_creative_link_description)

# Clean up brackets
clean_brackets <- function(x){
  x <- str_remove(x,  '\\[\\"\\"')
  x <- str_remove(x,  '\\"\\"\\]')
  x <- str_replace_all(x,  '\\"\\"', '\\"')
}
# Apply the function to all text columns
text <- text %>%
  mutate(across(c(ad_creative_body, page_name, disclaimer,
                  ad_creative_link_caption, ad_creative_link_title, 
                  ad_creative_link_description),
                clean_brackets))


#----
# Combine text with ASR
df <- left_join(text, asr, by = "ad_id")

# Convert all NAs to just empty strings
nas_to_emptystr <- function(values){
  values[is.na(values)] <- ""
  return(values)
}

df <- df %>%
  mutate(across(c(ad_creative_body, page_name, disclaimer,
                  ad_creative_link_caption, ad_creative_link_title, 
                  ad_creative_link_description, asr),
                nas_to_emptystr))


# Kick out empty ads
df <- df[!(df$ad_creative_body == "" & df$page_name == "" & df$disclaimer == "" & df$ad_creative_link_caption == "" & df$ad_creative_link_title == "" & df$ad_creative_link_description == "" & df$asr == "" ),]
# Replace newlines with spaces
df <- df %>%
  mutate(across(c(ad_creative_body, page_name, disclaimer,
                  ad_creative_link_caption, ad_creative_link_title, 
                  ad_creative_link_description, asr),
                str_replace_all, "\\\\n", " "))

# Clean up extraneous spaces
df <- df %>%
  mutate(across(c(ad_creative_body, page_name, disclaimer,
                  ad_creative_link_caption, ad_creative_link_title, 
                  ad_creative_link_description, asr),
                str_squish))

# Aggregate so that all text fields are in one column
# And each unique text only occurs once
# Mapping back to which ads/fields have that text
# aka 'dehydrate'
# The reason we do this after all of the above
# even though it would be more elegant otherwise
# is because those transformations might help make some texts non-unique
df <- df %>% 
  select(-pd_id) %>% 
  pivot_longer(-ad_id) %>%
  filter(value != "") %>%
  mutate(id = paste(ad_id, name, sep = "__")) %>%
  select(-c(ad_id, name))
df <- aggregate(df$id, by = list(df$value), c)
# The last step can be reverted with
# df = unnest(df, cols = x)
names(df) <- c("text", "id")

# Save
fwrite(df, path_prepared_ads)
