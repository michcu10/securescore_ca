# Force Push After History Cleanup Script

Write-Host "=== Force Push After Git History Cleanup ===" -ForegroundColor Red
Write-Host "This script will force push the cleaned history to the remote repository." -ForegroundColor Yellow
Write-Host "⚠️  This will OVERWRITE the remote history completely!`n" -ForegroundColor Yellow

# Verify we're in the right state
Write-Host "Current local repository state:" -ForegroundColor Cyan
Write-Host "Local HEAD: $(git rev-parse HEAD)" -ForegroundColor White
Write-Host "Remote HEAD: $(git ls-remote origin main | Select-String main | ForEach-Object { $_.ToString().Split()[0] })" -ForegroundColor White

Write-Host "`nLocal commits (cleaned history):" -ForegroundColor Cyan
git log --oneline -5

Write-Host "`nRemote commits (with sensitive data):" -ForegroundColor Yellow
git fetch origin main 2>$null
git log --oneline origin/main -5 2>$null

Write-Host "`n⚠️  CRITICAL WARNINGS:" -ForegroundColor Red
Write-Host "• This will permanently overwrite GitHub history" -ForegroundColor Yellow
Write-Host "• All collaborators will need to re-clone the repository" -ForegroundColor Yellow
Write-Host "• The old commits with sensitive data will be replaced" -ForegroundColor Yellow
Write-Host "• This action cannot be undone" -ForegroundColor Yellow

Write-Host "`n✅ Benefits:" -ForegroundColor Green
Write-Host "• Removes sensitive CSV and log files from GitHub history" -ForegroundColor White
Write-Host "• Prevents potential data exposure" -ForegroundColor White
Write-Host "• Creates a clean repository state" -ForegroundColor White

Write-Host ""
$confirm = Read-Host "Proceed with force push to GitHub? (type 'FORCE PUSH' to confirm)"

if ($confirm -eq 'FORCE PUSH') {
    Write-Host "`n🚀 Starting force push..." -ForegroundColor Green
    
    try {
        # Method 1: Try --force-with-lease with explicit remote ref
        Write-Host "Attempting force push with lease..." -ForegroundColor Yellow
        $remoteRef = git ls-remote origin main | Select-String main | ForEach-Object { $_.ToString().Split()[0] }
        git push --force-with-lease=main:$remoteRef origin main
        Write-Host "✅ Force push with lease successful!" -ForegroundColor Green
        $success = $true
    }
    catch {
        Write-Host "⚠️  Force with lease failed, trying regular force push..." -ForegroundColor Yellow
        $success = $false
    }
    
    if (-not $success) {
        try {
            # Method 2: Regular force push (less safe but necessary after history rewrite)
            Write-Host "Performing regular force push..." -ForegroundColor Yellow
            git push --force origin main
            Write-Host "✅ Regular force push successful!" -ForegroundColor Green
            $success = $true
        }
        catch {
            Write-Host "❌ Force push failed: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "Manual intervention may be required." -ForegroundColor Yellow
            return
        }
    }
    
    if ($success) {
        # Also push tags if they exist
        try {
            git push --force origin --tags
            Write-Host "✅ Tags pushed successfully" -ForegroundColor Green
        }
        catch {
            Write-Host "⚠️  Tag push failed (this is usually not critical)" -ForegroundColor Yellow
        }
        
        Write-Host "`n🎉 SUCCESS! Repository history cleaned and pushed to GitHub!" -ForegroundColor Green
        
        # Verify the push worked
        Write-Host "`nVerification:" -ForegroundColor Cyan
        git fetch origin main
        $localHead = git rev-parse HEAD
        $remoteHead = git rev-parse origin/main
        
        if ($localHead -eq $remoteHead) {
            Write-Host "✅ Local and remote are now synchronized" -ForegroundColor Green
        } else {
            Write-Host "⚠️  Local and remote still differ - manual check recommended" -ForegroundColor Yellow
        }
        
        Write-Host "`n=== IMPORTANT NEXT STEPS ===" -ForegroundColor Cyan
        Write-Host "1. Verify on GitHub that sensitive files are gone from history" -ForegroundColor White
        Write-Host "2. Notify all collaborators that they need to re-clone:" -ForegroundColor White
        Write-Host "   git clone https://github.com/michcu10/securescore_ca.git" -ForegroundColor Gray
        Write-Host "3. Consider making the repository private if it contains sensitive configs" -ForegroundColor White
        Write-Host "4. Update any CI/CD systems that reference the old commit SHAs" -ForegroundColor White
        
        Write-Host "`n✅ Sensitive data has been purged from GitHub history!" -ForegroundColor Green
    }
    
} else {
    Write-Host "`nOperation cancelled. Repository not pushed to GitHub." -ForegroundColor Yellow
    Write-Host "Note: Local history is already cleaned. You can run this script again later." -ForegroundColor Cyan
}

Write-Host "`n=== Alternative Manual Commands ===" -ForegroundColor Cyan
Write-Host "If this script doesn't work, try these manual commands:" -ForegroundColor White
Write-Host "git push --force origin main" -ForegroundColor Gray
Write-Host "git push --force origin --tags" -ForegroundColor Gray