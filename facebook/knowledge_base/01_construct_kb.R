library(dplyr)
library(haven)
library(data.table)
library(stringr)
library(quanteda)
library(readxl)
library(tidyr)

# The working directory below assumes that you are running scripts
# from the entity_linking_2022 directory. If you are running from
# anywhere else, it may need to be adjusted.

setwd("./")

# NOTE: The paths below are written with the assumption that you are running
# from the entity_linking_2022 directory. If you are running from elsewhere,
# they may need to be adjusted.

# File paths
# In

# These files are located in our datasets repository (https://github.com/Wesleyan-Media-Project/datasets)
# Make sure the datasets folder is located in the same directory as entity_linking_2022
path_people_file <- "../datasets/people/person_2022.csv"
path_cand_file <- "../datasets/candidates/wmpcand_120223_wmpid.csv"
# Out
path_kb <- "facebook/data/entity_kb.csv"


# People file
people <- fread(path_people_file, encoding = "UTF-8", data.table = F)
# Create some additional person categories
people$pubhealth <- ifelse(people$face_category == "public health related", 1, 0)
people$cabinet <- ifelse(people$face_category == "cabinet", 1, 0)
people$historical <- ifelse(people$face_category == "historical figures", 1, 0)
# In case any of these variables contain NAs (they largely don't any more)
# Make them 0s instead
people$supcourt_2022[is.na(people$supcourt_2022)] <- 0
people$supcourt_former[is.na(people$supcourt_former)] <- 0
people$currsen_2022[is.na(people$currsen_2022)] <- 0
people$prompol[is.na(people$prompol)] <- 0
people$former_uspres[is.na(people$former_uspres)] <- 0
people$intl_leaders[is.na(people$intl_leaders)] <- 0
people$gov2022_gencd[is.na(people$gov2022_gencd)] <- 0

# Make sure there are no duplicate people
if (any(duplicated(people$wmpid))) {
  stop("There are duplicate people.")
}


# Candidate file
# Make sure that genelect is 1 so we ignore duplicate versions of the same candidate who ran for different offices but only made it to the general election in one
# Also retain only relevant variables
cands <- fread(path_cand_file, encoding = "UTF-8", data.table = F)
cands <- cands %>%
  filter(genelect_cd == 1) %>%
  select(wmpid, genelect_cd, cand_id, cand_office, cand_office_st, cand_office_dist, cand_party_affiliation)
# Make sure there are no duplicate candidates
if (any(duplicated(cands$wmpid))) {
  stop("There are duplicate candidates.")
}

# Merge candidate file into people file
people <- left_join(people, cands, by = "wmpid")

# Restrict to only 2022 candidates and other relevant people
# Also retain only relevant variables
people <- people %>%
  filter(genelect_cd == 1 | supcourt_2022 == 1 | supcourt_former == 1 | currsen_2022 == 1 | prompol == 1 | former_uspres == 1 | intl_leaders == 1 | gov2022_gencd == 1 | pubhealth == 1 | cabinet == 1 | historical == 1) %>%
  select(wmpid, full_name, first_name, last_name, fecid_2022a, fecid_2022b, genelect_cd, supcourt_2022, supcourt_former, currsen_2022, prompol, former_uspres, intl_leaders, gov2022_gencd, pubhealth, cabinet, historical, cand_id, cand_office, cand_office_st, cand_office_dist, cand_party_affiliation)


entities_candidate <- people$full_name

tks <- tokens(entities_candidate)
#---- FIRST NAME
# the first word is always the first name
people$first_name_extracted <- unlist(lapply(tks, function(x) {
  x[1]
}))

#---- LAST NAME
# If the name consists of two words, then the second one is the last name
people$last_name_extracted <- unlist(lapply(tks, function(x) {
  if (length(x) == 2) {
    x[2]
  } else {
    NA
  }
}))
# If the name consists of more than two words, then the last one is the last name
last_name_temp <- unlist(lapply(tks, function(x) {
  if (length(x) > 2) {
    x[length(x)]
  } else {
    NA
  }
}))
people$last_name_extracted[is.na(last_name_temp) == F] <- last_name_temp[is.na(last_name_temp) == F]
# if the last word is jr or sr, the second-to last word is the last name
last_word_temp <- unlist(lapply(tks, function(x) {
  x[length(x)]
}))
jr_temp_indices <- which(last_word_temp %in% c(".", "Jr", "Sr"))
jr_temp_names <- entities_candidate[jr_temp_indices]
jr_temp_suffix <- str_extract(jr_temp_names, "[J|S]r")
people$suffix_name_extracted <- NA
people$suffix_name_extracted[jr_temp_indices] <- jr_temp_suffix
jr_temp_names_without_suffix <- str_remove(jr_temp_names, " [J|S]r.?") # remove Jr/Sr + 0 or more occurence of .
jr_temp_names_without_suffix_tks <- tokens(jr_temp_names_without_suffix)
jr_temp_last_names <- unlist(lapply(jr_temp_names_without_suffix_tks, function(x) {
  x[length(x)]
}))
people$last_name_extracted[jr_temp_indices] <- jr_temp_last_names


