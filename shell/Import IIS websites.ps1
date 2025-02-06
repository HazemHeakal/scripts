# Define log file path
$logFilePath = "C:\ScriptLog.txt"

# Start transcript to log output
Start-Transcript -Path $logFilePath

# Array of website configurations
$websites = @(
    @{
        websiteName = "mobilem8api57_bkdkw"
        physicalPath = "C:\inetpub\mobilem8api57_bkdkw"
        bindingInfo = "*:57:"
        appPoolName = "mobilem8api57_bkdkw"
        hostHeader = ""
        port = 57
    },
    @{
        websiteName = "mobilem8api84_raau"
        physicalPath = "C:\inetpub\mobilem8api84_raau"
        bindingInfo = "*:84:"
        appPoolName = "mobilem8api84_raau"
        hostHeader = ""
        port = 84
    },
	    @{
        websiteName = "mobilem8api81_pggt"
        physicalPath = "C:\inetpub\mobilem8api81_pggt"
        bindingInfo = "*:81:"
        appPoolName = "mobilem8api81_pggt"
        hostHeader = ""
        port = 81
    }
)

# Check if IIS is installed by looking for appcmd.exe
$appcmdPath = "C:\Windows\System32\inetsrv\appcmd.exe"
if (-not (Test-Path $appcmdPath)) {
    Write-Host "IIS is not installed or appcmd.exe could not be found."
    exit
}

# Loop through each website configuration
foreach ($website in $websites) {
    $websiteName = $website.websiteName
    $physicalPath = $website.physicalPath
    $appPoolName = $website.appPoolName
    $hostHeader = $website.hostHeader
    $port = $website.port

    # Check if the physical path exists in inetpub
    if (-not (Test-Path $physicalPath)) {
        Write-Host "Physical path $physicalPath does not exist. Skipping creation for $websiteName."
        continue
    }

    # Create the application pool if it doesn't exist
    $appPoolExists = & $appcmdPath list apppool /name:$appPoolName
    if (-not $appPoolExists) {
        Write-Host "Creating application pool: $appPoolName..."
        & $appcmdPath add apppool /name:$appPoolName
    } else {
        Write-Host "Application pool $appPoolName already exists."
    }

    # Create or update the website
    $siteExists = & $appcmdPath list site /name:$websiteName
    if (-not $siteExists) {
        Write-Host "Creating website: $websiteName..."
        & $appcmdPath add site /name:$websiteName /bindings:"http/*:${port}:${hostHeader}" /physicalPath:$physicalPath
        & $appcmdPath set app "$websiteName/" /applicationPool:$appPoolName
        Write-Host "Website $websiteName created and assigned to application pool $appPoolName."
    } else {
        Write-Host "Website $websiteName already exists. Updating settings..."
        & $appcmdPath set site /site.name:$websiteName /bindings:"http/*:${port}:${hostHeader}"
        & $appcmdPath set apppool /apppool.name:$appPoolName
        Write-Host "Website $websiteName updated."
    }
}

# Stop transcript to end logging
Stop-Transcript

# Remove the script log if it exists
if (Test-Path $logFilePath) {
    Remove-Item -Path $logFilePath
}