$DATASETS = "datasets"
$SCRAPER = "face_url_scraper_2022"
$ENTITY = "entity_linking_2022_usabilitystudy"

function Repo-Exists {
    param (
        [string]$param1
    )
    
    # Check if the folder exists
    if (Test-Path -Path $param1 -PathType Container) {
        Write-Host "Folder '$param1' already exists."
        return $true
    } else {
        return $false
    }
}

function Check-R-Version {
    # Check if R is installed
    if (Get-Command "R" -ErrorAction SilentlyContinue) {
        $R_Version = (& R --version | Select-String -Pattern "[0-9]+\.[0-9]+\.[0-9]+" | ForEach-Object { $_.Matches[0].Value })
        Write-Host "R is installed. Version: $R_Version"
        return $true
    } else {
        Write-Host "R is not installed."
        return $false
    }
}

function Install-R-Packages {
    Write-Host "*** Installing necessary R packages using the command line... ***"

    # Define an array of packages to install
    $packages = @(
        "dplyr",
        "haven",
        "data.table",
        "stringr",
        "quanteda",
        "readxl",
        "tidyr",
        "R.utils"
    )

    # Loop through the array and check if each package is installed
    foreach ($package in $packages) {
        & Rscript -Command "
            if (!require('$package', quietly = TRUE)) {
                install.packages('$package', repos='http://cran.rstudio.com/')
            } else {
                cat('$package is already installed.\n')
            }
        "
    }

    Write-Host "*** All necessary R packages are installed. ***"
}

# Main Execution

Set-Location $HOME

# Check if R is installed
if (Check-R-Version) {

    # Clone datasets repo into parent directory if it doesn't already exist there
    if (-not (Repo-Exists $DATASETS)) {
        git clone https://github.com/Wesleyan-Media-Project/datasets.git
    }

    # Clone face_url_scraper_2022 into parent directory if it doesn't already exist there
    if (-not (Repo-Exists $SCRAPER)) {
        git clone https://github.com/Wesleyan-Media-Project/face_url_scraper_2022.git
    }

    # Install necessary R packages via command line
    Install-R-Packages

    # Change directory to entity_linking_2022_usabilitystudy repo
    Write-Host "*** Moving into '$ENTITY' directory... ***"
    Set-Location $ENTITY

    # Run the R script
    Write-Host "*** Running facebook/knowledge_base/01_construct_kb.R... ***"
    & Rscript facebook/knowledge_base/01_construct_kb.R

    # Check whether script ran successfully
    if ($LASTEXITCODE -eq 0) {
        Write-Host "*** 01_construct_kb.R ran successfully! ***"
    }

} else {
    Write-Host "R is not installed."
    Write-Host "Please install R by downloading and opening this package: https://cran.r-project.org/bin/windows/"
}