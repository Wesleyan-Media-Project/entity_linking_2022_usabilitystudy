#!/bin/bash

DATASETS="datasets"
SCRAPER="face_url_scraper_2022"
ENTITY="entity_linking_2022_usabilitystudy"

repo_exists() {

    param1=$1

    # Check if the file exists in the current directory
    if [ -d "$param1" ]; then
        echo "Folder '$param1' already exists."
        return 0
    else
        return 1
    fi
}

install_r_packages() {
    echo
    echo "*** Installing necessary R packages using the command line... ***"
    echo

    Rscript -e "install.packages('dplyr', repos='http://cran.rstudio.com/')"
    Rscript -e "install.packages('haven', repos='http://cran.rstudio.com/')"
    Rscript -e "install.packages('data.table', repos='http://cran.rstudio.com/')"
    Rscript -e "install.packages('stringr', repos='http://cran.rstudio.com/')"
    Rscript -e "install.packages('quanteda', repos='http://cran.rstudio.com/')"
    Rscript -e "install.packages('readxl', repos='http://cran.rstudio.com/')"
    Rscript -e "install.packages('tidyr', repos='http://cran.rstudio.com/')"
    Rscript -e "install.packages('R.utils', repos='http://cran.rstudio.com/')"

    echo
    echo "*** All R installations completed successfully. ***"
}

## Main Execution

#Confirm we're in home directory
cd ~

# Clones datasets repo into parent directory if it doesn't already exist there
if ! repo_exists "$DATASETS"; then
    git clone https://github.com/Wesleyan-Media-Project/datasets.git
fi

# Clones face_url_scraper_2022 into parent directory if it doesn't already exist there
if ! repo_exists "$SCRAPER"; then
    git clone https://github.com/Wesleyan-Media-Project/face_url_scraper_2022.git
fi

# Install necessary R packages via command line
install_r_packages

# Makes entity_linking_2022_usabilitystudy repo current directory

echo
echo "*** Moving into '$ENTITY' directory... ***"
echo
cd $ENTITY

# Runs script
echo
echo "*** Running facebook/knowledge_base/01_construct_kb.R... ***"
Rscript facebook/knowledge_base/01_construct_kb.R

# Checks whether script ran successfully
if [ $? -eq 0 ]; then
    echo
    echo "*** 01_construct_kb.R ran successfully! ***"
    echo
fi
