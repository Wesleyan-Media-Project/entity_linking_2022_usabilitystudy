# Define constants
$DATASET = "fb_2022_adid_text.csv"
$ENTITYLINKER = "trained_entity_linker"
$REPO = "entity_linking_2022_usabilitystudy"

function dataset_exists {
    # Check if the file exists in the Downloads directory
    if (Test-Path -Path "$HOME\Downloads\$DATASET" -or Test-Path -Path "$HOME\Downloads\$DATASET.gz") {
        if (Test-Path -Path "$HOME\Downloads\$DATASET") {
            Write-Host "File '$DATASET' exists. Compressing it now..."
            Compress-Archive -Path "$HOME\Downloads\$DATASET" -DestinationPath "$HOME\Downloads\$DATASET.zip"
            Write-Host "File '$DATASET' has been compressed to '$DATASET.zip'."
        }
        Move-Item -Path "$HOME\Downloads\$DATASET.gz" -Destination "$HOME" -Force
        Write-Host "File '$DATASET' has been moved to your home directory."
        return $true
    } elseif (Test-Path -Path "$HOME\Downloads\$DATASET.gz") {
        return $true
    } else {
        return $false
    }
}

function entitylinker_exists {
    # Check if the directory exists in the Downloads directory
    if (Test-Path -Path "$HOME\Downloads\$ENTITYLINKER" -or Test-Path -Path "$HOME\Downloads\$ENTITYLINKER.zip") {
        if (Test-Path -Path "$HOME\Downloads\$ENTITYLINKER.zip") {
            Write-Host "Folder '$ENTITYLINKER.zip' exists. Unzipping it now..."
            Expand-Archive -Path "$HOME\Downloads\$ENTITYLINKER.zip" -DestinationPath "$HOME\Downloads\$ENTITYLINKER"
            Write-Host "Folder '$ENTITYLINKER.zip' has been unzipped to '$ENTITYLINKER'."
        }
        Write-Host "Folder '$ENTITYLINKER' exists. Moving it now..."
        New-Item -ItemType Directory -Path "models" -Force | Out-Null
        Move-Item -Path "$HOME\Downloads\$ENTITYLINKER" -Destination "$HOME" -Force
        Move-Item -Path "$HOME\$ENTITYLINKER" -Destination "$REPO\models" -Force
        Write-Host "File '$ENTITYLINKER' has been moved to a models folder in the $REPO directory."
        return $true
    } elseif (Test-Path -Path "$HOME\$REPO\models\$ENTITYLINKER") {
        return $true
    } else {
        return $false
    }
}

function check_python_version {
    # Get the Python 3.10 version if installed
    $PYTHON_VERSION = & python3.10 --version 2>$null
    if ($PYTHON_VERSION -match "Python 3.10") {
        Write-Host "Python 3.10 is installed: $PYTHON_VERSION"
        return $true
    } else {
        return $false
    }
}

function check_r_version {
    # Check if R is installed
    if (Get-Command R -ErrorAction SilentlyContinue) {
        $R_VERSION = & R --version | Select-String -Pattern "[0-9]*\.[0-9]*\.[0-9]*"
        Write-Host "R is installed. Version: $R_VERSION"
        return $true
    } else {
        Write-Host "R is not installed."
        return $false
    }
}

function run_inference_scripts {
    Write-Host "*** Now running 01_combine_text_asr_ocr.R... ***"
    & Rscript facebook/inference/01_combine_text_asr_ocr.R
    if ($LASTEXITCODE -eq 0) {
        Write-Host "*** 01_combine_text_asr_ocr.R ran successfully! ***"
        Write-Host "*** Now running 02_entity_linking_inference.py... ***"
        & python3 facebook/inference/02_entity_linking_inference.py
        if ($LASTEXITCODE -eq 0) {
            Write-Host "*** 02_entity_linking_inference.py ran successfully! ***"
            Write-Host "*** Now running 03_combine_results.R... ***"
            & Rscript facebook/inference/03_combine_results.R
            if ($LASTEXITCODE -eq 0) {
                Write-Host "*** 03_combine_results.R ran successfully! ***"
            } else {
                exit
            }
        } else {
            exit
        }
    } else {
        exit
    }
}

function setup_venv {
    Write-Host "Creating Python 3.10 virtual environment..."
    python3.10 -m venv venv
    Write-Host "Starting virtual environment venv..."
    & .\venv\Scripts\Activate.ps1
}

function install_python_packages {
    Write-Host "Installing spaCy version 3.2.4..."
    pip install spacy==3.2.4

    Write-Host "Installing numpy version 1.26.2..."
    pip install numpy==1.26.2

    Write-Host "Downloading spaCy's large English model..."
    & python3.10 -m spacy download en_core_web_lg

    Write-Host "Installing pandas version 2.1.1..."
    pip install pandas==2.1.1

    Write-Host "All python installations completed successfully."
}

function install_r_packages {
    Write-Host "Installing necessary R packages using the command line..."
    
    # Define an array of packages to install
    $packages = @("dplyr", "data.table", "stringr", "tidyr", "R.utils")

    # Loop through the array and install each package
    foreach ($package in $packages) {
        & Rscript -e "install.packages('$package', repos='http://cran.rstudio.com/')"
    }

    Write-Host "All R installations completed successfully."
}

# Confirm we're in home directory
Set-Location -Path $HOME

# Check if Python 3.10 and R are installed
if (check_python_version -and check_r_version) {
    if (dataset_exists -and entitylinker_exists) {
        Write-Host "Files '$DATASET' and '$ENTITYLINKER' exist!"

        setup_venv
        install_python_packages
        install_r_packages

        Write-Host "Making $REPO current directory..."
        Set-Location -Path $REPO

        run_inference_scripts

    } else {
        if (-not (dataset_exists)) {
            Write-Host "File '$DATASET' does not exist."
        }
        if (-not (entitylinker_exists)) {
            Write-Host "File '$ENTITYLINKER' does not exist."
        }
    }
} else {
    if (-not (check_r_version)) {
        Write-Host "R is not installed."
        Write-Host "Please install R by downloading and opening this package (macOS): https://cran.r-project.org/bin/macosx/"
    }
    if (-not (check_python_version)) {
        Write-Host "Python 3.10 is not installed."
        Write-Host "Please install Python 3.10.5 by downloading and opening this package (macOS): https://www.python.org/ftp/python/3.10.5/python-3.10.5-macos11.pkg. Make sure to add Python 3.10.5 to your PATH during installation!"
    }
}
