# DeepSeek Claude Installation Script for Windows
# This script installs claude-code in an isolated environment configured for DeepSeek
# Run in PowerShell: .\install-deepseek-claude.ps1

$ErrorActionPreference = "Stop"

# Configuration
$INSTALL_DIR = "$env:USERPROFILE\.deepseek-claude"
$WRAPPER_SCRIPT = "deepseek-claude.cmd"
$PS_WRAPPER_SCRIPT = "deepseek-claude.ps1"

# Available DeepSeek models
$MODELS = @(
    "deepseek-v4-pro",
    "deepseek-v4-flash",
    "deepseek-chat",
    "deepseek-reasoner"
)
$MODEL_DESCRIPTIONS = @(
    "DeepSeek V4 Pro - Strongest model for complex reasoning, coding, and agent workflows",
    "DeepSeek V4 Flash - Fast and economical for cost-efficient production use",
    "DeepSeek Chat - Legacy model (maps to V4 Flash non-thinking mode)",
    "DeepSeek Reasoner - Legacy model (maps to V4 Flash thinking mode)"
)

# Available context limits
$CONTEXT_LIMITS = @("64000", "128000", "256000", "512000", "1000000")
$CONTEXT_DESCRIPTIONS = @("64K tokens", "128K tokens", "256K tokens", "512K tokens", "1M tokens (maximum)")

Write-Host ""
Write-Host "  Installing DeepSeek Claude in isolated environment..." -ForegroundColor Cyan
Write-Host ""

# Check if Node.js and npm are installed
try {
    $null = & node --version 2>&1
} catch {
    Write-Host "  Error: Node.js is not installed. Please install Node.js first." -ForegroundColor Red
    Write-Host "  Download from: https://nodejs.org/" -ForegroundColor Yellow
    exit 1
}

try {
    $null = & npm --version 2>&1
} catch {
    Write-Host "  Error: npm is not installed. Please install npm first." -ForegroundColor Red
    exit 1
}

# Check for DeepSeek API key
if (-not $env:DEEPSEEK_API_KEY) {
    Write-Host "  Warning: DEEPSEEK_API_KEY environment variable is not set." -ForegroundColor Yellow
    Write-Host "  You can set it by running:" -ForegroundColor Yellow
    Write-Host "    `$env:DEEPSEEK_API_KEY = 'your_api_key_here'" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Or set it permanently in System Environment Variables." -ForegroundColor Yellow
    Write-Host ""
}

