#!/bin/bash

DATASET="fb_2022_adid_text.csv"
ENTITYLINKER="trained_entity_linker"
REPO="entity_linking_2022_usabilitystudy"

dataset_exists() {
    # Check if the file exists in Downloads as a csv or gz
    if [[ -f "$HOME/Downloads/$DATASET" || -f "$HOME/Downloads/$DATASET.gz" ]]; then
        # If it exists as a csv then gzip
        if [ -f "$HOME/Downloads/$DATASET" ]; then
            echo "File '$DATASET' exists. Compressing it now..."
            gzip "$DATASET"
            echo "File '$DATASET' has been compressed to '$DATASET.gz'."
        fi
        sudo mv $HOME/Downloads/$DATASET.gz ~/   
        echo "File '$DATASET' has been moved to your home directory."
        return 0
    else
        # Check if file is already in home directory
        if [ -f "$DATASET.gz" ]; then
            return 0
        fi
        return 1
    fi
}

entitylinker_exists() {
    # Check to see if trained_entity_linker is already in correct place
    if [ -d "$REPO/models/$ENTITYLINKER" ]; then
        echo "trained_entity_linker already located within entity_linking_2022_usabilitystudy/models"
        return 0
    else
        #Check downloads folder for trained_entity_linker
        if [[ -d "$HOME/Downloads/$ENTITYLINKER" || -f "$HOME/Downloads/$ENTITYLINKER.zip" ]]; then
            # If it's a zip, then unzip
            if [ -d "$HOME/Downloads/$ENTITYLINKER.zip" ]; then
                echo "Folder '$ENTITYLINKER.zip' exists. Unzipping it now..."
                unzip "$ENTITYLINKER.zip"
                echo "Folder '$ENTITYLINKER.zip' has been unzipped to '$ENTITYLINKER'."
            fi
            # Move into home directory
            echo "Folder '$ENTITYLINKER' exists. Moving it now..."
            sudo mv $HOME/Downloads/$ENTITYLINKER $HOME/    
            # Check to see if a models folder already exists
            if [ ! -d "$HOME/$REPO/models" ]; then
                # if not, make and move
                echo "No models folder in $REPO. Creating models folder..."
                mkdir "$HOME/$REPO/models"
            fi
            mv "$HOME/$ENTITYLINKER" "$HOME/$REPO/models"
            if [ $? -eq 0 ]; then
                echo "File '$ENTITYLINKER' has been successfully moved to the models folder in $REPO."
                return 0
            else
                echo "Error: Could not move '$ENTITYLINKER' into $REPO/models."
                return 1
            fi
        else
            echo "Cannot find trained_entity_linker. Make sure after downloading from Figshare it is located in your Downloads folder!"
            return 1
        fi
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
        "openpyxl"  # Added openpyxl
    )

    # Define an array of corresponding versions
    versions=(
        "3.2.4"
        "1.26.2"
        "2.1.1"
        "3.0.9"  # Added openpyxl version
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

    echo "*** Now running 01_combine_text_asr_ocr.R... ***"
    Rscript facebook/inference/01_combine_text_asr_ocr.R
    # If first script runs successfully, continue
    if [ $? -eq 0 ]; then    
        echo "*** 01_combine_text_asr_ocr.R ran successfully! ***"
        echo "*** Now running 02_entity_linking_inference.py... ***"
        python3 facebook/inference/02_entity_linking_inference.py
        # If second script runs successfully, continue
        if [ $? -eq 0 ]; then 
            echo "*** 02_entity_linking_inference.py ran successfully! ***"
            echo "*** Now running 03_combine_results.R... ***"
            Rscript facebook/inference/03_combine_results.R
            # If third script runs successfully, done!
            if [ $? -eq 0 ]; then 
                echo "*** 03_combine_results.R ran successfully! ***"
            else
                exit
            fi
        else
            exit
        fi
    else
        exit
    fi

}

#Confirm we're in home directory
cd $HOME

# Check if Python 3.10 is installed
if check_python_version && check_r_version; then
    
    if dataset_exists && entitylinker_exists; then
        echo "Files '$DATASET' and '$ENTITYLINKER' exist!"

        setup_venv
        install_python_packages
        install_r_packages

        echo "Making $REPO current directory..."
        cd $REPO

        run_inference_scripts

    else
        if ! dataset_exists; then
            echo "File '$DATASET' does not exist."
        fi
        if ! entitylinker_exists; then
            echo "File '$ENTITYLINKER' does not exist."
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

