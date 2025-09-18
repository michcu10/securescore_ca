# Git History Cleanup Script - Remove Sensitive Data from Repository History

Write-Host "=== Git History Cleanup - Remove Sensitive Data ===" -ForegroundColor Red
Write-Host "⚠️  WARNING: This script will permanently remove files from Git history!" -ForegroundColor Yellow
Write-Host "This action cannot be undone and will rewrite repository history.`n" -ForegroundColor Yellow

# Check if git-filter-repo is available (preferred method)
$filterRepoAvailable = $false
try {
    git filter-repo --version 2>$null | Out-Null
    $filterRepoAvailable = $true
    Write-Host "✓ git-filter-repo is available (recommended method)" -ForegroundColor Green
}
catch {
    Write-Host "⚠️  git-filter-repo not found. Will use BFG Repo-Cleaner as alternative." -ForegroundColor Yellow
}

Write-Host ""

# Define patterns to remove from history
$filesToPurge = @(
    "*.csv",
    "*.log", 
    "Reports/",
    "Logs/",
    "*.tmp",
    "*.temp"
)

Write-Host "Files/patterns to be purged from Git history:" -ForegroundColor Yellow
foreach ($pattern in $filesToPurge) {
    Write-Host "  - $pattern" -ForegroundColor White
}

Write-Host ""
Write-Host "⚠️  IMPORTANT WARNINGS:" -ForegroundColor Red
Write-Host "• This will rewrite the entire Git history" -ForegroundColor Yellow
Write-Host "• All commit SHAs will change" -ForegroundColor Yellow
Write-Host "• If this repo is shared, collaborators will need to re-clone" -ForegroundColor Yellow
Write-Host "• Remote repository will need force push (if applicable)" -ForegroundColor Yellow
Write-Host "• Create a backup before proceeding!" -ForegroundColor Yellow

Write-Host ""
$createBackup = Read-Host "Create a backup of the repository first? (Y/n)"
if ($createBackup -notmatch '^[Nn]') {
    try {
        $backupPath = "..\securescore_ca_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        Write-Host "Creating backup at: $backupPath" -ForegroundColor Yellow
        
        # Create backup using git clone
        git clone . $backupPath
        Write-Host "✓ Backup created successfully" -ForegroundColor Green
    }
    catch {
        Write-Host "✗ Failed to create backup: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Consider creating a manual backup before proceeding." -ForegroundColor Yellow
    }
}

Write-Host ""
$confirm = Read-Host "Do you want to proceed with purging sensitive data from Git history? (type 'PURGE' to confirm)"

