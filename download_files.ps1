# $figshare_urls = @(
#     "https://figshare.wesleyan.edu/ndownloader/files/46512400"
# )

# function Download-Files {
#     foreach ($url in $figshare_urls) {
#         # Set the desired output filename
#         $output_file = "trained_entity_linker.zip"

#         # Check if the file already exists
#         if (Test-Path $output_file) {
#             Write-Output "File '$output_file' already exists."
#         } else {
#             Invoke-WebRequest -Uri $url -OutFile $output_file
#             Write-Output "Downloaded '$output_file'."
#         }
#     }
# }

# Download-Files

# URLs for the files
$model_url = "https://figshare.wesleyan.edu/ndownloader/files/46512400"
$data_urls = @(
    "https://figshare.wesleyan.edu/ndownloader/files/47298157",
    "https://figshare.wesleyan.edu/ndownloader/files/47298214"
)

# Filenames for the downloaded files
$model_file = "trained_entity_linker.zip"
$data_files = @("fb_2022_adid_text.csv.gz", "g2022_adid_01062021_11082022_text.csv.gz")

# Function to download files
function Download-File {
    param (
        [string]$url,
        [string]$output_file
    )

    if (Test-Path $output_file) {
        Write-Host "File '$output_file' already exists."
    } else {
        Invoke-WebRequest -Uri $url -OutFile $output_file
        Write-Host "Downloaded '$output_file'."
    }
}

# Function to display help
function Show-Help {
    Write-Host "Usage: .\download_files.ps1 {-model|-data|-all|-help}"
    Write-Host
    Write-Host "Options:"
    Write-Host "  -model    Download the model file only."
    Write-Host "  -data     Download the two data files only."
    Write-Host "  -all      Download both the model and data files."
    Write-Host "  -help     Display this help message."
}

# Process input arguments
param (
    [string]$option
)

switch ($option) {
    "-model" {
        Write-Host "Downloading model..."
        Download-File -url $model_url -output_file $model_file
    }
    "-data" {
        Write-Host "Downloading data files..."
        for ($i = 0; $i -lt $data_urls.Count; $i++) {
            Download-File -url $data_urls[$i] -output_file $data_files[$i]
        }
    }
    "-all" {
        Write-Host "Downloading model and data files..."
        Download-File -url $model_url -output_file $model_file
        for ($i = 0; $i -lt $data_urls.Count; $i++) {
            Download-File -url $data_urls[$i] -output_file $data_files[$i]
        }
    }
    "-help" {
        Show-Help
    }
    Default {
        Write-Host "Invalid option. Use -help for usage information."
        exit 1
    }
}
