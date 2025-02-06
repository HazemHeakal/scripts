# Define the path to your text file
$csvFilePath = "C:\Users\Hazem Heakal\Desktop\SoftwareList.csv"

# Define a directory to store downloaded installers
$downloadDirectory = "C:\Users\Hazem Heakal\Downloads\Softwares"
if (-not (Test-Path -Path $downloadDirectory)) {
    New-Item -ItemType Directory -Path $downloadDirectory
}

# Function to download and install a software package
function Install-SoftwareFromUrl {
    param (
        [string]$softwareName,
        [string]$url
    )

    $installerPath = Join-Path $downloadDirectory (Split-Path -Leaf $url)

    # Download the installer
    Write-Host "Downloading $softwareName..."
    Invoke-WebRequest -Uri $url -OutFile $installerPath

    # Install the software
    Write-Host "Installing $softwareName..."
    # Update this line based on the installer type and required arguments
    Start-Process $installerPath -ArgumentList "/quiet /norestart" -Wait

    Write-Host "$softwareName installation completed."
}

# Read the CSV file and process each row
Import-Csv $csvFilePath | ForEach-Object {
    $softwareName = $_."Name"   # Update if your column name is different
    $url = $_."URL"             # Update if your column name is different

    Install-SoftwareFromUrl -softwareName $softwareName -url $url
}

Write-Host "All software installations are completed."
