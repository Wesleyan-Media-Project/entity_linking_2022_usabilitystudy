# Define variables
$DATASETS = "datasets"
$SCRAPER = "face_url_scraper_2022"
$ENTITY = "entity_linking_2022_usabilitystudy"

# Function to check if the repository exists
function repo_exists {
    param (
        [string]$param1
    )

    # Check if the directory exists
    if (Test-Path $param1) {
        Write-Host "Folder '$param1' already exists."
        return $true
    } else {
        return $false
    }
}

# Function to install necessary R packages
function install_r_packages {
    Write-Host
    Write-Host "*** Installing necessary R packages using the command line... ***"
    Write-Host

    $packages = @('dplyr', 'haven', 'data.table', 'stringr', 'quanteda', 'readxl', 'tidyr', 'R.utils')

    foreach ($package in $packages) {
        Rscript -e "install.packages('$package', repos='http://cran.rstudio.com/')"
    }

    Write-Host
    Write-Host "*** All R installations completed successfully. ***"
}

## Main Execution

# Confirm we're in home directory
Set-Location -Path $HOME

# Makes entity_linking_2022_usabilitystudy repo current directory
Write-Host
Write-Host "*** Moving into '$ENTITY' directory... ***"
Write-Host
Set-Location $ENTITY

# Clones datasets repo into parent directory if it doesn't already exist there
if (-not (repo_exists "../$DATASETS")) {
    git clone https://github.com/Wesleyan-Media-Project/datasets.git "../$DATASETS"
}

# Clones face_url_scraper_2022 into parent directory if it doesn't already exist there
if (-not (repo_exists "../$SCRAPER")) {
    git clone https://github.com/Wesleyan-Media-Project/face_url_scraper_2022.git "../$SCRAPER"
}

# Install necessary R packages via command line
install_r_packages

# Runs the R script
Write-Host
Write-Host "*** Running facebook/knowledge_base/01_construct_kb.R... ***"
Rscript "facebook/knowledge_base/01_construct_kb.R"

# Checks whether the script ran successfully
if ($LASTEXITCODE -eq 0) {
    Write-Host
    Write-Host "*** 01_construct_kb.R ran successfully! ***"
}
