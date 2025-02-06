param (
    [string]$ImportDirectory = "$([Environment]::GetFolderPath('Desktop'))\ScheduledTasksExport",
    [string]$UserId = "dmsvc",
    [string]$Password = "xY4S6M9$"
)

# Check if Import Directory Exists
if (!(Test-Path -Path $ImportDirectory)) {
    Write-Host "Import directory does not exist: $ImportDirectory"
    exit 1
}

# Import all XML files as scheduled tasks with specified UserId and Password
Get-ChildItem -Path $ImportDirectory -Filter *.xml | ForEach-Object {
    $taskFile = $_.FullName
    $taskName = [System.IO.Path]::GetFileNameWithoutExtension($taskFile)

    # Import the scheduled task using the dmsvc account and provided password
    try {
        schtasks /create /tn "$taskName" /xml $taskFile /ru $UserId /rp $Password /f
        Write-Host "Imported: $taskName as $UserId"
    }
    catch {
        Write-Host "ERROR: Could not import task $taskName - $_"
    }
}

Write-Host "Scheduled tasks have been imported from $ImportDirectory under the account $UserId"
