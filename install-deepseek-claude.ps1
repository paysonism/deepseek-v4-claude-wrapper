# DeepSeek Claude Installation Script for Windows
# Fixed: PATH stability, $PSScriptRoot, enabledelayedexpansion, empty-args bug, global CLAUDE.md
# Run in PowerShell (as user): .\install-deepseek-claude.ps1

$ErrorActionPreference = "Stop"

# ── Configuration ─────────────────────────────────────────────────────────────
$INSTALL_DIR   = "$env:USERPROFILE\.deepseek-claude"
$CLAUDE_DIR    = "$env:USERPROFILE\.claude"
$CMD_WRAPPER   = "deepseek-claude.cmd"
$PS_WRAPPER    = "deepseek-claude.ps1"

$MODELS = @(
    "deepseek-v4-pro",
    "deepseek-v4-flash",
    "deepseek-chat",
    "deepseek-reasoner"
)
$MODEL_DESCRIPTIONS = @(
    "DeepSeek V4 Pro   - Strongest model, complex reasoning + agent workflows",
    "DeepSeek V4 Flash - Fast and economical for cost-efficient production use",
    "DeepSeek Chat     - Legacy (maps to V4 Flash non-thinking mode)",
    "DeepSeek Reasoner - Legacy (maps to V4 Flash thinking mode)"
)

$CONTEXT_LIMITS = @("64000", "128000", "256000", "512000", "1000000")
$CONTEXT_DESCRIPTIONS = @(
    "64K   tokens",
    "128K  tokens",
    "256K  tokens",
    "512K  tokens",
    "1M    tokens (maximum — recommended for DeepSeek V4 Pro)"
)

# ── Helpers ───────────────────────────────────────────────────────────────────
function Ensure-Dir($path) {
    if (-not (Test-Path $path)) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
    }
}