# the II, the III
II_temp_indices <- which(last_word_temp %in% c("II", "III"))
II_temp_names <- entities_candidate[II_temp_indices]
II_temp_suffix <- str_extract(II_temp_names, "II+")
people$suffix_name_extracted[II_temp_indices] <- II_temp_suffix
II_temp_names_without_suffix <- str_remove(II_temp_names, " II+") # remove II/III
II_temp_names_without_suffix_tks <- tokens(II_temp_names_without_suffix)
II_temp_last_names <- unlist(lapply(II_temp_names_without_suffix_tks, function(x) {
  x[length(x)]
}))
people$last_name_extracted[II_temp_indices] <- II_temp_last_names

#---- MIDDLE NAMES
name_len <- unlist(lapply(tks, length))
no_middle_name <- which(name_len == 2)
no_middle_name <- sort(unique(c(no_middle_name, jr_temp_indices, II_temp_indices)))
middle_name_indices <- (1:nrow(people))[which((1:nrow(people) %in% no_middle_name) == F)] # people who do have middle names
tks_middle_names <- tks[middle_name_indices]
tks_middle_names <- lapply(tks_middle_names, function(x) {
  x[-1]
}) # remove the first word
tks_middle_names <- lapply(tks_middle_names, function(x) {
  x[-length(x)]
}) # remove the last word
tks_middle_names <- lapply(tks_middle_names, paste0, collapse = " ") # combine them and make a space so that multiple middle names, or "De La" etc. get resolved
tks_middle_names <- str_replace_all(tks_middle_names, " \\.", "\\.") # this does create a problem with periods, clean them up
tks_middle_names <- str_replace(tks_middle_names, "^\\.", "") # remove periods if they are the first char
tks_middle_names <- str_trim(tks_middle_names) # clean up spaces at beginning/end
people$middle_name_extracted <- NA
people$middle_name_extracted[middle_name_indices] <- tks_middle_names
people$middle_name_extracted[which(people$middle_name_extracted == "")] <- NA # some people ended up with an empty middle name, remove


# ----
# JASMINE'S FIXES to candidate names
# This file is located in our face_url_scraper_2022 repository (https://github.com/Wesleyan-Media-Project/face_url_scraper_2022)
# Make sure the face_url_scraper_2022 folder is located in the same directory as entity_linking_2022
fixes <- read_xlsx("../face_url_scraper_2022/data/bp2022_house_scraped_face_jasmine.xlsx") # nolint: line_length_linter.
fixes <- fixes %>%
  select(wmpid, cand_name, full_name, starts_with("hc")) %>%
  select(-c(hc_face_note, hc_face_url, hc_office_district, hc_office_district_note))

people <- left_join(people, fixes, by = "wmpid")

# Overwrite with Jasmine's fixes
people$first_name_extracted[is.na(people$hc_first_name) == F] <- people$hc_first_name[is.na(people$hc_first_name) == F]
people$middle_name_extracted[is.na(people$hc_middle_name) == F] <- people$hc_middle_name[is.na(people$hc_middle_name) == F]
people$last_name_extracted[is.na(people$hc_last_name) == F] <- people$hc_last_name[is.na(people$hc_last_name) == F]
people$suffix_name_extracted[is.na(people$hc_suffix) == F] <- people$hc_suffix[is.na(people$hc_suffix) == F]

# Correct names
people$first_name <- people$first_name_extracted
people$middle_name <- people$middle_name_extracted
people$last_name <- people$last_name_extracted
people$suffix_name <- people$suffix_name_extracted
people <- unite(people, "full_name", c(first_name, middle_name, last_name, suffix_name), sep = " ", na.rm = T, remove = F)
people <- unite(people, "full_name_first_last", c(first_name, last_name), sep = " ", na.rm = T, remove = F)
people$full_name <- str_squish(people$full_name)
people$full_name_first_last <- str_squish(people$full_name_first_last)

