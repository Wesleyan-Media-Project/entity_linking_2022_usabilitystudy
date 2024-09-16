library(data.table)
library(dplyr)
library(tidyr)
library(stringr)

# Input files
path_ner_4k <- "facebook/validation/fb_2022_sample.csv"
path_text <- "../fb_2022/fb_2022_adid_text.csv.gz"
# Output files
path_ner_4k_prepared <- "facebook/data/ner_linking_sample_4k_separate.csv"


df <- fread(path_ner_4k, colClasses = "character", encoding = "UTF-8")
text <- fread(path_text, colClasses = "character", encoding = "UTF-8")

df2 <- merge(df, text, by = 'ad_id')


fix_brackets <- function(x){
  x <- str_remove(x,  '\\[\\"\\"')
  x <- str_remove(x,  '\\"\\"\\]')
  x <- str_replace_all(x,  '\\"\\"', '\\"')
  return(x)
}

df2$page_name <- df2$page_name.x
df2$disclaimer <- df2$disclaimer.x
df2$ad_creative_body <- df2$ad_creative_body.x

df3 <- df2 %>%
  select(ad_creative_body, 
         ad_creative_link_caption, ad_creative_link_title, 
         ad_creative_link_description, google_asr_text,
         aws_ocr_text_img, aws_ocr_text_vid, ad_id)

df3 <- df3 %>%
  mutate(across(c(ad_creative_body, 
                  ad_creative_link_caption, ad_creative_link_title, 
                  ad_creative_link_description, google_asr_text,
                  aws_ocr_text_img, aws_ocr_text_vid),
                fix_brackets))

df4 <- pivot_longer(df3, -ad_id, names_to = "field", values_to  = "text")
df4 <- df4[df4$text != "",]
df4 <- df4[is.na(df4$text) == F,]

fwrite(df4, path_ner_4k_prepared)

