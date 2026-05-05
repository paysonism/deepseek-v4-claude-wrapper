# DeepSeek Claude Uninstall Script for Windows
# Run in PowerShell: .\uninstall-deepseek-claude.ps1

$ErrorActionPreference = "Stop"

$INSTALL_DIR = "$env:USERPROFILE\.deepseek-claude"

Write-Host ""
Write-Host "  Uninstalling DeepSeek Claude..." -ForegroundColor Cyan
Write-Host ""

# Remove installation directory
if (Test-Path $INSTALL_DIR) {
    Write-Host "  Removing installation directory: $INSTALL_DIR" -ForegroundColor Cyan
    Remove-Item -Recurse -Force $INSTALL_DIR
    Write-Host "  Installation directory removed." -ForegroundColor Green
} else {
    Write-Host "  Installation directory not found: $INSTALL_DIR" -ForegroundColor Yellow
}

# Remove from user PATH
$currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
if ($currentPath -like "*$INSTALL_DIR*") {
    $newPath = ($currentPath -split ";" | Where-Object { $_ -ne $INSTALL_DIR }) -join ";"
    [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
    Write-Host "  Removed from user PATH." -ForegroundColor Green
}

Write-Host ""
Write-Host "  DeepSeek Claude has been uninstalled successfully!" -ForegroundColor Green
Write-Host "  Note: Your original Claude Code installation remains untouched." -ForegroundColor Cyan
Write-Host ""
