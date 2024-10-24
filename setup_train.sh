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

    # Check if the file exists in Downloads as a csv or gz
    if [[ -f "Downloads/$param1" || -f "Downloads/$param1.gz" ]]; then
        # If it exists as a csv then gzip
        if [ -f "Downloads/$param1" ]; then
            echo "File '$param1' exists. Compressing it now..."
            gzip "$param1"
            echo "File '$param1' has been compressed to '$param1.gz'."
        fi
        sudo mv ~/Downloads/$param1.gz ~/   
        echo "File '$param1' has been moved to your home directory."
        return 0
    else
        # Check if file is already in home directory
        if [ -f "$param1.gz" ]; then
            return 0
        fi
        return 1
    fi
}

# Function to check if Python 3.10 is installed
check_python_version() {
    # Get the Python 3.10 version if installed
    PYTHON_VERSION=$(python3.10 --version 2>/dev/null)
    
    if [[ $PYTHON_VERSION == *"Python 3.10"* ]]; then
        echo "Python 3.10 is installed: $PYTHON_VERSION"
        return 0  # Python 3.10 is installed
    else
        return 1  # Python 3.10 is not installed
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

setup_venv() {
    VENV_DIR="venv"

    # Check if the virtual environment already exists
    if [ -d "$VENV_DIR" ]; then
        echo "Virtual environment '$VENV_DIR' already exists. Skipping creation."
    else
        echo "Creating Python 3.10 virtual environment..."
        python3.10 -m venv $VENV_DIR

        echo "Virtual environment '$VENV_DIR' created successfully."
    fi
    echo "Starting virtual environment venv..."
    source $VENV_DIR/bin/activate
}

install_python_packages() {
    echo "*** Installing necessary Python packages... ***"

    # Define an array of package names
    packages=(
        "spacy"
        "numpy"
        "pandas"
    )

    # Define an array of corresponding versions
    versions=(
        "3.2.4"
        "1.26.2"
        "2.1.1"
    )

    # Loop through the array and install each package if not already installed
    for i in "${!packages[@]}"; do
        package=${packages[$i]}
        version=${versions[$i]}

        # Check if the package is already installed
        if pip show "$package" >/dev/null 2>&1; then
            installed_version=$(pip show "$package" | grep "Version:" | awk '{print $2}')
            if [ "$installed_version" == "$version" ]; then
                echo "$package (version $version) is already installed. Skipping."
            else
                echo "$package is installed, but not the correct version ($installed_version). Installing version $version..."
                pip install "$package==$version"
            fi
        else
            echo "Installing $package (version $version)..."
            pip install "$package==$version"
        fi
    done

    echo "*** All Python packages installed successfully. ***"

    echo "*** Downloading spaCy's large English model if not present... ***"
    if python -m spacy validate | grep -q "en_core_web_lg"; then
        echo "spaCy's large English model already installed. Skipping."
    else
        python -m spacy download en_core_web_lg
    fi

    echo "*** All installations and checks completed successfully. ***"
}

install_r_packages() {
    echo "*** Installing necessary R packages using the command line... ***"

    # Define an array of packages to install
    packages=(
        "dplyr"
        "data.table"
        "stringr"
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

## Main Execution

#Confirm we're in home directory
cd $HOME

if check_python_version && check_r_version; then

    # Clones datasets repo into parent directory if it doesn't already exist there
    if ! repo_exists "$DATASETS"; then
        git clone https://github.com/Wesleyan-Media-Project/datasets.git
    fi

    if dataset_exists "$FBTEXT" && dataset_exists "$FBVAR1"; then
        echo "Files '$FBTEXT' and '$FBVAR1' exist!"

        # Sets up virtual environment, installs all necessary packages
        setup_venv
        install_python_packages
        install_r_packages

        # Makes entity_linking_2022_usabilitystudy repo current directory
        echo "*** Moving into '$ENTITY' directory... ***"
        cd $ENTITY

        # Attempts to run scripts
        run_inference_scripts

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
else

    if ! check_r_version; then
        echo "R is not installed."
        echo "Please install R by downloading and opening this package (macOS): https://cran.r-project.org/bin/macosx/"
    fi
    if ! check_python_version; then
        echo "Python 3.10 is not installed."
        echo "Please install Python 3.10.5 by downloading and opening this package (macOS): https://www.python.org/ftp/python/3.10.5/python-3.10.5-macos11.pkg.
        Make sure to add Python 3.10.5 to your PATH during installation!"
    fi

fi