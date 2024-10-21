#!/bin/bash

DATASETS="datasets"
FBTEXT="fb_2022_adid_text.csv"
FBVAR1="fb_2022_adid_var1.csv"
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

dataset_exists() {

    param1=$1

    # Check if the file exists in the current directory
    if [ -f "Downloads/$param1" ]; then
        echo "File '$param1' exists. Compressing it now..."
        gzip "$param1"
        echo "File '$param1' has been compressed to '$param1.gz'."
        return 0
    else
        if [ -f "Downloads/$param1.gz" ]; then
            return 0
        else
            return 1
        fi
    fi
}

setup_venv() {
    echo "Creating Python 3.10 virtual environment..."
    python3.10 -m venv venv

    echo "Starting virtual environment venv..."
    source venv/bin/activate
}

install_python_packages() {
    echo "Installing spaCy version 3.2.4..."
    pip3 install spacy==3.2.4

    echo "Installing numpy version 1.26.2..."
    pip3 install numpy==1.26.2

    echo "Downloading spaCy's large English model..."
    python3.10 -m spacy download en_core_web_lg

    echo "Installing pandas version 2.1.1..."
    pip3 install pandas==2.1.1

    echo "All python installations completed successfully."
}

install_r_packages() {
    echo "Installing necessary R packages using the command line..."

    # Define an array of packages to install
    packages=(
        "dplyr"
        "data.table"
        "stringr"
        "tidyr"
        "R.utils"
    )

    # Loop through the array and install each package
    for package in "${packages[@]}"; do
        Rscript -e "install.packages('$package', repos='http://cran.rstudio.com/')"
    done

    echo "All R installations completed successfully."
}

run_inference_scripts() {

    echo "*** Now running 01_create_EL_training_data.R... ***"
    Rscript facebook/train/01_create_EL_training_data.R
    if [ $? -eq 0 ]; then
        echo "*** 01_create_EL_training_data.R ran successfully! ***"
        echo "*** Now running 02_train_entity_linking.py... ***"

        python3 facebook/train/02_train_entity_linking.py
        if [ $? -eq 0 ]; then
            echo "*** 02_train_entity_linking.py ran successfully! ***"
        else   
            exit
        fi
    else 
        exit
    fi
    
}

remove_venv() {
    rm -r "venv"
    echo "Deleted virtual environment"    
}

## Main Execution

# Clones datasets repo into parent directory if it doesn't already exist there
if ! repo_exists "$DATASETS"; then
    git clone https://github.com/Wesleyan-Media-Project/datasets.git
fi

if dataset_exists "$FBTEXT" && dataset_exists "$FBVAR1"; then

    echo "Files '$FBTEXT' and '$FBVAR1' exist!"
    echo

    # Sets up virtual environment, installs all necessary packages
    setup_venv
    install_python_packages
    install_r_packages

    # Makes entity_linking_2022_usabilitystudy repo current directory
    echo
    echo "*** Moving into '$ENTITY' directory... ***"
    echo
    cd $ENTITY

    # Attempts to run scripts
    run_inference_scripts

    # Deletes virtual environment at the end of process
    remove_venv

else

    if ! dataset_exists "$FBTEXT"; then
        echo "File '$FBTEXT' does not exist in the home directory."
        echo "Please download from Figshare."
    else
        echo "File '$FBTEXT' exists."
    fi
    if ! dataset_exists "$FBVAR1"; then
        echo "File '$FBVAR1' does not exist in the home directory."
        echo "Please download from Figshare."
    else
        echo "File '$FBVAR1' exists."
    fi
fi