if ($confirm -eq 'PURGE') {
    Write-Host ""
    Write-Host "=== Starting Git History Cleanup ===" -ForegroundColor Green
    
    if ($filterRepoAvailable) {
        Write-Host "Using git-filter-repo (recommended method)..." -ForegroundColor Yellow
        
        try {
            # Remove files by path patterns
            foreach ($pattern in $filesToPurge) {
                Write-Host "Removing pattern: $pattern" -ForegroundColor White
                
                if ($pattern.EndsWith("/")) {
                    # Directory pattern
                    git filter-repo --path $pattern --invert-paths --force
                } else {
                    # File pattern
                    git filter-repo --path-glob $pattern --invert-paths --force
                }
            }
            
            Write-Host "✓ History cleanup completed using git-filter-repo" -ForegroundColor Green
        }
        catch {
            Write-Host "✗ git-filter-repo failed: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "Falling back to alternative method..." -ForegroundColor Yellow
            $filterRepoAvailable = $false
        }
    }
    
    if (-not $filterRepoAvailable) {
        Write-Host "Using git filter-branch (fallback method)..." -ForegroundColor Yellow
        Write-Host "⚠️  This method is slower but should work on all Git installations" -ForegroundColor Yellow
        
        try {
            # Build the filter-branch command to remove sensitive files
            $indexFilter = ""
            foreach ($pattern in $filesToPurge) {
                if ($pattern.EndsWith("/")) {
                    # Directory pattern
                    $indexFilter += "git rm -rf --cached --ignore-unmatch '$pattern' || true; "
                } else {
                    # File pattern  
                    $indexFilter += "git rm -rf --cached --ignore-unmatch '$pattern' || true; "
                }
            }
            
            Write-Host "Running git filter-branch..." -ForegroundColor White
            Write-Host "This may take several minutes for large repositories..." -ForegroundColor Gray
            
            # Execute filter-branch
            $cmd = "git filter-branch --index-filter `"$indexFilter`" --prune-empty --tag-name-filter cat -- --all"
            Invoke-Expression $cmd
            
            Write-Host "✓ History cleanup completed using git filter-branch" -ForegroundColor Green
        }
        catch {
            Write-Host "✗ git filter-branch failed: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "You may need to install git-filter-repo or BFG Repo-Cleaner for better results." -ForegroundColor Yellow
            return
        }
    }
    
    Write-Host ""
    Write-Host "=== Cleanup Completed ===" -ForegroundColor Green
    
    # Clean up backup refs and run garbage collection
    Write-Host "Cleaning up backup references and running garbage collection..." -ForegroundColor Yellow
    try {
        # Remove backup refs created by filter-branch
        if (Test-Path ".git/refs/original") {
            Remove-Item -Path ".git/refs/original" -Recurse -Force
            Write-Host "✓ Removed backup references" -ForegroundColor Green
        }
        
        # Expire reflogs and run garbage collection
        git reflog expire --expire=now --all
        git gc --prune=now --aggressive
        
        Write-Host "✓ Garbage collection completed" -ForegroundColor Green
    }
    catch {
        Write-Host "⚠️  Warning: Cleanup operations had issues: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "Repository should still be clean, but you may want to run 'git gc' manually." -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "=== Summary ===" -ForegroundColor Cyan
    
    # Show repository size before/after (if possible)
    try {
        $repoSize = (Get-ChildItem -Path ".git" -Recurse | Measure-Object -Property Length -Sum).Sum
        Write-Host "Current repository size: $([math]::Round($repoSize / 1MB, 2)) MB" -ForegroundColor White
    }
    catch {
        Write-Host "Could not calculate repository size" -ForegroundColor Gray
    }
    
    # Check if there are any remaining sensitive files
    Write-Host ""
    Write-Host "Checking for any remaining sensitive files..." -ForegroundColor Yellow
    $remainingFiles = git ls-files | Where-Object { 
        $_ -like "*.csv" -or $_ -like "*.log" -or $_ -like "Reports/*" -or $_ -like "Logs/*" 
    }
    
    if ($remainingFiles) {
        Write-Host "⚠️  Warning: Some files may still be tracked:" -ForegroundColor Yellow
        foreach ($file in $remainingFiles) {
            Write-Host "  - $file" -ForegroundColor White
        }
    } else {
        Write-Host "✓ No sensitive file patterns found in Git tracking" -ForegroundColor Green
    }
    
    Write-Host ""
    Write-Host "=== Next Steps ===" -ForegroundColor Cyan
    Write-Host "1. Verify the cleanup worked correctly:" -ForegroundColor White
    Write-Host "   git log --oneline --all" -ForegroundColor Gray
    Write-Host "   git ls-files | grep -E '\\.(csv|log)$'" -ForegroundColor Gray
    Write-Host ""
    Write-Host "2. If you have a remote repository, you'll need to force push:" -ForegroundColor White
    Write-Host "   git push --force-with-lease --all" -ForegroundColor Gray
    Write-Host "   git push --force-with-lease --tags" -ForegroundColor Gray
    Write-Host ""
    Write-Host "3. All collaborators will need to re-clone the repository:" -ForegroundColor White
    Write-Host "   git clone <repository-url>" -ForegroundColor Gray
    Write-Host ""
    Write-Host "⚠️  Remember: Force pushing changes history permanently!" -ForegroundColor Yellow
    
} else {
    Write-Host "Operation cancelled. No changes made to Git history." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Installation Guide for git-filter-repo ===" -ForegroundColor Cyan
Write-Host "For better performance in future cleanups, install git-filter-repo:" -ForegroundColor White
Write-Host ""
Write-Host "Python/pip method:" -ForegroundColor Yellow
Write-Host "  pip install git-filter-repo" -ForegroundColor Gray
Write-Host ""
Write-Host "Manual installation:" -ForegroundColor Yellow
Write-Host "  1. Download from: https://github.com/newren/git-filter-repo" -ForegroundColor Gray
Write-Host "  2. Place git-filter-repo in your PATH" -ForegroundColor Gray
Write-Host ""
Write-Host "Package managers:" -ForegroundColor Yellow
Write-Host "  # macOS" -ForegroundColor Gray
Write-Host "  brew install git-filter-repo" -ForegroundColor Gray
Write-Host "  # Ubuntu/Debian" -ForegroundColor Gray  
Write-Host "  apt install git-filter-repo" -ForegroundColor Gray