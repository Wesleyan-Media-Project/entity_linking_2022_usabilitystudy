#!/bin/bash

: '
To run this bash script:

First, run the following command (only needs to be done once):
chmod +x setup.sh 

Then, to run the script run the next command:
./setup.sh

'


DATASET="fb_2022_adid_text_final_092924.csv"
DATASET_GZ="fb_2022_adid_text_final_092924.csv"
ENTITYLINKER="trained_entity_linker"
REPO="entity_linking_2022"

check_dataset() {
    # Check if the file exists in the current directory
    if [ -f "$DATASET" ]; then
        echo "File '$DATASET' exists. Compressing it now..."
        gzip "$DATASET"
        echo "File '$DATASET' has been compressed to '$DATASET_GZ'."
        return 0
    else
        if [ -f "$DATASET_GZ" ]; then
            echo "File '$DATASET_GZ' exists and is already compressed."
            return 0
        else
            return 1
        fi
    fi
}

check_repo() {
    # Check if the file exists in the current directory
    if [ -d "entity_linking_2022" ]; then
        echo "Folder '$REPO' already exists."
        return 1
    else
        return 0
    fi
}

check_entitylinker() {
    # Check if the file exists in the current directory
    if [ -d "$ENTITYLINKER" ]; then
        echo "Folder '$ENTITYLINKER' exists. Moving it now..."
        return 0
    else
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

remove_repo() {
    rm -r "$REPO"
    echo "Deleted $REPO directory"
}

remove_venv() {
    rm -r "venv"
    echo "Deleted virtual environment"    
}

gunzip_dataset() {
    gunzip "$DATASET_GZ"
}

run_inference_scripts() {
    Rscript facebook/inference/01_combine_text_asr_ocr.R
    python3 facebook/inference/02_entity_linking_inference.py
    Rscript facebook/inference/03_combine_results.R
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

    Rscript -e "install.packages('dplyr', repos='http://cran.rstudio.com/')"
    Rscript -e "install.packages('data.table', repos='http://cran.rstudio.com/')"
    Rscript -e "install.packages('stringr', repos='http://cran.rstudio.com/')"
    Rscript -e "install.packages('tidyr', repos='http://cran.rstudio.com/')"
    Rscript -e "install.packages('R.utils', repos='http://cran.rstudio.com/')"

    echo "All R installations completed successfully."
}


if check_repo; then
    git clone https://github.com/Wesleyan-Media-Project/entity_linking_2022.git
fi

# Check if Python 3.10 is installed
if check_python_version && check_r_version; then
    
    # Proceed with installations since Python 3.10 and R are available
    setup_venv
    install_python_packages
    install_r_packages

    if check_dataset; then

        if check_entitylinker; then
            
            mkdir "models"
            mv "$ENTITYLINKER" "models"
            mv "models" "$REPO"
            echo "File '$ENTITYLINKER' has been moved to a models folder in the $REPO directory."

            echo "Making $REPO current directory..."
            cd $REPO

            run_inference_scripts

        else
            echo "File '$ENTITYLINKER' does not exist in the current directory."
            remove_venv # Removes all installs
            gunzip_dataset # Unzips csv so we can re-run cleanly
        fi

    else
        echo "File '$DATASET' does not exist in the current directory."
        remove_venv # Removes all installs
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

