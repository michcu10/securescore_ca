# Cleanup Script for Azure Defender for Cloud Data Export

Write-Host "=== Cleanup Data Export Files ===" -ForegroundColor Green
Write-Host "This script will remove all generated reports and logs.`n" -ForegroundColor White

# Define directories to clean
$directoriesToClean = @(".\Reports", ".\Logs")
$filesToClean = @()

# Find files to clean
foreach ($dir in $directoriesToClean) {
    if (Test-Path $dir) {
        $files = Get-ChildItem -Path $dir -File -Recurse
        if ($files) {
            $filesToClean += $files
            Write-Host "Found $($files.Count) files in $dir" -ForegroundColor Yellow
            foreach ($file in $files) {
                Write-Host "  - $($file.Name) ($([math]::Round($file.Length / 1KB, 2)) KB)" -ForegroundColor White
            }
        } else {
            Write-Host "No files found in $dir" -ForegroundColor Green
        }
    } else {
        Write-Host "Directory $dir does not exist" -ForegroundColor Gray
    }
}

# Also clean any CSV or log files in the root directory (but not .ps1 files!)
$rootFiles = Get-ChildItem -Path "." -File | Where-Object { 
    ($_.Extension -eq ".csv" -or 
     $_.Extension -eq ".log" -or 
     $_.Name -like "*.tmp") -and
    $_.Extension -ne ".ps1"  # Never delete PowerShell scripts!
}

if ($rootFiles) {
    $filesToClean += $rootFiles
    Write-Host "Found $($rootFiles.Count) files in root directory to clean" -ForegroundColor Yellow
    foreach ($file in $rootFiles) {
        Write-Host "  - $($file.Name) ($([math]::Round($file.Length / 1KB, 2)) KB)" -ForegroundColor White
    }
}

Write-Host ""

if ($filesToClean.Count -eq 0) {
    Write-Host "✓ No files need to be cleaned" -ForegroundColor Green
    exit 0
}

# Confirm cleanup
Write-Host "Total files to remove: $($filesToClean.Count)" -ForegroundColor Yellow
$totalSize = ($filesToClean | Measure-Object -Property Length -Sum).Sum
Write-Host "Total size: $([math]::Round($totalSize / 1KB, 2)) KB" -ForegroundColor Yellow

Write-Host ""
$confirm = Read-Host "Remove all these files? (y/N)"

if ($confirm -match '^[Yy]') {
    $removedCount = 0
    $errors = 0
    
    foreach ($file in $filesToClean) {
        try {
            Remove-Item -Path $file.FullName -Force
            Write-Host "✓ Removed: $($file.Name)" -ForegroundColor Green
            $removedCount++
        }
        catch {
            Write-Host "✗ Failed to remove: $($file.Name) - $($_.Exception.Message)" -ForegroundColor Red
            $errors++
        }
    }
    
    Write-Host ""
    Write-Host "=== Cleanup Summary ===" -ForegroundColor Green
    Write-Host "Files removed: $removedCount" -ForegroundColor Green
    if ($errors -gt 0) {
        Write-Host "Errors: $errors" -ForegroundColor Red
    }
    
    # Clean up empty directories
    foreach ($dir in $directoriesToClean) {
        if (Test-Path $dir) {
            $remainingFiles = Get-ChildItem -Path $dir -File -Recurse
            if (-not $remainingFiles) {
                try {
                    Remove-Item -Path $dir -Recurse -Force
                    Write-Host "✓ Removed empty directory: $dir" -ForegroundColor Green
                }
                catch {
                    Write-Host "✗ Could not remove directory: $dir - $($_.Exception.Message)" -ForegroundColor Yellow
                }
            }
        }
    }
    
    Write-Host ""
    Write-Host "Cleanup completed! 🧹" -ForegroundColor Green
} else {
    Write-Host "Cleanup cancelled" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Note: These files will be automatically excluded from Git by .gitignore" -ForegroundColor Cyan