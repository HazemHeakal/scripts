param (
    [string]$ExportDirectory = "$([Environment]::GetFolderPath('Desktop'))\ScheduledTasksExport"
)

# Check if Export Directory Exists, If not, create it
if (!(Test-Path -Path $ExportDirectory)) {
    New-Item -ItemType Directory -Path $ExportDirectory -Force
}

# Export all non-Microsoft scheduled tasks
$tasks = Get-ScheduledTask | Where-Object { $_.TaskPath -notmatch "Microsoft" }

foreach ($task in $tasks) {
    $taskPath = $task.TaskPath.TrimStart('\')
    $taskName = $task.TaskName

    # If taskPath is empty, use taskName alone
    if ([string]::IsNullOrWhiteSpace($taskPath)) {
        $fullTaskPath = $taskName
    }
    else {
        $fullTaskPath = Join-Path -Path $taskPath -ChildPath $taskName
    }

    $exportPath = Join-Path -Path $ExportDirectory -ChildPath "$($taskName).xml"

    # Export the task as XML
    try {
        schtasks /query /tn "$fullTaskPath" /xml > $exportPath
        Write-Host "Exported: $fullTaskPath"
    }
    catch {
        Write-Host "ERROR: Could not export task $fullTaskPath - $_"
    }
}

Write-Host "Scheduled tasks have been exported to $ExportDirectory"