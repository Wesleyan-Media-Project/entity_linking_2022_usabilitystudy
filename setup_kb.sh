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

check_r_version() {
    # Check if R is installed
    if command -v R >/dev/null 2>&1; then
        # Get the R version
        R_VERSION=$(R --version | grep -o "[0-9]*\.[0-9]*\.[0-9]*")
        echo "R is installed. Version: $R_VERSION"
        return 0
    else
        echo "R is not installed."
        return 1
    fi
}

install_r_packages() {
    echo "*** Installing necessary R packages using the command line... ***"

    # Define an array of packages to install
    packages=(
        "dplyr"
        "haven"
        "data.table"
        "stringr"
        "quanteda"
        "readxl"
        "tidyr"
        "R.utils"
    )

    # Loop through the array and check if each package is installed
    for package in "${packages[@]}"; do
        Rscript -e "
            if (!require('$package', quietly = TRUE)) {
                install.packages('$package', repos='http://cran.rstudio.com/')
            } else {
                cat('$package is already installed.\n')
            }
        "
    done

    echo "*** All necessary R packages are installed. ***"
}


## Main Execution

#Confirm we're in home directory
cd $HOME

if check_r_version; then

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

    echo "*** Moving into '$ENTITY' directory... ***"
    cd $ENTITY

    # Runs script
    echo "*** Running facebook/knowledge_base/01_construct_kb.R... ***"
    Rscript facebook/knowledge_base/01_construct_kb.R

    # Checks whether script ran successfully
    if [ $? -eq 0 ]; then
        echo "*** 01_construct_kb.R ran successfully! ***"
    fi

else
    echo "R is not installed."
    echo "Please install R by downloading and opening this package (macOS): https://cran.r-project.org/bin/macosx/"
fi
