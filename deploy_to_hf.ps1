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
    [string]$LocalBuild = "$PSScriptRoot\chess-main\build\web"
)

function Abort($msg){ Write-Host "ERROR: $msg" -ForegroundColor Red; exit 1 }

if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Abort 'git is not installed or not in PATH.' }

$repoUrl = "https://huggingface.co/spaces/$HFUser/$HFSpace"
Write-Host "Target repo: $repoUrl"

if (-not (Test-Path $LocalBuild)) { Abort "Local build folder not found: $LocalBuild. Run 'flutter build web' first." }

# Clone or update repo
if (-not (Test-Path "$PSScriptRoot\$HFSpace")) {
    Write-Host "Cloning $repoUrl..."
    git clone $repoUrl $HFSpace
    if ($LASTEXITCODE -ne 0) { Abort 'git clone failed. Check the repo URL and your network.' }
} else {
    Write-Host "Updating existing repo folder $HFSpace..."
    Push-Location $HFSpace
    git pull
    Pop-Location
}

Push-Location $HFSpace

# Mirror build output into repo web/
if (Test-Path .\web) { Write-Host 'Removing existing web/ in repo...'; Remove-Item -Recurse -Force .\web }

Write-Host "Copying build output from $LocalBuild to repo web/ (this may take a moment)..."
robocopy $LocalBuild .\web /MIR | Out-Null
if ($LASTEXITCODE -ge 8) { Abort 'robocopy failed copying files.' }

# Copy Docker/nginx if they exist in local project
if (Test-Path "$PSScriptRoot\chess-main\Dockerfile") {
    Copy-Item "$PSScriptRoot\chess-main\Dockerfile" -Destination . -Force
}
if (Test-Path "$PSScriptRoot\chess-main\nginx.conf") {
    Copy-Item "$PSScriptRoot\chess-main\nginx.conf" -Destination . -Force
}

Write-Host 'Staging files for commit...'
git add .

Write-Host 'Committing changes...'
git commit -m "Deploy Flutter web (automated)" 2>$null

Write-Host "About to push to $repoUrl"
Write-Host 'When prompted for username: enter your Hugging Face username.'
Write-Host 'When prompted for password: paste your Hugging Face access token.'

git push
if ($LASTEXITCODE -ne 0) { Abort 'git push failed. If prompted for credentials, use HF username and token as password.' }

Write-Host 'Push complete. Open your Space page and check Logs -> Build / Container.' -ForegroundColor Green

Pop-Location
