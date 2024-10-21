<#
To run this bash script:

Run the following command:
Get-ExecutionPolicy

If the result is Restricted, run this command (only needs to be done once a session):
Set-ExecutionPolicy RemoteSigned -Scope Process

Then, run:
.\setup_windows.ps1

#>

# Variables
$DATASET = "fb_2022_adid_text.csv"
$DATASET_GZ="fb_2022_adid_text.csv.gz"
$ENTITYLINKER = "trained_entity_linker"
$REPO = "entity_linking_2022"

# Function to check if dataset exists
function Check-Dataset {
    if (Test-Path $DATASET) {
        Write-Host "File '$DATASET' exists. Compressing it now..."
        Compress-Archive -Path $DATASET -DestinationPath "$DATASET_GZ"
        Write-Host "File '$DATASET' has been compressed to '$DATASET_GZ'."
        return $true
    } 
    elseif (Test-Path $DATASET_GZ) {
        Write-Host "File '$DATASET' exists and is already compressed."
        return $true
    }
    else {
        Write-Host "File '$DATASET' does not exist."
        return $false
    }
}

# Function to check if entity linker folder exists
function Check-EntityLinker {
    if (Test-Path $ENTITYLINKER) {
        Write-Host "Folder '$ENTITYLINKER' exists. Moving it now..."
        return $true
    } else {
        Write-Host "Folder '$ENTITYLINKER' does not exist."
        return $false
    }
}

function Check-Repository {
    if (Test-Path "entity_linking_2022") {
        Write-Host "Folder '$REPO' exists. Moving it now..."
        return $true
    } else {
        Write-Host "Folder '$REPO' does not exist."
        return $false
    }
}

# Function to check Python version
function Check-PythonVersion {
    $python_version = python3.10 --version 2>$null
    if ($python_version -like "*3.10*") {
        Write-Host "Python 3.10 is installed: $python_version"
        return $true
    } else {
        Write-Host "Python 3.10 is not installed."
        return $false
    }
}

# Function to check R version
function Check-RVersion {
    $r_version = R --version 2>$null
    if ($r_version) {
        Write-Host "R is installed. Version: $r_version"
        return $true
    } else {
        Write-Host "R is not installed."
        return $false
    }
}

function Remove-Venv {
    if (Test-Path "venv") {
        Remove-Item -Recurse -Force "venv"
        Write-Host "Deleted virtual environment"
    }
}

# Function to run inference scripts
function Run-InferenceScripts {
    & Rscript facebook/inference/01_combine_text_asr_ocr.R
    & python facebook/inference/02_entity_linking_inference.py
    & Rscript facebook/inference/03_combine_results.R
}

# Function to set up virtual environment
function Setup-Venv {
    Write-Host "Creating Python 3.10 virtual environment..."
    python3.10 -m venv venv

    Write-Host "Starting virtual environment 'venv'..."
    & .\venv\Scripts\Activate
}

function Install-PythonPackages {
    Write-Host "Installing spaCy version 3.2.4..."
    pip3 install spacy==3.2.4

    Write-Host "Installing numpy version 1.26.2..."
    pip3 install numpy==1.26.2

    Write-Host "Downloading spaCy's large English model..."
    python3.10 -m spacy download en_core_web_lg

    Write-Host "Installing pandas version 2.1.1..."
    pip3 install pandas==2.1.1

    Write-Host "All python installations completed successfully."
}

function Install-RPackages {
    Write-Host "Installing necessary R packages using the command line..."

    Rscript -e "install.packages('dplyr', repos='http://cran.rstudio.com/')"
    Rscript -e "install.packages('data.table', repos='http://cran.rstudio.com/')"
    Rscript -e "install.packages('stringr', repos='http://cran.rstudio.com/')"
    Rscript -e "install.packages('tidyr', repos='http://cran.rstudio.com/')"
    Rscript -e "install.packages('R.utils', repos='http://cran.rstudio.com/')"

    Write-Host "All R installations completed successfully."
}

# Main Script Execution

if (-not (Check-Repository)) {
    git clone https://github.com/Wesleyan-Media-Project/entity_linking_2022.git
}

if ((Check-PythonVersion) -and (Check-RVersion)) {

    Setup-Venv
    Install-PythonPackages
    Install-RPackages


    if (Check-Dataset) {

        if (Check-EntityLinker) {
            New-Item -ItemType Directory -Path "models" -Force
            Move-Item $ENTITYLINKER "models"
            Move-Item "models" "$REPO"
            Write-Host "Folder '$ENTITYLINKER' has been moved to 'models' folder."

            Set-Location "$REPO"
            Run-InferenceScripts
        } else {
            Remove-Venv
            Remove-Item "$DATASET_GZ"
        }
    } else {
        Remove-Venv
    }
} else {
    if (-not (Check-RVersion)) {
        Write-Host "R is not installed."
        Write-Host "Please install R by downloading and opening this package (Windows): https://cran.r-project.org/bin/windows/"
    }
    if (-not (Check-PythonVersion)) {
        Write-Host "Python 3.10 is not installed."
        Write-Host "Please install Python 3.10.5 by downloading and opening this package (Windows): https://www.python.org/ftp/python/3.10.5/python-3.10.5-amd64.exe.
        Make sure to add Python 3.10.5 to your PATH during installation!"

    }
}