# Model selection function
function Select-Models {
    $selectedPrimary = ""
    $selectedSmall = ""
    $selectedContext = ""

    Write-Host ""
    Write-Host "  +--------------------------------------------------------------+" -ForegroundColor Cyan
    Write-Host "  |              DeepSeek Model Configuration                     |" -ForegroundColor Cyan
    Write-Host "  +--------------------------------------------------------------+" -ForegroundColor Cyan
    Write-Host ""

    # Select primary model
    Write-Host "  Select your PRIMARY model (for complex tasks):" -ForegroundColor White
    Write-Host ""
    for ($i = 0; $i -lt $MODELS.Count; $i++) {
        Write-Host "    $($i+1)) $($MODEL_DESCRIPTIONS[$i])" -ForegroundColor Green
    }
    Write-Host ""
    while ($true) {
        $choice = Read-Host "  Enter choice [1-$($MODELS.Count)] (default: 1 - deepseek-v4-pro)"
        if ([string]::IsNullOrEmpty($choice)) { $choice = "1" }
        if ($choice -match '^[1-4]$') {
            $selectedPrimary = $MODELS[[int]$choice - 1]
            break
        }
        Write-Host "  Invalid choice. Please enter 1-$($MODELS.Count)." -ForegroundColor Red
    }
    Write-Host "    Primary model: $selectedPrimary" -ForegroundColor Green
    Write-Host ""

    # Select small/fast model
    Write-Host "  Select your SMALL/FAST model (for quick tasks):" -ForegroundColor White
    Write-Host ""
    for ($i = 0; $i -lt $MODELS.Count; $i++) {
        Write-Host "    $($i+1)) $($MODEL_DESCRIPTIONS[$i])" -ForegroundColor Green
    }
    Write-Host ""
    while ($true) {
        $choice = Read-Host "  Enter choice [1-$($MODELS.Count)] (default: 2 - deepseek-v4-flash)"
        if ([string]::IsNullOrEmpty($choice)) { $choice = "2" }
        if ($choice -match '^[1-4]$') {
            $selectedSmall = $MODELS[[int]$choice - 1]
            break
        }
        Write-Host "  Invalid choice. Please enter 1-$($MODELS.Count)." -ForegroundColor Red
    }
    Write-Host "    Small/fast model: $selectedSmall" -ForegroundColor Green
    Write-Host ""

    # Select context limit
    Write-Host "  Select context window limit:" -ForegroundColor White
    Write-Host ""
    for ($i = 0; $i -lt $CONTEXT_LIMITS.Count; $i++) {
        Write-Host "    $($i+1)) $($CONTEXT_DESCRIPTIONS[$i])" -ForegroundColor Green
    }
    Write-Host ""
    while ($true) {
        $choice = Read-Host "  Enter choice [1-$($CONTEXT_LIMITS.Count)] (default: 5 - 1M tokens)"
        if ([string]::IsNullOrEmpty($choice)) { $choice = "5" }
        if ($choice -match '^[1-5]$') {
            $selectedContext = $CONTEXT_LIMITS[[int]$choice - 1]
            break
        }
        Write-Host "  Invalid choice. Please enter 1-$($CONTEXT_LIMITS.Count)." -ForegroundColor Red
    }
    Write-Host "    Context limit: $selectedContext tokens" -ForegroundColor Green
    Write-Host ""

    # Write config file
    @"
# DeepSeek Claude Configuration
# Edit this file or run 'deepseek-claude set-model' to change settings
DEEPSEEK_PRIMARY_MODEL=$selectedPrimary
DEEPSEEK_SMALL_MODEL=$selectedSmall
DEEPSEEK_CONTEXT_LIMIT=$selectedContext
"@ | Set-Content -Path "$INSTALL_DIR\config.env" -Encoding UTF8

    Write-Host "  Configuration saved!" -ForegroundColor Green
}

# Create installation directory
Write-Host "  Creating installation directory: $INSTALL_DIR" -ForegroundColor Cyan
if (-not (Test-Path $INSTALL_DIR)) {
    New-Item -ItemType Directory -Path $INSTALL_DIR -Force | Out-Null
}

Set-Location $INSTALL_DIR

# Initialize npm project if package.json doesn't exist
if (-not (Test-Path "package.json")) {
    Write-Host "  Initializing npm project..." -ForegroundColor Cyan
    @'
{
  "name": "deepseek-claude-installation",
  "version": "1.0.0",
  "description": "DeepSeek Claude isolated installation",
  "private": true
}
'@ | Set-Content -Path "package.json" -Encoding UTF8
}

# Install claude-code locally
Write-Host "  Installing @anthropic-ai/claude-code..." -ForegroundColor Cyan
& npm install @anthropic-ai/claude-code
if ($LASTEXITCODE -ne 0) {
    Write-Host "  Error: npm install failed." -ForegroundColor Red
    exit 1
}

# Run model selection
Select-Models

# Create the CMD wrapper script (for Command Prompt)
Write-Host "  Creating wrapper scripts..." -ForegroundColor Cyan
@"
@echo off
REM DeepSeek Claude Wrapper Script for Windows (CMD)
REM This script sets up DeepSeek environment variables and launches claude-code

REM Handle set-model and show-config without API key check
if "%~1"=="set-model" goto :run_ps
if "%~1"=="show-config" goto :run_ps

REM Check if DEEPSEEK_API_KEY is set
if "%DEEPSEEK_API_KEY%"=="" (
    echo Error: DEEPSEEK_API_KEY environment variable is not set.
    echo.
    echo Set it by running:
    echo   set DEEPSEEK_API_KEY=your_api_key_here
    echo.
    echo Or set it permanently:
    echo   setx DEEPSEEK_API_KEY your_api_key_here
    echo.
    exit /b 1
)

REM Handle update command
if "%~1"=="update" (
    echo Updating DeepSeek Claude...
    cd /d "%~dp0"
    npm update @anthropic-ai/claude-code
    echo Update complete!
    exit /b 0
)

REM Read config file
set "CONFIG_FILE=%~dp0config.env"
if exist "%CONFIG_FILE%" (
    for /f "usebackq tokens=1,* delims==" %%a in ("%CONFIG_FILE%") do (
        set "line=%%a"
        if not "!line:~0,1!"=="#" (
            set "%%a=%%b"
        )
    )
)

