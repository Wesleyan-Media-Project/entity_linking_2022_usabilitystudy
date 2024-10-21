# Variables
$DATASETS = "datasets"
$FBTEXT = "fb_2022_adid_text.csv"
$FBVAR1 = "fb_2022_adid_var1.csv"
$ENTITY = "entity_linking_2022_usabilitystudy"

function repo_exists($param1) {
    # Check if the directory exists
    if (Test-Path -Path $param1 -PathType Container) {
        Write-Host "Folder '$param1' already exists."
        return $true
    } else {
        return $false
    }
}

function dataset_exists($param1) {
    $downloadsPath = "$HOME\Downloads"
    # Check if the file exists
    if (Test-Path -Path "$downloadsPath\$param1" -PathType Leaf) {
        Write-Host "File '$param1' exists. Compressing it now..."
        # Compress the file
        Compress-Archive -Path "$downloadsPath\$param1" -DestinationPath "$downloadsPath\$param1.zip"
        Write-Host "File '$param1' has been compressed to '$param1.zip'."
        return $true
    } elseif (Test-Path -Path "$downloadsPath\$param1.zip") {
        return $true
    } else {
        return $false
    }
}

function setup_venv {
    Write-Host "Creating Python 3.10 virtual environment..."
    python -m venv venv
    Write-Host "Starting virtual environment venv..."
    .\venv\Scripts\Activate.ps1
}

function install_python_packages {
    Write-Host "Installing spaCy version 3.2.4..."
    pip install spacy==3.2.4

    Write-Host "Installing numpy version 1.26.2..."
    pip install numpy==1.26.2

    Write-Host "Downloading spaCy's large English model..."
    python -m spacy download en_core_web_lg

    Write-Host "Installing pandas version 2.1.1..."
    pip install pandas==2.1.1

    Write-Host "All Python installations completed successfully."
}

function install_r_packages {
    Write-Host "Installing necessary R packages using the command line..."

    # Define an array of packages to install
    $packages = @("dplyr", "data.table", "stringr", "tidyr", "R.utils")

    # Loop through the array and install each package
    foreach ($package in $packages) {
        Rscript -e "install.packages('$package', repos='http://cran.rstudio.com/')"
    }

    Write-Host "All R installations completed successfully."
}

function run_inference_scripts {
    Write-Host "*** Now running 01_create_EL_training_data.R... ***"
    Rscript facebook/train/01_create_EL_training_data.R
    if ($LASTEXITCODE -eq 0) {
        Write-Host "*** 01_create_EL_training_data.R ran successfully! ***"
        Write-Host "*** Now running 02_train_entity_linking.py... ***"

        python facebook/train/02_train_entity_linking.py
        if ($LASTEXITCODE -eq 0) {
            Write-Host "*** 02_train_entity_linking.py ran successfully! ***"
        } else {
            exit
        }
    } else {
        exit
    }
}

function remove_venv {
    Remove-Item -Recurse -Force "venv"
    Write-Host "Deleted virtual environment"
}

# Main Execution

# Clones datasets repo into parent directory if it doesn't already exist there
if (-not (repo_exists $DATASETS)) {
    git clone https://github.com/Wesleyan-Media-Project/datasets.git
}

if (dataset_exists $FBTEXT -and dataset_exists $FBVAR1) {
    Write-Host "Files '$FBTEXT' and '$FBVAR1' exist in the home directory!"
    Write-Host

    # Sets up virtual environment, installs all necessary packages
    setup_venv
    install_python_packages
    install_r_packages

    # Makes entity_linking_2022_usabilitystudy repo current directory
    Write-Host
    Write-Host "*** Moving into '$ENTITY' directory... ***"
    Write-Host
    Set-Location $ENTITY

    # Attempts to run scripts
    run_inference_scripts

    # Deletes virtual environment at the end of process
    remove_venv

} else {
    if (-not (dataset_exists $FBTEXT)) {
        Write-Host "File '$FBTEXT' does not exist in the home directory."
        Write-Host "Please download from Figshare and move into home directory."
    } else {
        Write-Host "File '$FBTEXT' exists in the home directory."
    }
    if (-not (dataset_exists $FBVAR1)) {
        Write-Host "File '$FBVAR1' does not exist in the home directory."
        Write-Host "Please download from Figshare and move into home directory."
    } else {
        Write-Host "File '$FBVAR1' exists in the home directory."
    }
}
