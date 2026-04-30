# jobescape-qa plugin installer (Windows / PowerShell)
# Mirror of install.sh — clones the executor, installs deps, downloads Chromium.
# Idempotent — re-running is safe.

$ErrorActionPreference = "Stop"

$ExecutorDir = Join-Path $env:USERPROFILE "jobescape-auto-qa"
$ExecutorRepo = "https://github.com/Yelnur-Zeken/jobescape-auto-qa.git"

Write-Host "▶ jobescape-qa plugin installer (Windows)"
Write-Host ""

# Quick prereq check
foreach ($cmd in @("git", "node", "npm")) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        Write-Host "✗ Required command not found: $cmd" -ForegroundColor Red
        Write-Host "  Install: git from https://git-scm.com/, node ≥20 from https://nodejs.org/"
        exit 1
    }
}

if (-not (Test-Path $ExecutorDir)) {
    Write-Host "  · Cloning executor → $ExecutorDir"
    git clone $ExecutorRepo $ExecutorDir
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} else {
    Write-Host "  · Executor exists at $ExecutorDir — pulling latest"
    Push-Location $ExecutorDir
    try {
        git pull --rebase --autostash
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    } finally {
        Pop-Location
    }
}

Write-Host "  · npm install in $ExecutorDir"
Push-Location $ExecutorDir
try {
    npm install --silent
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    Write-Host "  · Installing Chromium (Playwright)"
    npx playwright install chromium
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    $envFile = Join-Path $ExecutorDir ".env"
    $envExample = Join-Path $ExecutorDir ".env.example"
    if (-not (Test-Path $envFile) -and (Test-Path $envExample)) {
        Copy-Item $envExample $envFile
        Write-Host "  · Created .env from .env.example"
    }
} finally {
    Pop-Location
}

Write-Host ""
Write-Host "✓ Installed." -ForegroundColor Green
Write-Host ""
Write-Host "Try it:"
Write-Host "  In Claude Code, type: /qa-upsell u13.0.4 4-week solidgate"
Write-Host "  Or describe naturally: 'QA upsell u15.4.3 on Solidgate, 4-week'"