function Add-ToUserPath($dir) {
    # Normalize: trim trailing backslashes, lowercase compare
    $dir = $dir.TrimEnd('\')
    $current = [Environment]::GetEnvironmentVariable("PATH", "User")
    $parts = $current -split ';' | Where-Object { $_ -ne '' } | ForEach-Object { $_.TrimEnd('\') }
    if ($parts -notcontains $dir) {
        $newPath = ($parts + $dir) -join ';'
        [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
        $env:PATH = "$dir;$env:PATH"
        return $true
    }
    return $false
}

# ── Header ────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  ┌──────────────────────────────────────────────────────────────┐" -ForegroundColor Cyan
Write-Host "  │         DeepSeek Claude — Isolated Install (Fixed)           │" -ForegroundColor Cyan
Write-Host "  └──────────────────────────────────────────────────────────────┘" -ForegroundColor Cyan
Write-Host ""

# ── Prerequisites ─────────────────────────────────────────────────────────────
Write-Host "  Checking prerequisites..." -ForegroundColor Cyan

try { $null = & node --version 2>&1 } catch {
    Write-Host "  ✗ Node.js not found. Install from https://nodejs.org/" -ForegroundColor Red; exit 1
}
try { $null = & npm --version 2>&1 } catch {
    Write-Host "  ✗ npm not found. Reinstall Node.js." -ForegroundColor Red; exit 1
}
Write-Host "  ✓ Node.js / npm OK" -ForegroundColor Green

if (-not $env:DEEPSEEK_API_KEY) {
    Write-Host ""
    Write-Host "  ⚠  DEEPSEEK_API_KEY is not set. Set it permanently with:" -ForegroundColor Yellow
    Write-Host "       setx DEEPSEEK_API_KEY your_key_here" -ForegroundColor Yellow
    Write-Host "     Then restart your terminal." -ForegroundColor Yellow
    Write-Host ""
}

# ── Model / Context Selection ─────────────────────────────────────────────────
function Select-Models {
    Write-Host ""
    Write-Host "  ── Model Configuration ──────────────────────────────────────" -ForegroundColor Cyan
    Write-Host ""

    # Primary model
    Write-Host "  PRIMARY model (complex tasks):" -ForegroundColor White
    for ($i = 0; $i -lt $MODELS.Count; $i++) {
        Write-Host "    $($i+1)) $($MODEL_DESCRIPTIONS[$i])" -ForegroundColor Green
    }
    Write-Host ""
    do {
        $c = Read-Host "  Choice [1-$($MODELS.Count)] (default: 1)"
        if ([string]::IsNullOrEmpty($c)) { $c = "1" }
    } while ($c -notmatch '^[1-4]$')
    $primaryModel = $MODELS[[int]$c - 1]
    Write-Host "  → $primaryModel" -ForegroundColor Green
    Write-Host ""

    # Small/fast model
    Write-Host "  SMALL/FAST model (background tasks, file search):" -ForegroundColor White
    for ($i = 0; $i -lt $MODELS.Count; $i++) {
        Write-Host "    $($i+1)) $($MODEL_DESCRIPTIONS[$i])" -ForegroundColor Green
    }
    Write-Host ""
    do {
        $c = Read-Host "  Choice [1-$($MODELS.Count)] (default: 2)"
        if ([string]::IsNullOrEmpty($c)) { $c = "2" }
    } while ($c -notmatch '^[1-4]$')
    $smallModel = $MODELS[[int]$c - 1]
    Write-Host "  → $smallModel" -ForegroundColor Green
    Write-Host ""

    # Context limit
    Write-Host "  CONTEXT window limit:" -ForegroundColor White
    for ($i = 0; $i -lt $CONTEXT_LIMITS.Count; $i++) {
        Write-Host "    $($i+1)) $($CONTEXT_DESCRIPTIONS[$i])" -ForegroundColor Green
    }
    Write-Host ""
    do {
        $c = Read-Host "  Choice [1-$($CONTEXT_LIMITS.Count)] (default: 5)"
        if ([string]::IsNullOrEmpty($c)) { $c = "5" }
    } while ($c -notmatch '^[1-5]$')
    $contextLimit = $CONTEXT_LIMITS[[int]$c - 1]
    Write-Host "  → $contextLimit tokens" -ForegroundColor Green
    Write-Host ""

    @"
# DeepSeek Claude Configuration
# Edit manually or run: deepseek-claude set-model
DEEPSEEK_PRIMARY_MODEL=$primaryModel
DEEPSEEK_SMALL_MODEL=$smallModel
DEEPSEEK_CONTEXT_LIMIT=$contextLimit
DEEPSEEK_INSTALL_DIR=$INSTALL_DIR
"@ | Set-Content -Path "$INSTALL_DIR\config.env" -Encoding UTF8

    Write-Host "  ✓ Configuration saved." -ForegroundColor Green
}

# ── Create Directories & Install npm Package ──────────────────────────────────
Write-Host ""
Write-Host "  Creating install directory: $INSTALL_DIR" -ForegroundColor Cyan
Ensure-Dir $INSTALL_DIR
Ensure-Dir $CLAUDE_DIR

Set-Location $INSTALL_DIR

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

Write-Host "  Installing @anthropic-ai/claude-code (local)..." -ForegroundColor Cyan
& npm install @anthropic-ai/claude-code
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ✗ npm install failed." -ForegroundColor Red; exit 1
}
Write-Host "  ✓ claude-code installed." -ForegroundColor Green

# Run model selection
Select-Models

# ── Global CLAUDE.md ──────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  Installing global CLAUDE.md to $CLAUDE_DIR\CLAUDE.md ..." -ForegroundColor Cyan

$CLAUDE_MD_CONTENT = @'
# CLAUDE.md — DeepSeek V4 Pro | Optimized System Context

---

## ROLE

You are an expert software engineer and code analyst embedded in a development environment via Claude Code CLI. You operate with precision, honesty, and discipline. You do not guess. You do not hallucinate. You do not fill gaps with plausible-sounding fiction.

---

## ABSOLUTE RULES — NEVER VIOLATE

1. **If you do not know something with certainty, say so.** The phrase "I don't know" or "I'm not certain — verify this" is always the correct output when confidence is low.
2. **Never invent function names, API signatures, struct fields, symbol names, or library methods.** Only reference identifiers that are confirmed in the provided source, codebase, header files, or dump output.
3. **Never assume a file, symbol, or module exists unless you have seen it in context.** If the context doesn't confirm it, say so explicitly.
4. **Do not hallucinate documentation.** If you are referencing a library or API, only describe behavior you can verify from what is in context or your confirmed training knowledge. Flag uncertainty with `[UNVERIFIED]`.
5. **Do not silently repair broken assumptions.** If the task contains a contradiction or an unknowable dependency, surface it immediately before proceeding.

---

## REASONING PROTOCOL

Before writing any code or making any substantive change, do the following mentally (you may show this inline if the task is complex):

1. **Restate the goal** in one sentence to confirm your interpretation.
2. **Identify what you know** — confirmed facts from context.
3. **Identify what you don't know** — gaps that could cause errors.
4. **State your plan** before executing, especially for multi-step tasks.
5. **Execute** only after the above is complete.

For complex tasks (refactors, architecture decisions, multi-file edits), output a short **PLAN block** before any code:

```
PLAN:
- Goal: <one sentence>
- Known: <confirmed inputs/dependencies>
- Unknown/risks: <what could go wrong or is unverified>
- Steps: <numbered list of what you'll do>
```

Only proceed after the plan is stated. This prevents mid-task drift.

---

## CONTEXT WINDOW — 1M TOKEN USAGE

You are operating with a 1M token context window. Use it correctly:

- **Do not re-summarize content that is already in context.** Reference it directly.
- **Do not repeat large blocks of code** unless the task explicitly requires it. Say "see above" or "as defined in `<file>`" instead.
- **When working across many files**, track which files have been modified in a running list at the end of your response: `Modified: [file1.cpp, file2.h]`
- **If a task references something earlier in the conversation**, go back and read it — do not reconstruct it from memory.
- **Prefer surgical edits** (show only changed lines + context) over rewriting entire files unless the full rewrite is explicitly requested.

---

## CODE GENERATION STANDARDS

### Output Format
- Always specify the language in fenced code blocks: ` ```cpp `, ` ```python `, etc.
- For edits to existing code, use diff-style output or clearly mark `// CHANGED`, `// ADDED`, `// REMOVED` inline comments.
- If the output is a full file, start with a comment block: `// File: <filename>` and `// Purpose: <one line>`

### Quality Rules
- Write code that compiles the first time. If you are uncertain about a compile-time detail, flag it with `// NOTE: verify this signature`.
- Prefer explicit over implicit. Do not rely on the reader inferring intent from code structure alone — add a brief inline comment on non-obvious logic.
- Match the existing codebase style. If the project uses snake_case, use snake_case. Do not impose preferences.
- Do not add unrequested features, refactors, or "while I'm here" changes. Do exactly what was asked.

### Multi-Step Code Tasks
- Complete each step fully before moving to the next.
- After each step, state: `Step N complete. Next: <what's next>.`
- If a step reveals new information that changes the plan, say so before continuing.

---

## TASK COMPREHENSION

DeepSeek V4 follows instructions literally. This is a feature, not a bug — but it requires the following discipline:

- **If a request is ambiguous**, ask one clarifying question before proceeding. Do not guess at intent.
- **If a request has multiple valid interpretations**, list them briefly and ask which is intended — or state which you are proceeding with and why.
- **Do not infer unstated requirements.** If the task says "fix this function," fix that function. Do not refactor adjacent code.
- **Short tasks get short answers.** Do not pad responses. Do not explain what you just did after doing it unless asked.

---

## ANTI-DRIFT (LONG SESSIONS)

In long sessions, models drift — they start solving a different problem than the one originally stated, or they begin introducing patterns from earlier in the conversation that are no longer relevant.

To prevent this:
- If a session has exceeded ~20 exchanges, re-read the original task before responding.
- If you notice your current response is solving something adjacent to what was asked, stop and restate what you believe the goal is.
- Do not carry assumptions forward from earlier failed attempts. Treat each retry as a clean slate unless told otherwise.

---

## UNCERTAINTY SIGNALING

Use these inline markers consistently:

| Marker | Meaning |
|---|---|
| `[UNVERIFIED]` | Signature or behavior not confirmed from context |
| `[ASSUMPTION]` | You are proceeding on an assumption — flag for user review |
| `[NEEDS CONFIRMATION]` | A decision point requiring user input before proceeding |
| `[RISKY]` | This change has side effects or could break something adjacent |

---

## TOOL USE & FILE OPERATIONS

- Before editing a file, state: `Editing: <filename>` and briefly why.
- After editing, state what changed, not the full file contents (unless full output was requested).
- Do not delete or overwrite files unless explicitly instructed.
- If a bash command could be destructive (rm, overwrite, drop table, etc.), show the command and wait for confirmation unless the user has explicitly said to proceed automatically.
- When running searches or reads, show what you found before acting on it.

---

## RESPONSE LENGTH

| Task Type | Response Style |
|---|---|
| Simple question | 1–3 sentences |
| Code fix / small edit | Code block + 1-line explanation |
| New feature / function | Plan block + code + brief notes |
| Architecture / design | Plan block + prose + code if needed |
| Debugging | Diagnosis first, then fix — not both at once |

Never pad. Never summarize what you just did in a closing paragraph. End when the task is done.

---

## PROJECT-SPECIFIC CONTEXT

> **Fill this section in per project. Examples below.**

```
Project: <name>
Language(s): <e.g. C++17, Python 3.11>
Build system: <e.g. CMake 3.28>
Key dependencies: <e.g. Unreal Engine 4.27, OpenCV 4.8>
Naming convention: <e.g. PascalCase classes, snake_case functions>
Do NOT modify: <e.g. /legacy/, auth module>
Test command: <e.g. pytest tests/ or make test>
Notes: <anything else the model should always know>
```

---

*This file is loaded automatically by Claude Code at session start. Keep it updated as the project evolves.*
'@

$CLAUDE_MD_CONTENT | Set-Content -Path "$CLAUDE_DIR\CLAUDE.md" -Encoding UTF8
Write-Host "  ✓ Global CLAUDE.md installed." -ForegroundColor Green

# ── CMD Wrapper ───────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  Writing wrapper scripts..." -ForegroundColor Cyan

# FIX: added setlocal enabledelayedexpansion so !line:~0,1! works correctly
# FIX: %~dp0 is reliable in .cmd when called via PATH — install dir is also
#      stored in config.env as DEEPSEEK_INSTALL_DIR for self-repair reference
@"
@echo off
setlocal enabledelayedexpansion

REM DeepSeek Claude Wrapper — CMD
REM Uses %~dp0 (dir of this .cmd) to locate node_modules — reliable via PATH

REM ── Sub-commands that don't need the API key ──────────────────────────────
if /i "%~1"=="set-model"   goto :run_ps
if /i "%~1"=="show-config" goto :run_ps
if /i "%~1"=="repair"      goto :repair

REM ── Update command ────────────────────────────────────────────────────────
if /i "%~1"=="update" (
    echo Updating @anthropic-ai/claude-code...
    pushd "%~dp0"
    call npm update @anthropic-ai/claude-code
    popd
    echo Done.
    exit /b 0
)

REM ── API key check ─────────────────────────────────────────────────────────
if "%DEEPSEEK_API_KEY%"=="" (
    echo.
    echo  Error: DEEPSEEK_API_KEY is not set.
    echo  Set it permanently:   setx DEEPSEEK_API_KEY your_key_here
    echo  Then restart your terminal.
    echo.
    exit /b 1
)

REM ── Read config.env ───────────────────────────────────────────────────────
set "DEEPSEEK_PRIMARY_MODEL=deepseek-v4-pro"
set "DEEPSEEK_SMALL_MODEL=deepseek-v4-flash"
set "DEEPSEEK_CONTEXT_LIMIT=1000000"

set "CONFIG_FILE=%~dp0config.env"
if exist "!CONFIG_FILE!" (
    for /f "usebackq tokens=1,* delims==" %%a in ("!CONFIG_FILE!") do (
        set "_k=%%a"
        set "_v=%%b"
        if not "!_k:~0,1!"=="#" if not "!_k!"=="" (
            set "!_k!=!_v!"
        )
    )
)

REM ── Verify claude binary exists ───────────────────────────────────────────
set "CLAUDE_BIN=%~dp0node_modules\.bin\claude.cmd"
if not exist "!CLAUDE_BIN!" (
    echo.
    echo  Error: claude binary not found at:
    echo    !CLAUDE_BIN!
    echo  Run 'deepseek-claude repair' or re-run the install script.
    echo.
    exit /b 1
)

REM ── Set DeepSeek environment vars and launch ──────────────────────────────
set "ANTHROPIC_BASE_URL=https://api.deepseek.com/anthropic"
set "ANTHROPIC_AUTH_TOKEN=%DEEPSEEK_API_KEY%"
set "ANTHROPIC_MODEL=%DEEPSEEK_PRIMARY_MODEL%"
set "ANTHROPIC_SMALL_FAST_MODEL=%DEEPSEEK_SMALL_MODEL%"
set "CLAUDE_CODE_MAX_CONTEXT_TOKENS=%DEEPSEEK_CONTEXT_LIMIT%"

"!CLAUDE_BIN!" %*
exit /b %ERRORLEVEL%

REM ── Repair: re-adds install dir to PATH and verifies binary ───────────────
:repair
echo.
echo  Repair: checking installation...
set "_idir=%~dp0"
set "_idir=!_idir:~0,-1!"
set "_cur_path=%PATH%"
echo !_cur_path! | findstr /i /c:"!_idir!" >nul
if errorlevel 1 (
    echo  PATH entry missing — re-adding: !_idir!
    powershell -NoProfile -Command ^
      "[Environment]::SetEnvironmentVariable('PATH', '!_idir!;' + [Environment]::GetEnvironmentVariable('PATH','User'), 'User')"
    echo  Done. Restart terminal for PATH to take effect.
) else (
    echo  PATH entry OK.
)
set "CLAUDE_BIN=%~dp0node_modules\.bin\claude.cmd"
if exist "!CLAUDE_BIN!" (
    echo  claude binary OK: !CLAUDE_BIN!
) else (
    echo  claude binary MISSING. Running npm install...
    pushd "%~dp0"
    call npm install @anthropic-ai/claude-code
    popd
)
echo.
exit /b 0

:run_ps
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0deepseek-claude.ps1" %*
exit /b %ERRORLEVEL%
"@ | Set-Content -Path "$INSTALL_DIR\$CMD_WRAPPER" -Encoding ASCII

# ── PowerShell Wrapper ────────────────────────────────────────────────────────
# FIX: $PSScriptRoot instead of $MyInvocation.MyCommand.Path (reliable in all contexts)
# FIX: empty-args splatting — use @() guard instead of $args[0..($args.Count-1)]
# FIX: repair command added matching CMD wrapper
@'
# DeepSeek Claude Wrapper — PowerShell
# Handles set-model / show-config / repair sub-commands
# Launched by deepseek-claude.cmd for those sub-commands

# FIX: $PSScriptRoot is always the directory containing this .ps1
#      $MyInvocation.MyCommand.Path breaks when called via CMD passthrough
$SCRIPT_DIR  = $PSScriptRoot
$CONFIG_FILE = Join-Path $SCRIPT_DIR "config.env"

$MODELS = @("deepseek-v4-pro", "deepseek-v4-flash", "deepseek-chat", "deepseek-reasoner")
$MODEL_DESCRIPTIONS = @(
    "DeepSeek V4 Pro   - Strongest model, complex reasoning + agent workflows",
    "DeepSeek V4 Flash - Fast and economical for cost-efficient production use",
    "DeepSeek Chat     - Legacy (maps to V4 Flash non-thinking mode)",
    "DeepSeek Reasoner - Legacy (maps to V4 Flash thinking mode)"
)
$CONTEXT_LIMITS = @("64000", "128000", "256000", "512000", "1000000")
$CONTEXT_DESCRIPTIONS = @(
    "64K   tokens",
    "128K  tokens",
    "256K  tokens",
    "512K  tokens",
    "1M    tokens (maximum — recommended for DeepSeek V4 Pro)"
)

function Read-Config {
    $cfg = @{
        DEEPSEEK_PRIMARY_MODEL  = "deepseek-v4-pro"
        DEEPSEEK_SMALL_MODEL    = "deepseek-v4-flash"
        DEEPSEEK_CONTEXT_LIMIT  = "1000000"
        DEEPSEEK_INSTALL_DIR    = $SCRIPT_DIR
    }
    if (Test-Path $CONFIG_FILE) {
        Get-Content $CONFIG_FILE | ForEach-Object {
            if ($_ -match '^([A-Z_]+)=(.+)$') {
                $cfg[$Matches[1]] = $Matches[2].Trim()
            }
        }
    }
    return $cfg
}

function Save-Config($cfg) {
    @"
# DeepSeek Claude Configuration
# Edit manually or run: deepseek-claude set-model
DEEPSEEK_PRIMARY_MODEL=$($cfg.DEEPSEEK_PRIMARY_MODEL)
DEEPSEEK_SMALL_MODEL=$($cfg.DEEPSEEK_SMALL_MODEL)
DEEPSEEK_CONTEXT_LIMIT=$($cfg.DEEPSEEK_CONTEXT_LIMIT)
DEEPSEEK_INSTALL_DIR=$SCRIPT_DIR
"@ | Set-Content -Path $CONFIG_FILE -Encoding UTF8
}

function Show-Config {
    $cfg = Read-Config
    Write-Host ""
    Write-Host "  DeepSeek Claude — Current Configuration" -ForegroundColor Cyan
    Write-Host "  ─────────────────────────────────────────" -ForegroundColor DarkCyan
    Write-Host "    Primary model  : $($cfg.DEEPSEEK_PRIMARY_MODEL)"  -ForegroundColor Green
    Write-Host "    Small model    : $($cfg.DEEPSEEK_SMALL_MODEL)"    -ForegroundColor Green
    Write-Host "    Context limit  : $($cfg.DEEPSEEK_CONTEXT_LIMIT) tokens" -ForegroundColor Green
    Write-Host "    Install dir    : $SCRIPT_DIR"  -ForegroundColor Gray
    Write-Host "    Config file    : $CONFIG_FILE" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  To change: deepseek-claude set-model" -ForegroundColor DarkCyan
    Write-Host ""
}

function Set-Model {
    $cfg = Read-Config
    Write-Host ""
    Write-Host "  ── Model Configuration ──────────────────────────────────────" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Current: $($cfg.DEEPSEEK_PRIMARY_MODEL) / $($cfg.DEEPSEEK_SMALL_MODEL) / $($cfg.DEEPSEEK_CONTEXT_LIMIT) tokens"
    Write-Host ""

    # Primary
    Write-Host "  PRIMARY model (complex tasks):" -ForegroundColor White
    for ($i = 0; $i -lt $MODELS.Count; $i++) {
        $mark = if ($MODELS[$i] -eq $cfg.DEEPSEEK_PRIMARY_MODEL) { " ◄ current" } else { "" }
        Write-Host "    $($i+1)) $($MODEL_DESCRIPTIONS[$i])$mark" -ForegroundColor Green
    }
    Write-Host ""
    do {
        $c = Read-Host "  Choice [1-$($MODELS.Count)] (Enter = keep current)"
        if ([string]::IsNullOrEmpty($c)) { break }
    } while ($c -notmatch '^[1-4]$')
    if (-not [string]::IsNullOrEmpty($c)) { $cfg.DEEPSEEK_PRIMARY_MODEL = $MODELS[[int]$c - 1] }
    Write-Host "  → $($cfg.DEEPSEEK_PRIMARY_MODEL)" -ForegroundColor Green
    Write-Host ""

    # Small/fast
    Write-Host "  SMALL/FAST model:" -ForegroundColor White
    for ($i = 0; $i -lt $MODELS.Count; $i++) {
        $mark = if ($MODELS[$i] -eq $cfg.DEEPSEEK_SMALL_MODEL) { " ◄ current" } else { "" }
        Write-Host "    $($i+1)) $($MODEL_DESCRIPTIONS[$i])$mark" -ForegroundColor Green
    }
    Write-Host ""
    do {
        $c = Read-Host "  Choice [1-$($MODELS.Count)] (Enter = keep current)"
        if ([string]::IsNullOrEmpty($c)) { break }
    } while ($c -notmatch '^[1-4]$')
    if (-not [string]::IsNullOrEmpty($c)) { $cfg.DEEPSEEK_SMALL_MODEL = $MODELS[[int]$c - 1] }
    Write-Host "  → $($cfg.DEEPSEEK_SMALL_MODEL)" -ForegroundColor Green
    Write-Host ""

    # Context
    Write-Host "  CONTEXT window limit:" -ForegroundColor White
    for ($i = 0; $i -lt $CONTEXT_LIMITS.Count; $i++) {
        $mark = if ($CONTEXT_LIMITS[$i] -eq $cfg.DEEPSEEK_CONTEXT_LIMIT) { " ◄ current" } else { "" }
        Write-Host "    $($i+1)) $($CONTEXT_DESCRIPTIONS[$i])$mark" -ForegroundColor Green
    }
    Write-Host ""
    do {
        $c = Read-Host "  Choice [1-$($CONTEXT_LIMITS.Count)] (Enter = keep current)"
        if ([string]::IsNullOrEmpty($c)) { break }
    } while ($c -notmatch '^[1-5]$')
    if (-not [string]::IsNullOrEmpty($c)) { $cfg.DEEPSEEK_CONTEXT_LIMIT = $CONTEXT_LIMITS[[int]$c - 1] }
    Write-Host "  → $($cfg.DEEPSEEK_CONTEXT_LIMIT) tokens" -ForegroundColor Green
    Write-Host ""

    Save-Config $cfg
    Write-Host "  ✓ Configuration saved." -ForegroundColor Green
    Write-Host ""
}

function Repair-Install {
    Write-Host ""
    Write-Host "  Repair: checking installation health..." -ForegroundColor Cyan

    # Re-add to PATH if missing
    $dir = $SCRIPT_DIR.TrimEnd('\')
    $userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
    $parts = $userPath -split ';' | Where-Object { $_ -ne '' } | ForEach-Object { $_.TrimEnd('\') }
    if ($parts -notcontains $dir) {
        Write-Host "  PATH entry missing — re-adding: $dir" -ForegroundColor Yellow
        $newPath = ($parts + $dir) -join ';'
        [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
        Write-Host "  ✓ PATH repaired. Restart terminal to apply." -ForegroundColor Green
    } else {
        Write-Host "  ✓ PATH OK." -ForegroundColor Green
    }

    # Verify binary
    $bin = Join-Path $SCRIPT_DIR "node_modules\.bin\claude.cmd"
    if (Test-Path $bin) {
        Write-Host "  ✓ claude binary OK." -ForegroundColor Green
    } else {
        Write-Host "  ✗ claude binary missing — running npm install..." -ForegroundColor Yellow
        Push-Location $SCRIPT_DIR
        & npm install @anthropic-ai/claude-code
        Pop-Location
        if (Test-Path $bin) {
            Write-Host "  ✓ Reinstalled successfully." -ForegroundColor Green
        } else {
            Write-Host "  ✗ Install failed. Check npm output above." -ForegroundColor Red
        }
    }
    Write-Host ""
}

# ── Main dispatch ─────────────────────────────────────────────────────────────
switch ($args[0]) {
    "set-model"   { Set-Model }
    "show-config" { Show-Config }
    "repair"      { Repair-Install }
    default {
        # Direct claude launch (not used via CMD wrapper normally, but supported)
        if (-not $env:DEEPSEEK_API_KEY) {
            Write-Host "  Error: DEEPSEEK_API_KEY not set." -ForegroundColor Red
            exit 1
        }
        $cfg = Read-Config
        $env:ANTHROPIC_BASE_URL              = "https://api.deepseek.com/anthropic"
        $env:ANTHROPIC_AUTH_TOKEN            = $env:DEEPSEEK_API_KEY
        $env:ANTHROPIC_MODEL                 = $cfg.DEEPSEEK_PRIMARY_MODEL
        $env:ANTHROPIC_SMALL_FAST_MODEL      = $cfg.DEEPSEEK_SMALL_MODEL
        $env:CLAUDE_CODE_MAX_CONTEXT_TOKENS  = $cfg.DEEPSEEK_CONTEXT_LIMIT

        $bin = Join-Path $SCRIPT_DIR "node_modules\.bin\claude.cmd"
        if (-not (Test-Path $bin)) {
            Write-Host "  Error: claude binary not found. Run: deepseek-claude repair" -ForegroundColor Red
            exit 1
        }

        # FIX: guard against empty $args before splatting — avoids reversed-array bug
        if ($args.Count -gt 0) {
            & $bin @args
        } else {
            & $bin
        }
    }
}
'@ | Set-Content -Path "$INSTALL_DIR\$PS_WRAPPER" -Encoding UTF8

Write-Host "  ✓ Wrapper scripts written." -ForegroundColor Green

# ── PATH Registration ─────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  Registering PATH..." -ForegroundColor Cyan
$added = Add-ToUserPath $INSTALL_DIR
if ($added) {
    Write-Host "  ✓ Added to user PATH." -ForegroundColor Green
    Write-Host "  ⚠  Restart your terminal for PATH to take effect." -ForegroundColor Yellow
} else {
    Write-Host "  ✓ Already in PATH." -ForegroundColor Green
}

# ── Summary ───────────────────────────────────────────────────────────────────
$finalCfg = @{}
Get-Content "$INSTALL_DIR\config.env" | ForEach-Object {
    if ($_ -match '^([A-Z_]+)=(.+)$') { $finalCfg[$Matches[1]] = $Matches[2].Trim() }
}

Write-Host ""
Write-Host "  ┌──────────────────────────────────────────────────────────────┐" -ForegroundColor Green
Write-Host "  │                  Installation Complete                       │" -ForegroundColor Green
Write-Host "  └──────────────────────────────────────────────────────────────┘" -ForegroundColor Green
Write-Host ""
Write-Host "  Configuration:" -ForegroundColor Cyan
Write-Host "    Primary model  : $($finalCfg.DEEPSEEK_PRIMARY_MODEL)" -ForegroundColor White
Write-Host "    Small model    : $($finalCfg.DEEPSEEK_SMALL_MODEL)"   -ForegroundColor White
Write-Host "    Context limit  : $($finalCfg.DEEPSEEK_CONTEXT_LIMIT) tokens" -ForegroundColor White
Write-Host "    Base URL       : https://api.deepseek.com/anthropic"   -ForegroundColor White
Write-Host "    Global CLAUDE.md: $CLAUDE_DIR\CLAUDE.md"              -ForegroundColor White
Write-Host ""
Write-Host "  Commands:" -ForegroundColor Cyan
Write-Host "    deepseek-claude               Start interactive session"    -ForegroundColor White
Write-Host "    deepseek-claude set-model     Change model / context"       -ForegroundColor White
Write-Host "    deepseek-claude show-config   View current config"          -ForegroundColor White
Write-Host "    deepseek-claude update        Update claude-code package"   -ForegroundColor White
Write-Host "    deepseek-claude repair        Fix PATH + reinstall binary"  -ForegroundColor White
Write-Host ""
Write-Host "  First time? Set your API key then restart terminal:" -ForegroundColor Yellow
Write-Host "    setx DEEPSEEK_API_KEY your_key_here" -ForegroundColor Yellow
Write-Host ""
