library(dplyr)
library(haven)
library(data.table)
library(stringr)
library(quanteda)

# File paths
path_people_file <- "../datasets/people/person_2022_cd101222_v4.csv"
path_cand_file <- "../datasets/candidates/wmpcand_101422_wmpid.csv"

# People file
# Restrict to only 2022 candidates and other relevant people
# Also retain only relevant variables
people <- fread(path_people_file, encoding = "UTF-8", data.table = F)
people <- people %>% 
  filter(genelect_cd_2022 == 1 | supcourt_2022 == 1 | supcourt_former == 1 | currsen_2022 == 1 | prompol == 1 | former_uspres == 1 | intl_leaders == 1) %>%
  select(wmpid, full_name, first_name, last_name, fecid_2022a, fecid_2022b, genelect_cd_2022, supcourt_2022, supcourt_former, currsen_2022, prompol, former_uspres, intl_leaders, gov2022_gencd)

people$supcourt_2022[is.na(people$supcourt_2022)] <- 0
people$supcourt_former[is.na(people$supcourt_former)] <- 0
people$currsen_2022[is.na(people$currsen_2022)] <- 0
people$prompol[is.na(people$prompol)] <- 0
people$former_uspres[is.na(people$former_uspres)] <- 0
people$intl_leaders[is.na(people$intl_leaders)] <- 0
people$gov2022_gencd[is.na(people$gov2022_gencd)] <- 0

# Candidate file
# Make sure that genelect is 1 so we ignore duplicate versions of the same candidate who ran for different offices but only made it to the general election in one
# Also retain only relevant variables
cands <- fread(path_cand_file, encoding = "UTF-8", data.table = F)
cands <- cands %>% 
  filter(genelect_cd == 1) %>% 
  select(wmpid, cand_id, cand_office, cand_office_st, cand_office_dist, cand_party_affiliation)

# Merge candidate file into people file
people <- left_join(people, cands, by = 'wmpid')

# ----
# CANDIDATE DESCRIPTIONS
# Party
people$party[!people$cand_party_affiliation %in% c("DEM", "REP")] <- "3rd party"
people$party[people$cand_party_affiliation  == "DEM"] <- "Democratic"
people$party[people$cand_party_affiliation  == "REP"] <- "Republican"
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
for(i in 1:nrow(people)){
  if(is.na(people$genelect_cd_2022[i]) == F){
    if(people$cand_office[i] == "H"){
      people$descr[i] <- paste0(people$full_name[i], " is a ", people$party[i], " candidate for the ", district_number[i], " District of ", state_name[i], ".")
    }
    else if(people$cand_office[i] == "S"){
      people$descr[i] <- paste0(people$full_name[i], " is a ", people$party[i], " Senate candidate in ", state_name[i], ".")
    }
  }
  else if(people$currsen_2022[i] == 1){
    people$descr[i] <- paste0(people$full_name[i], " is a ", people$party[i], " Senator in ", state_name[i], ".")
  }
  else if(people$former_uspres[i] == 1){
    people$descr[i] <- paste0(people$full_name[i], " is a former U.S. president.")
  }
  else if(people$prompol[i] == 1){
    people$descr[i] <- paste0(people$full_name[i], " is a prominent politician.")
  }
  else if(people$intl_leaders[i] == 1){
    people$descr[i] <- paste0(people$full_name[i], " is an international leader.")
  }
  else if(people$supcourt_2022[i] == 1){
      people$descr[i] <- paste0(people$full_name[i], " is a Supreme Court Justice.")
  }
  else if(people$supcourt_former[i] == 1){
      people$descr[i] <- paste0(people$full_name[i], " is a former Supreme Court Justice.")
  }
}


# ----
# CANDIDATE ALIASES
for(i in 1:nrow(people)){
  cand_names <- c(people$full_name[i], people$last_name[i])
  if(substr(cand_names[1], nchar(cand_names[1]), nchar(cand_names[1])) != "s"){
    cand_aliases <- c(cand_names, paste0(cand_names, "'s"))
  }else{
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

fwrite(kb, "data/people_2022.csv")
# The 4 variables in this file are the only thing 
# from this script that enter the entity linker
