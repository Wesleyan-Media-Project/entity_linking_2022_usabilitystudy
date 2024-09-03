#!/bin/bash

# URLs for the files
model_url="https://figshare.wesleyan.edu/ndownloader/files/46512400"
data_urls=(
    "https://figshare.wesleyan.edu/ndownloader/files/47298157"
    "https://figshare.wesleyan.edu/ndownloader/files/47298214"
)

# Filenames for the downloaded files
model_file="trained_entity_linker.zip"
data_files=("fb_2022_adid_text.csv.gz" "g2022_adid_01062021_11082022_text.csv.gz")

# Function to download files
download_file() {
    url="$1"
    output_file="$2"

    if [ -f "$output_file" ]; then
        echo "File '$output_file' already exists."
    else
        curl -L -o "$output_file" "$url"
        echo "Downloaded '$output_file'."
    fi
}

# Function to display help
show_help() {
    echo "Usage: $0 {-model|-data|-all|-help}"
    echo
    echo "Options:"
    echo "  -model    Download the model file only."
    echo "  -data     Download the two data files only."
    echo "  -all      Download both the model and data files."
    echo "  -help     Display this help message."
}

# Process input arguments
case "$1" in
    -model)
        echo "Downloading model..."
        download_file "$model_url" "$model_file"
        ;;
    -data)
        echo "Downloading data files..."
        for i in "${!data_urls[@]}"; do
            download_file "${data_urls[$i]}" "${data_files[$i]}"
        done
        ;;
    -all)
        echo "Downloading model and data files..."
        download_file "$model_url" "$model_file"
        for i in "${!data_urls[@]}"; do
            download_file "${data_urls[$i]}" "${data_files[$i]}"
        done
        ;;
    -help)
        show_help
        ;;
    *)
        echo "Invalid option. Use -help for usage information."
        exit 1
        ;;
esac

