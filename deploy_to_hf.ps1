<#
deploy_to_hf.ps1

Usage (PowerShell):
  - Open PowerShell and run from the folder that contains this repo (e.g. C:\Users\Lenovo\Desktop\chess)
  - Optionally set environment variable HF_TOKEN with your Hugging Face access token to avoid interactive prompt.

Example:
  $env:HF_TOKEN = 'hf_XXXXXXXX...'
  .\deploy_to_hf.ps1 -HFUser Anil1515 -HFSpace chess-frontend

This script will:
  - Clone (or update) the Space repo
  - Mirror your local Flutter `build/web` into the repo `web/` folder
  - Copy `Dockerfile` and `nginx.conf` from the local project root into the repo
  - Commit and push changes to the Space

IMPORTANT: When asked for Git credentials, use your Hugging Face username and an access token
as the password (create one at https://huggingface.co/settings/tokens).
#>

param(
    [string]$HFUser = "Anil1515",
    [string]$HFSpace = "chess-frontend",
  [string]$LocalBuild = "$PSScriptRoot\build\web"
)

function Abort($msg){ Write-Host "ERROR: $msg" -ForegroundColor Red; exit 1 }

if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Abort 'git is not installed or not in PATH.' }

$repoUrl = "https://huggingface.co/spaces/$HFUser/$HFSpace"
Write-Host "Target repo: $repoUrl"
if (-not (Test-Path $LocalBuild)) { Abort "Local build folder not found: $LocalBuild. Run 'flutter build web' first." }

# Decide the absolute path where the Space repo should live (next to the script)
$scriptRelative = Join-Path $PSScriptRoot $HFSpace
$workspaceRoot = Split-Path $PSScriptRoot -Parent
$workspaceRelative = Join-Path $workspaceRoot $HFSpace

# Prefer an existing repo at workspace root (where you previously cloned), else use script-relative
if (Test-Path $workspaceRelative) {
  $targetRepoPath = $workspaceRelative
} else {
  $targetRepoPath = $scriptRelative
}

if (Test-Path $targetRepoPath) {
  Write-Host "Updating existing repo folder $targetRepoPath..."
  Push-Location $targetRepoPath
  git pull
  Pop-Location
} else {
  Write-Host "Cloning $repoUrl into $targetRepoPath..."
  git clone $repoUrl $targetRepoPath
  if ($LASTEXITCODE -ne 0) { Abort 'git clone failed. Check the repo URL and your network.' }
}

Push-Location $targetRepoPath

# Mirror build output into repo web/
if (Test-Path .\web) { Write-Host 'Removing existing web/ in repo...'; Remove-Item -Recurse -Force .\web }

Write-Host "Copying build output from $LocalBuild to repo web/ (this may take a moment)..."
robocopy $LocalBuild .\web /MIR | Out-Null
if ($LASTEXITCODE -ge 8) { Abort 'robocopy failed copying files.' }

# Copy Docker/nginx if they exist in local project
if (Test-Path "$PSScriptRoot\Dockerfile") {
  Copy-Item "$PSScriptRoot\Dockerfile" -Destination . -Force
}
if (Test-Path "$PSScriptRoot\nginx.conf") {
  Copy-Item "$PSScriptRoot\nginx.conf" -Destination . -Force
}

Write-Host 'Staging files for commit...'
git add .

Write-Host 'Committing changes...'
# Try to commit; if there are no staged changes git will exit non-zero.
# Prevent git from launching an editor for commit messages (avoid Notepad popping up)
$env:GIT_TERMINAL_PROMPT = "0"
$commitOutput = git -c core.editor=true commit -m "Deploy Flutter web (automated)" 2>&1
if ($LASTEXITCODE -ne 0) {
  Write-Host "git commit returned code $LASTEXITCODE; message:`n$commitOutput" -ForegroundColor Yellow
  Write-Host "(This usually means there were no changes to commit.)"
} else {
  Write-Host "Commit successful." -ForegroundColor Green
}

Write-Host "About to push to $repoUrl"
Write-Host 'If push fails due to credentials, the script will show the error message.'

# Disable interactive credential prompts in terminal to avoid external GUI editors/dialogs opening
$env:GIT_TERMINAL_PROMPT = "0"
$pushOutput = git push 2>&1
if ($LASTEXITCODE -ne 0) {
  Write-Host "git push failed (code $LASTEXITCODE):`n$pushOutput" -ForegroundColor Red
  Abort 'git push failed. Ensure your HF credentials are configured (hf auth login) or provide a token via Windows credential manager.'
}

Write-Host 'Push complete. Open your Space page and check Logs -> Build / Container.' -ForegroundColor Green

Pop-Location
