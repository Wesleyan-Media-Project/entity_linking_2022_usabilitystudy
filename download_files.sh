#!/bin/bash

figshare_urls=(
   https://figshare.wesleyan.edu/ndownloader/files/46512400
)

download_files() {
   for url in "${figshare_urls[@]}"; do
       # Set the desired output filename
       output_file="trained_entity_linker.zip"

       # Check if the file already exists
       if [ -f "$output_file" ]; then
           echo "File '$output_file' already exists."
       else
           wget -O "$output_file" "$url"
           echo "Downloaded '$output_file'."
       fi
   done
}

download_files