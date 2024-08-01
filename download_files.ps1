$figshare_urls = @(
    "https://figshare.wesleyan.edu/ndownloader/files/46512400"
)

function Download-Files {
    foreach ($url in $figshare_urls) {
        # Set the desired output filename
        $output_file = "trained_entity_linker.zip"

        # Check if the file already exists
        if (Test-Path $output_file) {
            Write-Output "File '$output_file' already exists."
        } else {
            Invoke-WebRequest -Uri $url -OutFile $output_file
            Write-Output "Downloaded '$output_file'."
        }
    }
}

Download-Files