REM Set defaults if not configured
if "%DEEPSEEK_PRIMARY_MODEL%"=="" set "DEEPSEEK_PRIMARY_MODEL=deepseek-v4-pro"
if "%DEEPSEEK_SMALL_MODEL%"=="" set "DEEPSEEK_SMALL_MODEL=deepseek-v4-flash"
if "%DEEPSEEK_CONTEXT_LIMIT%"=="" set "DEEPSEEK_CONTEXT_LIMIT=1000000"

REM Set DeepSeek environment variables
set "ANTHROPIC_BASE_URL=https://api.deepseek.com/anthropic"
set "ANTHROPIC_AUTH_TOKEN=%DEEPSEEK_API_KEY%"
set "ANTHROPIC_MODEL=%DEEPSEEK_PRIMARY_MODEL%"
set "ANTHROPIC_SMALL_FAST_MODEL=%DEEPSEEK_SMALL_MODEL%"
set "CLAUDE_CODE_MAX_CONTEXT_TOKENS=%DEEPSEEK_CONTEXT_LIMIT%"

REM Run claude-code from the isolated installation with all arguments
"%~dp0node_modules\.bin\claude.cmd" %*
exit /b %ERRORLEVEL%

:run_ps
powershell -ExecutionPolicy Bypass -File "%~dp0deepseek-claude.ps1" %*
exit /b %ERRORLEVEL%
"@ | Set-Content -Path "$INSTALL_DIR\$WRAPPER_SCRIPT" -Encoding ASCII

# Create the PowerShell wrapper script
@'
# DeepSeek Claude Wrapper Script for Windows (PowerShell)
# This script handles set-model and show-config commands

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$CONFIG_FILE = Join-Path $SCRIPT_DIR "config.env"

# Available models and context limits
$MODELS = @("deepseek-v4-pro", "deepseek-v4-flash", "deepseek-chat", "deepseek-reasoner")
$MODEL_DESCRIPTIONS = @(
    "DeepSeek V4 Pro - Strongest model for complex reasoning, coding, and agent workflows",
    "DeepSeek V4 Flash - Fast and economical for cost-efficient production use",
    "DeepSeek Chat - Legacy model (maps to V4 Flash non-thinking mode)",
    "DeepSeek Reasoner - Legacy model (maps to V4 Flash thinking mode)"
)
$CONTEXT_LIMITS = @("64000", "128000", "256000", "512000", "1000000")
$CONTEXT_DESCRIPTIONS = @("64K tokens", "128K tokens", "256K tokens", "512K tokens", "1M tokens (maximum)")

function Read-Config {
    $config = @{
        DEEPSEEK_PRIMARY_MODEL = "deepseek-v4-pro"
        DEEPSEEK_SMALL_MODEL = "deepseek-v4-flash"
        DEEPSEEK_CONTEXT_LIMIT = "1000000"
    }
    if (Test-Path $CONFIG_FILE) {
        Get-Content $CONFIG_FILE | ForEach-Object {
            if ($_ -match '^([^#][A-Z_]+)=(.+)$') {
                $config[$Matches[1]] = $Matches[2]
            }
        }
    }
    return $config
}

function Save-Config($config) {
    @"
# DeepSeek Claude Configuration
# Edit this file or run 'deepseek-claude set-model' to change settings
DEEPSEEK_PRIMARY_MODEL=$($config.DEEPSEEK_PRIMARY_MODEL)
DEEPSEEK_SMALL_MODEL=$($config.DEEPSEEK_SMALL_MODEL)
DEEPSEEK_CONTEXT_LIMIT=$($config.DEEPSEEK_CONTEXT_LIMIT)
"@ | Set-Content -Path $CONFIG_FILE -Encoding UTF8
}

function Show-Config {
    $config = Read-Config
    Write-Host ""
    Write-Host "  DeepSeek Claude Configuration" -ForegroundColor Cyan
    Write-Host "  ==============================" -ForegroundColor Blue
    Write-Host "    Primary model:    $($config.DEEPSEEK_PRIMARY_MODEL)" -ForegroundColor Green
    Write-Host "    Small/fast model: $($config.DEEPSEEK_SMALL_MODEL)" -ForegroundColor Green
    Write-Host "    Context limit:    $($config.DEEPSEEK_CONTEXT_LIMIT) tokens" -ForegroundColor Green
    Write-Host "    Config file:      $CONFIG_FILE" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  To change: deepseek-claude set-model" -ForegroundColor Blue
    Write-Host ""
}

