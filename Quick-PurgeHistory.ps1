# Quick Git History Purge - Remove Sensitive Files Immediately

Write-Host "=== Quick Git History Purge ===" -ForegroundColor Red
Write-Host "This script will immediately remove sensitive data files from Git history" -ForegroundColor Yellow
Write-Host "using only built-in Git commands.`n" -ForegroundColor White

# Check if we're in a Git repository
if (-not (Test-Path ".git")) {
    Write-Host "✗ Not in a Git repository" -ForegroundColor Red
    exit 1
}

Write-Host "Current repository status:" -ForegroundColor Cyan
git log --oneline -5

Write-Host "`nFiles currently tracked by Git:" -ForegroundColor Cyan
$trackedFiles = git ls-files
$sensitiveFiles = $trackedFiles | Where-Object { 
    $_ -like "*.csv" -or $_ -like "*.log" -or $_ -like "Reports/*" -or $_ -like "Logs/*" 
}

if ($sensitiveFiles) {
    Write-Host "❌ Found sensitive files in Git history:" -ForegroundColor Red
    foreach ($file in $sensitiveFiles) {
        Write-Host "  - $file" -ForegroundColor Yellow
    }
} else {
    Write-Host "✅ No sensitive files currently tracked" -ForegroundColor Green
}

Write-Host ""
$proceed = Read-Host "Remove ALL CSV and log files from Git history? This cannot be undone. (type YES to confirm)"

if ($proceed -eq "YES") {
    Write-Host "`n🚀 Starting immediate cleanup..." -ForegroundColor Green
    
    try {
        # Method 1: Remove specific file patterns from entire history
        Write-Host "Step 1: Removing CSV files from history..." -ForegroundColor Yellow
        git filter-branch --force --index-filter 'git rm --cached --ignore-unmatch "*.csv"' --prune-empty --tag-name-filter cat -- --all
        
        Write-Host "Step 2: Removing log files from history..." -ForegroundColor Yellow  
        git filter-branch --force --index-filter 'git rm --cached --ignore-unmatch "*.log"' --prune-empty --tag-name-filter cat -- --all
        
        Write-Host "Step 3: Removing Reports directory from history..." -ForegroundColor Yellow
        git filter-branch --force --index-filter 'git rm -rf --cached --ignore-unmatch Reports/' --prune-empty --tag-name-filter cat -- --all
        
        Write-Host "Step 4: Removing Logs directory from history..." -ForegroundColor Yellow
        git filter-branch --force --index-filter 'git rm -rf --cached --ignore-unmatch Logs/' --prune-empty --tag-name-filter cat -- --all
        
        # Clean up the mess left by filter-branch
        Write-Host "Step 5: Cleaning up..." -ForegroundColor Yellow
        
        # Remove backup refs
        if (Test-Path ".git/refs/original") {
            Remove-Item -Path ".git/refs/original" -Recurse -Force
            Write-Host "  ✓ Removed backup references" -ForegroundColor Green
        }
        
        # Expire all reflogs
        git reflog expire --expire=now --all
        
        # Aggressive garbage collection
        git gc --prune=now --aggressive
        
        Write-Host "`n✅ History cleanup completed!" -ForegroundColor Green
        
        # Verify the cleanup
        Write-Host "`nVerification:" -ForegroundColor Cyan
        $remainingSensitive = git ls-files | Where-Object { 
            $_ -like "*.csv" -or $_ -like "*.log" -or $_ -like "Reports/*" -or $_ -like "Logs/*" 
        }
        
        if ($remainingSensitive) {
            Write-Host "⚠️  Some files may still be tracked:" -ForegroundColor Yellow
            foreach ($file in $remainingSensitive) {
                Write-Host "  - $file" -ForegroundColor White
            }
        } else {
            Write-Host "✅ No sensitive files found in Git tracking" -ForegroundColor Green
        }
        
        # Show new repository info
        Write-Host "`nRepository status after cleanup:" -ForegroundColor Cyan
        git log --oneline -5
        
        # Calculate approximate size savings
        try {
            $repoSize = (Get-ChildItem -Path ".git" -Recurse | Measure-Object -Property Length -Sum).Sum
            Write-Host "`nCurrent .git directory size: $([math]::Round($repoSize / 1MB, 2)) MB" -ForegroundColor White
        }
        catch {
            Write-Host "`nCould not calculate repository size" -ForegroundColor Gray
        }
        
        Write-Host "`n🎉 Sensitive data purged from Git history!" -ForegroundColor Green
        Write-Host "`n⚠️  IMPORTANT NEXT STEPS:" -ForegroundColor Yellow
        Write-Host "1. If you have a remote repository (GitHub, etc.), you MUST force push:" -ForegroundColor White
        Write-Host "   git push --force-with-lease origin main" -ForegroundColor Cyan
        Write-Host "`n2. All collaborators must re-clone the repository:" -ForegroundColor White
        Write-Host "   rm -rf local-repo && git clone <repo-url>" -ForegroundColor Cyan
        Write-Host "`n3. The old history with sensitive data may still exist on:" -ForegroundColor White
        Write-Host "   - GitHub/remote server (until force pushed)" -ForegroundColor Gray
        Write-Host "   - Other developers' local clones" -ForegroundColor Gray
        Write-Host "   - Backup systems" -ForegroundColor Gray
        
    }
    catch {
        Write-Host "`n❌ Error during cleanup: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "You may need to resolve conflicts or try alternative methods." -ForegroundColor Yellow
        
        # Try to recover
        Write-Host "`nAttempting to recover..." -ForegroundColor Yellow
        try {
            git reset --hard HEAD
            Write-Host "✓ Repository state recovered" -ForegroundColor Green
        }
        catch {
            Write-Host "⚠️  Could not auto-recover. Check repository state manually." -ForegroundColor Red
        }
    }
    
} else {
    Write-Host "`nOperation cancelled. No changes made." -ForegroundColor Yellow
}

Write-Host "`nFor more advanced cleanup options, run: .\Purge-GitHistory.ps1" -ForegroundColor Cyan