$ErrorActionPreference = "Continue"

$INSTALL_DIR = "$env:USERPROFILE\.deepseek-claude"
$CLAUDE_DIR  = "$env:USERPROFILE\.claude"
$CLAUDE_MD   = "$CLAUDE_DIR\CLAUDE.md"

function Remove-FromUserPath {
    param([string]$DirToRemove)
    $DirToRemove = $DirToRemove.TrimEnd('\')
    $userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
    if ([string]::IsNullOrEmpty($userPath)) {
        return $false
    }
    $parts = $userPath -split ';' | Where-Object { $_ -ne '' } | ForEach-Object { $_.TrimEnd('\') }
    $newParts = $parts | Where-Object { $_ -ne $DirToRemove }
    if ($newParts.Count -eq $parts.Count) {
        return $false   # not found
    }
    $newPath = $newParts -join ';'
    [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
    # Also update current process PATH
    $env:PATH = ($newParts + ($env:PATH -split ';' | Where-Object { $_ -ne $DirToRemove })) -join ';'
    return $true
}

Write-Host ""
Write-Host "  ┌──────────────────────────────────────────────────────────────┐" -ForegroundColor Cyan
Write-Host "  │           DeepSeek Claude — Full Uninstall                   │" -ForegroundColor Cyan
Write-Host "  └──────────────────────────────────────────────────────────────┘" -ForegroundColor Cyan
Write-Host ""
Write-Host "  This will permanently remove:" -ForegroundColor Yellow
Write-Host "    • Installation directory: $INSTALL_DIR" -ForegroundColor White
Write-Host "    • Global CLAUDE.md file:   $CLAUDE_MD" -ForegroundColor White
Write-Host "    • '$INSTALL_DIR' entry from your user PATH" -ForegroundColor White
Write-Host ""
$confirm = Read-Host "  Type 'yes' to confirm uninstall"
if ($confirm -ne "yes") {
    Write-Host "  Uninstall cancelled." -ForegroundColor Green
    exit 0
}

# install directory cleanup
Write-Host ""
Write-Host "  [1/3] Removing installation directory..." -ForegroundColor Cyan
if (Test-Path $INSTALL_DIR) {
    try {
        Get-ChildItem -Path $INSTALL_DIR -Recurse -Force | ForEach-Object {
            if (-not $_.PSIsContainer) { $_.IsReadOnly = $false }
        }
        Remove-Item -Path $INSTALL_DIR -Recurse -Force -ErrorAction Stop
        Write-Host "  ✓ Deleted: $INSTALL_DIR" -ForegroundColor Green
    }
    catch {
        Write-Host "  ✗ Failed to delete $INSTALL_DIR : $_" -ForegroundColor Red
        Write-Host "    You may need to close any process that is using this directory (e.g., a running deepseek-claude session)." -ForegroundColor Yellow
    }
}
else {
    Write-Host "  - Directory not found (already removed)." -ForegroundColor Gray
}

# global claude.md
Write-Host ""
Write-Host "  [2/3] Removing global CLAUDE.md..." -ForegroundColor Cyan
if (Test-Path $CLAUDE_MD) {
    try {
        Remove-Item -Path $CLAUDE_MD -Force -ErrorAction Stop
        Write-Host "  ✓ Deleted: $CLAUDE_MD" -ForegroundColor Green
    }
    catch {
        Write-Host "  ✗ Failed to delete $CLAUDE_MD : $_" -ForegroundColor Red
    }
}
else {
    Write-Host "  - CLAUDE.md not found (already removed or never existed)." -ForegroundColor Gray
}

# path
Write-Host ""
Write-Host "  [3/3] Cleaning user PATH..." -ForegroundColor Cyan
$removed = Remove-FromUserPath -DirToRemove $INSTALL_DIR
if ($removed) {
    Write-Host "  ✓ Removed '$INSTALL_DIR' from user PATH." -ForegroundColor Green
    Write-Host "  ⚠  Changes to PATH will take effect in new terminal sessions." -ForegroundColor Yellow
}
else {
    Write-Host "  - '$INSTALL_DIR' was not found in user PATH (already cleaned)." -ForegroundColor Gray
}

Write-Host ""
Write-Host "  ┌──────────────────────────────────────────────────────────────┐" -ForegroundColor Green
Write-Host "  │                    Uninstall Complete                        │" -ForegroundColor Green
Write-Host "  └──────────────────────────────────────────────────────────────┘" -ForegroundColor Green
Write-Host ""
Write-Host "  DeepSeek Claude has been removed from this system." -ForegroundColor White
Write-Host "  If you set the DEEPSEEK_API_KEY environment variable manually," -ForegroundColor White
Write-Host "  you may want to delete it with:  [Environment]::SetEnvironmentVariable('DEEPSEEK_API_KEY', '', 'User')" -ForegroundColor Gray
Write-Host ""