function Set-Model {
    $config = Read-Config

    Write-Host ""
    Write-Host "  +--------------------------------------------------------------+" -ForegroundColor Cyan
    Write-Host "  |              DeepSeek Model Configuration                     |" -ForegroundColor Cyan
    Write-Host "  +--------------------------------------------------------------+" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Current configuration:" -ForegroundColor Blue
    Write-Host "    Primary model:    $($config.DEEPSEEK_PRIMARY_MODEL)"
    Write-Host "    Small/fast model: $($config.DEEPSEEK_SMALL_MODEL)"
    Write-Host "    Context limit:    $($config.DEEPSEEK_CONTEXT_LIMIT) tokens"
    Write-Host ""

    # Select primary model
    Write-Host "  Select your PRIMARY model (for complex tasks):" -ForegroundColor White
    Write-Host ""
    for ($i = 0; $i -lt $MODELS.Count; $i++) {
        $marker = ""
        if ($MODELS[$i] -eq $config.DEEPSEEK_PRIMARY_MODEL) { $marker = " (current)" }
        Write-Host "    $($i+1)) $($MODEL_DESCRIPTIONS[$i])$marker" -ForegroundColor Green
    }
    Write-Host ""
    while ($true) {
        $choice = Read-Host "  Enter choice [1-$($MODELS.Count)] (default: keep current)"
        if ([string]::IsNullOrEmpty($choice)) { break }
        if ($choice -match '^[1-4]$') {
            $config.DEEPSEEK_PRIMARY_MODEL = $MODELS[[int]$choice - 1]
            break
        }
        Write-Host "  Invalid choice." -ForegroundColor Red
    }
    Write-Host "    Primary model: $($config.DEEPSEEK_PRIMARY_MODEL)" -ForegroundColor Green
    Write-Host ""

    # Select small/fast model
    Write-Host "  Select your SMALL/FAST model (for quick tasks):" -ForegroundColor White
    Write-Host ""
    for ($i = 0; $i -lt $MODELS.Count; $i++) {
        $marker = ""
        if ($MODELS[$i] -eq $config.DEEPSEEK_SMALL_MODEL) { $marker = " (current)" }
        Write-Host "    $($i+1)) $($MODEL_DESCRIPTIONS[$i])$marker" -ForegroundColor Green
    }
    Write-Host ""
    while ($true) {
        $choice = Read-Host "  Enter choice [1-$($MODELS.Count)] (default: keep current)"
        if ([string]::IsNullOrEmpty($choice)) { break }
        if ($choice -match '^[1-4]$') {
            $config.DEEPSEEK_SMALL_MODEL = $MODELS[[int]$choice - 1]
            break
        }
        Write-Host "  Invalid choice." -ForegroundColor Red
    }
    Write-Host "    Small/fast model: $($config.DEEPSEEK_SMALL_MODEL)" -ForegroundColor Green
    Write-Host ""

    # Select context limit
    Write-Host "  Select context window limit:" -ForegroundColor White
    Write-Host ""
    for ($i = 0; $i -lt $CONTEXT_LIMITS.Count; $i++) {
        $marker = ""
        if ($CONTEXT_LIMITS[$i] -eq $config.DEEPSEEK_CONTEXT_LIMIT) { $marker = " (current)" }
        Write-Host "    $($i+1)) $($CONTEXT_DESCRIPTIONS[$i])$marker" -ForegroundColor Green
    }
    Write-Host ""
    while ($true) {
        $choice = Read-Host "  Enter choice [1-$($CONTEXT_LIMITS.Count)] (default: keep current)"
        if ([string]::IsNullOrEmpty($choice)) { break }
        if ($choice -match '^[1-5]$') {
            $config.DEEPSEEK_CONTEXT_LIMIT = $CONTEXT_LIMITS[[int]$choice - 1]
            break
        }
        Write-Host "  Invalid choice." -ForegroundColor Red
    }
    Write-Host "    Context limit: $($config.DEEPSEEK_CONTEXT_LIMIT) tokens" -ForegroundColor Green
    Write-Host ""

    Save-Config $config
    Write-Host "  Configuration saved!" -ForegroundColor Green
    Write-Host ""
    Write-Host "  New configuration:" -ForegroundColor Blue
    Write-Host "    Primary model:    $($config.DEEPSEEK_PRIMARY_MODEL)"
    Write-Host "    Small/fast model: $($config.DEEPSEEK_SMALL_MODEL)"
    Write-Host "    Context limit:    $($config.DEEPSEEK_CONTEXT_LIMIT) tokens"
    Write-Host ""
}