# ----
# CANDIDATE DESCRIPTIONS
# Party
people$party[!people$cand_party_affiliation %in% c("DEM", "REP")] <- "3rd party"
people$party[people$cand_party_affiliation == "DEM"] <- "Democratic"
people$party[people$cand_party_affiliation == "REP"] <- "Republican"
people$party[is.na(people$cand_party_affiliation)] <- NA

# District number
district_number <- as.character(as.numeric(people$cand_office_dist))
district_number <- str_replace(district_number, "$", "th")
district_number <- str_replace(district_number, "1th", "1st")
district_number <- str_replace(district_number, "2th", "2nd")
district_number <- str_replace(district_number, "3th", "3rd")
district_number <- str_replace(district_number, "11st", "11th")
district_number <- str_replace(district_number, "12nd", "12th")

# State name rather than abbreviation
state_name <- state.name[match(people$cand_office_st, state.abb)]

# Construct the descriptions
people$descr <- NA
for (i in 1:nrow(people)) {
  if (is.na(people$genelect_cd[i]) == F) {
    if (people$cand_office[i] == "H") {
      people$descr[i] <- paste0(people$full_name[i], " is a ", people$party[i], " candidate for the ", district_number[i], " District of ", state_name[i], ".")
    } else if (people$cand_office[i] == "S") {
      people$descr[i] <- paste0(people$full_name[i], " is a ", people$party[i], " Senate candidate in ", state_name[i], ".")
    }
  } else if (people$currsen_2022[i] == 1) {
    people$descr[i] <- paste0(people$full_name[i], " is a Senator.")
  } else if (people$former_uspres[i] == 1) {
    people$descr[i] <- paste0(people$full_name[i], " is a former U.S. president.")
  } else if (people$prompol[i] == 1) {
    people$descr[i] <- paste0(people$full_name[i], " is a prominent politician.")
  } else if (people$intl_leaders[i] == 1) {
    people$descr[i] <- paste0(people$full_name[i], " is an international leader.")
  } else if (people$supcourt_2022[i] == 1) {
    people$descr[i] <- paste0(people$full_name[i], " is a Supreme Court Justice.")
  } else if (people$supcourt_former[i] == 1) {
    people$descr[i] <- paste0(people$full_name[i], " is a former Supreme Court Justice.")
  } else if (people$gov2022_gencd[i] == 1) {
    people$descr[i] <- paste0(people$full_name[i], " is a gubernatorial candidate.")
  } else if (people$pubhealth[i] == 1) {
    people$descr[i] <- paste0(people$full_name[i], " is a public health official.")
  } else if (people$cabinet[i] == 1) {
    people$descr[i] <- paste0(people$full_name[i], " is a cabinet member.")
  } else if (people$historical[i] == 1) {
    people$descr[i] <- paste0(people$full_name[i], " is a historical figure.")
  }
}


# ----
# Candidate aliases
for (i in 1:nrow(people)) {
  cand_names <- c(people$full_name[i], people$last_name[i], people$full_name_first_last[i])
  if (substr(cand_names[1], nchar(cand_names[1]), nchar(cand_names[1])) != "s") {
    cand_aliases <- c(cand_names, paste0(cand_names, "'s"))
  } else {
    cand_aliases <- c(cand_names, paste0(cand_names, "'"))
  }
  cand_aliases <- c(cand_aliases, toupper(cand_aliases))

  people$aliases[[i]] <- c(cand_aliases)
}

# ----
# Create knowledge base
kb <- people %>%
  select(wmpid, full_name, descr, aliases) %>%
  rename(id = wmpid, name = full_name)

# One-off fixes
kb$descr[kb$id == "WMPID1289"] <- "Joe Biden is the U.S. president."
kb$aliases[[1107]] <- str_remove(kb$aliases[[1107]], ",") # Remove commas from MLK because it screws with the csv

# Make sure every alias only exists once (people without middle names or suffixes will have duplicates otherwise)
kb$aliases <- lapply(kb$aliases, unique)

fwrite(kb, path_kb)
# The 4 variables in this file are the only thing
# from this script that enter the entity linker
