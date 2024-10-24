$DATASETS = "datasets"
$FBTEXT = "fb_2022_adid_text.csv"
$FBVAR1 = "fb_2022_adid_var1.csv"
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

function Dataset-Exists {
    param (
        [string]$param1
    )

    # Check if the file exists in Downloads as a csv or gz
    $csvFile = Join-Path $HOME "Downloads\$param1"
    $gzFile = Join-Path $HOME "Downloads\$param1.gz"

    if (Test-Path $csvFile -or Test-Path $gzFile) {
        if (Test-Path $csvFile) {
            Write-Host "File '$param1' exists. Compressing it now..."
            Compress-Archive -Path $csvFile -DestinationPath "$csvFile.gz"
            Write-Host "File '$param1' has been compressed to '$param1.gz'."
        }

        Move-Item $gzFile $HOME
        Write-Host "File '$param1.gz' has been moved to your home directory."
        return $true
    } elseif (Test-Path "$HOME\$param1.gz") {
        return $true
    }

    return $false
}

function Setup-Venv {
    $VENV_DIR = "venv"

    # Check if the virtual environment already exists
    if (Test-Path -Path $VENV_DIR -PathType Container) {
        Write-Host "Virtual environment '$VENV_DIR' already exists. Skipping creation."
    } else {
        Write-Host "Creating Python 3.10 virtual environment..."
        python3.10 -m venv $VENV_DIR

        Write-Host "Virtual environment '$VENV_DIR' created successfully."
    }
    Write-Host "Starting virtual environment venv..."
    . "$VENV_DIR\Scripts\Activate.ps1"
}

function Check-Python-Version {
    # Check if Python 3.10 is installed
    $PYTHON_VERSION = & python3.10 --version 2>$null

    if ($PYTHON_VERSION -like "*Python 3.10*") {
        Write-Host "Python 3.10 is installed: $PYTHON_VERSION"
        return $true
    } else {
        return $false
    }
}

function Check-R-Version {
    # Check if R is installed
    if (Get-Command "R" -ErrorAction SilentlyContinue) {
        $R_VERSION = (& R --version | Select-String -Pattern "[0-9]+\.[0-9]+\.[0-9]+" | ForEach-Object { $_.Matches[0].Value })
        Write-Host "R is installed. Version: $R_VERSION"
        return $true
    } else {
        Write-Host "R is not installed."
        return $false
    }
}

function Install-Python-Packages {
    Write-Host "*** Installing necessary Python packages... ***"

    $packages = @(
        @{ Name = "spacy"; Version = "3.2.4" },
        @{ Name = "numpy"; Version = "1.26.2" },
        @{ Name = "pandas"; Version = "2.1.1" }
    )

    foreach ($package in $packages) {
        $name = $package.Name
        $version = $package.Version

        if (pip show $name) {
            $installedVersion = (pip show $name | Select-String "Version:" | ForEach-Object { $_.ToString().Split()[1] })

            if ($installedVersion -eq $version) {
                Write-Host "$name (version $version) is already installed. Skipping."
            } else {
                Write-Host "$name is installed, but not the correct version ($installedVersion). Installing version $version..."
                pip install "$name==$version"
            }
        } else {
            Write-Host "Installing $name (version $version)..."
            pip install "$name==$version"
        }
    }

    Write-Host "*** All Python packages installed successfully. ***"

    Write-Host "*** Downloading spaCy's large English model if not present... ***"
    if (-not (python -m spacy validate | Select-String "en_core_web_lg")) {
        python -m spacy download en_core_web_lg
    } else {
        Write-Host "spaCy's large English model already installed. Skipping."
    }

    Write-Host "*** All installations and checks completed successfully. ***"
}

function Install-R-Packages {
    Write-Host "*** Installing necessary R packages using the command line... ***"

    $packages = @("dplyr", "data.table", "stringr", "tidyr", "R.utils")

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

function Run-Inference-Scripts {
    Write-Host "*** Now running 01_create_EL_training_data.R... ***"
    & Rscript "facebook/train/01_create_EL_training_data.R"

    if ($LASTEXITCODE -eq 0) {
        Write-Host "*** 01_create_EL_training_data.R ran successfully! ***"
        Write-Host "*** Now running 02_train_entity_linking.py... ***"
        & python3 "facebook/train/02_train_entity_linking.py"

        if ($LASTEXITCODE -eq 0) {
            Write-Host "*** 02_train_entity_linking.py ran successfully! ***"
        } else {
            exit
        }
    } else {
        exit
    }
}

# Main Execution
Set-Location $HOME

if (Check-Python-Version -and Check-R-Version) {
    if (-not (Repo-Exists $DATASETS)) {
        git clone https://github.com/Wesleyan-Media-Project/datasets.git
    }

    if (Dataset-Exists $FBTEXT -and Dataset-Exists $FBVAR1) {
        Write-Host "Files '$FBTEXT' and '$FBVAR1' exist!"
        
        Setup-Venv
        Install-Python-Packages
        Install-R-Packages

        Write-Host "*** Moving into '$ENTITY' directory... ***"
        Set-Location $ENTITY

        Run-Inference-Scripts
    } else {
        if (-not (Dataset-Exists $FBTEXT)) {
            Write-Host "File '$FBTEXT' does not exist in the home directory. Please download from Figshare."
        }
        if (-not (Dataset-Exists $FBVAR1)) {
            Write-Host "File '$FBVAR1' does not exist in the home directory. Please download from Figshare."
        }
    }
} else {
    if (-not (Check-R-Version)) {
        Write-Host "R is not installed. Please install R by downloading and opening this package: https://cran.r-project.org/bin/windows/"
    }
    if (-not (Check-Python-Version)) {
        Write-Host "Python 3.10 is not installed. Install Python 3.10.5 by downloading and opening this package: https://www.python.org/ftp/python/3.10.5/python-3.10.5-amd64.exe. Make sure to add Python 3.10.5 to your PATH during installation!"
    }
}