# Main command dispatch
$command = $args[0]
switch ($command) {
    "set-model" { Set-Model }
    "show-config" { Show-Config }
    default {
        # For all other commands, set env vars and run claude
        if (-not $env:DEEPSEEK_API_KEY) {
            Write-Host "  Error: DEEPSEEK_API_KEY environment variable is not set." -ForegroundColor Red
            Write-Host "  Set it by running: `$env:DEEPSEEK_API_KEY = 'your_key'" -ForegroundColor Yellow
            Write-Host "  Or permanently: setx DEEPSEEK_API_KEY your_key" -ForegroundColor Yellow
            exit 1
        }

        $config = Read-Config
        $env:ANTHROPIC_BASE_URL = "https://api.deepseek.com/anthropic"
        $env:ANTHROPIC_AUTH_TOKEN = $env:DEEPSEEK_API_KEY
        $env:ANTHROPIC_MODEL = $config.DEEPSEEK_PRIMARY_MODEL
        $env:ANTHROPIC_SMALL_FAST_MODEL = $config.DEEPSEEK_SMALL_MODEL
        $env:CLAUDE_CODE_MAX_CONTEXT_TOKENS = $config.DEEPSEEK_CONTEXT_LIMIT

        $claudePath = Join-Path $SCRIPT_DIR "node_modules\.bin\claude.cmd"
        $remainingArgs = $args[0..($args.Count - 1)]
        & $claudePath @remainingArgs
    }
}
'@ | Set-Content -Path "$INSTALL_DIR\$PS_WRAPPER_SCRIPT" -Encoding UTF8

# Add to user PATH
Write-Host "  Adding to PATH..." -ForegroundColor Cyan
$currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
if ($currentPath -notlike "*$INSTALL_DIR*") {
    [Environment]::SetEnvironmentVariable("PATH", "$INSTALL_DIR;$currentPath", "User")
    $env:PATH = "$INSTALL_DIR;$env:PATH"
    Write-Host "  Added to user PATH!" -ForegroundColor Green
    Write-Host "  Note: Restart your terminal for PATH changes to take effect." -ForegroundColor Yellow
} else {
    Write-Host "  Already in PATH." -ForegroundColor Green
}

Write-Host ""
Write-Host "  Installation completed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "  Usage Instructions:" -ForegroundColor Cyan
Write-Host "  1. Set your DeepSeek API key (one-time):" -ForegroundColor White
Write-Host "     setx DEEPSEEK_API_KEY your_api_key_here" -ForegroundColor Yellow
Write-Host ""
Write-Host "  2. Restart your terminal, then run:" -ForegroundColor White
Write-Host "     deepseek-claude" -ForegroundColor Yellow
Write-Host ""
Write-Host "  Commands:" -ForegroundColor Cyan
Write-Host "    deepseek-claude              - Start interactive session" -ForegroundColor White
Write-Host "    deepseek-claude set-model    - Change model/context settings" -ForegroundColor White
Write-Host "    deepseek-claude show-config  - View current configuration" -ForegroundColor White
Write-Host "    deepseek-claude update       - Update to latest version" -ForegroundColor White
Write-Host ""
Write-Host "  Configuration:" -ForegroundColor Cyan

# Read back config to display
$config = @{}
Get-Content "$INSTALL_DIR\config.env" | ForEach-Object {
    if ($_ -match '^([^#][A-Z_]+)=(.+)$') {
        $config[$Matches[1]] = $Matches[2]
    }
}
Write-Host "    Primary model:    $($config.DEEPSEEK_PRIMARY_MODEL)" -ForegroundColor White
Write-Host "    Small/fast model: $($config.DEEPSEEK_SMALL_MODEL)" -ForegroundColor White
Write-Host "    Context limit:    $($config.DEEPSEEK_CONTEXT_LIMIT) tokens" -ForegroundColor White
Write-Host "    Base URL:         https://api.deepseek.com/anthropic" -ForegroundColor White
Write-Host ""
