$DATASET = "fb_2022_adid_text.csv"
$ENTITYLINKER = "trained_entity_linker"
$REPO = "entity_linking_2022_usabilitystudy"

function DatasetExists {
    $datasetPath = "$HOME\Downloads\$DATASET"
    $datasetGzPath = "$HOME\Downloads\$DATASET.gz"

    if (Test-Path $datasetPath -or Test-Path $datasetGzPath) {
        if (Test-Path $datasetPath) {
            Write-Host "File '$DATASET' exists. Compressing it now..."
            Compress-Archive -Path $datasetPath -DestinationPath "$datasetPath.gz"
            Write-Host "File '$DATASET' has been compressed to '$DATASET.gz'."
        }
        Move-Item -Path $datasetGzPath -Destination $HOME -Force
        Write-Host "File '$DATASET' has been moved to your home directory."
        return $true
    } elseif (Test-Path "$HOME\$DATASET.gz") {
        return $true
    } else {
        return $false
    }
}

function EntityLinkerExists {
    $entityLinkerPath = "$HOME\Downloads\$ENTITYLINKER"
    $entityLinkerZipPath = "$HOME\Downloads\$ENTITYLINKER.zip"

    if (Test-Path $entityLinkerPath -or Test-Path $entityLinkerZipPath) {
        if (Test-Path $entityLinkerZipPath) {
            Write-Host "Folder '$ENTITYLINKER.zip' exists. Unzipping it now..."
            Expand-Archive -Path $entityLinkerZipPath -DestinationPath "$HOME\Downloads"
            Write-Host "Folder '$ENTITYLINKER.zip' has been unzipped to '$ENTITYLINKER'."
        }
        Write-Host "Folder '$ENTITYLINKER' exists. Moving it now..."
        New-Item -ItemType Directory -Path "$REPO\models" -Force
        Move-Item -Path $entityLinkerPath -Destination "$HOME\models" -Force
        Move-Item -Path "$HOME\models" -Destination $REPO -Force
        Write-Host "File '$ENTITYLINKER' has been moved to a models folder in the $REPO directory."
        return $true
    } elseif (Test-Path "$REPO\models\$ENTITYLINKER") {
        return $true
    } else {
        return $false
    }
}

function CheckPythonVersion {
    $pythonVersion = python3.10 --version 2>$null
    if ($pythonVersion -match "Python 3.10") {
        Write-Host "Python 3.10 is installed: $pythonVersion"
        return $true
    } else {
        return $false
    }
}

function CheckRVersion {
    $rVersion = & R --version 2>$null
    if ($rVersion) {
        $rVersionNum = $rVersion | Select-String -Pattern "[0-9]+\.[0-9]+\.[0-9]+" | ForEach-Object { $_.Matches[0].Value }
        Write-Host "R is installed. Version: $rVersionNum"
        return $true
    } else {
        Write-Host "R is not installed."
        return $false
    }
}

function RunInferenceScripts {
    Write-Host "*** Now running 01_combine_text_asr_ocr.R... ***"
    if (& Rscript facebook/inference/01_combine_text_asr_ocr.R) {
        Write-Host "*** 01_combine_text_asr_ocr.R ran successfully! ***"
        Write-Host "*** Now running 02_entity_linking_inference.py... ***"
        if (& python3 facebook/inference/02_entity_linking_inference.py) {
            Write-Host "*** 02_entity_linking_inference.py ran successfully! ***"
            Write-Host "*** Now running 03_combine_results.R... ***"
            if (& Rscript facebook/inference/03_combine_results.R) {
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

function InstallPythonPackages {
    Write-Host "*** Installing necessary Python packages... ***"
    $packages = @("spacy", "numpy", "pandas")
    $versions = @("3.2.4", "1.26.2", "2.1.1")

    for ($i = 0; $i -lt $packages.Length; $i++) {
        $package = $packages[$i]
        $version = $versions[$i]
        if (pip show $package) {
            $installedVersion = pip show $package | Select-String "Version:" | ForEach-Object { $_.ToString().Split()[1] }
            if ($installedVersion -eq $version) {
                Write-Host "$package (version $version) is already installed. Skipping."
            } else {
                Write-Host "$package is installed, but not the correct version ($installedVersion). Installing version $version..."
                pip install "$package==$version"
            }
        } else {
            Write-Host "Installing $package (version $version)..."
            pip install "$package==$version"
        }
    }

    Write-Host "*** All Python packages installed successfully. ***"
    Write-Host "*** Downloading spaCy's large English model if not present... ***"
    if (python -m spacy validate | Select-String "en_core_web_lg") {
        Write-Host "spaCy's large English model already installed. Skipping."
    } else {
        python -m spacy download en_core_web_lg
    }
    Write-Host "*** All installations and checks completed successfully. ***"
}

function InstallRPackages {
    Write-Host "*** Installing necessary R packages using the command line... ***"
    $packages = @("dplyr", "data.table", "stringr", "tidyr", "R.utils")
    foreach ($package in $packages) {
        & Rscript -e "if (!require('$package', quietly = TRUE)) { install.packages('$package', repos='http://cran.rstudio.com/') } else { cat('$package is already installed.\n') }"
    }
    Write-Host "*** All necessary R packages are installed. ***"
}

cd $HOME

if (CheckPythonVersion -and CheckRVersion) {
    if (DatasetExists -and EntityLinkerExists) {
        Write-Host "Files '$DATASET' and '$ENTITYLINKER' exist!"

        SetupVenv
        InstallPythonPackages
        InstallRPackages

        Write-Host "Making $REPO current directory..."
        cd $REPO

        RunInferenceScripts
    } else {
        if (-not (DatasetExists)) {
            Write-Host "File '$DATASET' does not exist."
        }
        if (-not (EntityLinkerExists)) {
            Write-Host "File '$ENTITYLINKER' does not exist."
        }
    }
} else {
    if (-not (CheckRVersion)) {
        Write-Host "R is not installed."
        Write-Host "Please install R by downloading and opening this package: https://cran.r-project.org/bin/windows/"
    }
    if (-not (CheckPythonVersion)) {
        Write-Host "Python 3.10 is not installed."
        Write-Host "Please install Python 3.10.5 by downloading and opening this package: https://www.python.org/ftp/python/3.10.5/python-3.10.5-amd64.exe. Make sure to add Python 3.10.5 to your PATH during installation!"
    }
}
