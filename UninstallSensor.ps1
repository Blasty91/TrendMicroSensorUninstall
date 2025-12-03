# Requires PowerShell 5.0 or later

# ==========================
# Configuratie
# ==========================

# Jouw (werkende) directe download-URL van OneDrive / SharePoint
$UninstallZipUrl     = "https://digitalebewakers-my.sharepoint.com/:u:/p/joris/IQBF69rerWm1QLxMXk3M1EekAezRrCsimPkGxHLMTTsh-bc?e=AS0x5g&download=1"

# Locaties voor download en extractie
$TempRoot            = $env:TEMP
$UninstallZipPath    = Join-Path $TempRoot "V1ESUninstallTool.zip"
$UninstallExtractDir = Join-Path $TempRoot "V1ESUninstallTool"

# ==========================
# Logging
# ==========================

$env:LogPath = "$env:APPDATA\Trend Micro\V1ES"
New-Item -Path $env:LogPath -ItemType Directory -Force | Out-Null

$LogFile = Join-Path $env:LogPath "v1es_uninstall.log"
Start-Transcript -Path $LogFile -Append

Write-Host "$(Get-Date -format T) Start uninstalling Trend Micro Endpoint Sensor."

# ==========================
# Pre-checks
# ==========================

# Admin check
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "$(Get-Date -format T) You are not running as an Administrator. Please try again with admin privileges." -ForegroundColor Red
    Stop-Transcript
    exit 1
}

# Check Invoke-WebRequest
if (-not (Get-Command Invoke-WebRequest -ErrorAction SilentlyContinue)) {
    Write-Host "$(Get-Date -format T) Invoke-WebRequest is not available. Please install PowerShell 3.0 or later." -ForegroundColor Red
    Stop-Transcript
    exit 1
}

# Check Expand-Archive
if (-not (Get-Command Expand-Archive -ErrorAction SilentlyContinue)) {
    Write-Host "$(Get-Date -format T) Expand-Archive is not available. Please install PowerShell 5.0 or later." -ForegroundColor Red
    Stop-Transcript
    exit 1
}

# TLS 1.2 forceren (vaak nodig bij OneDrive/modern HTTPS)
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
} catch {
    Write-Host "$(Get-Date -format T) Could not set TLS 1.2 explicitly: $($_.Exception.Message)" -ForegroundColor Yellow
}

# ==========================
# Download van V1ESUninstallTool.zip
# ==========================

Write-Host "$(Get-Date -format T) Downloading V1ESUninstallTool from $UninstallZipUrl"

try {
    if (Test-Path $UninstallZipPath) {
        Remove-Item -Path $UninstallZipPath -Force -ErrorAction SilentlyContinue
    }

    $response = Invoke-WebRequest -Uri $UninstallZipUrl -OutFile $UninstallZipPath -UseBasicParsing -PassThru

    if ($response.StatusCode -ge 400) {
        Write-Host "$(Get-Date -format T) HTTP error while downloading: $($response.StatusCode) $($response.StatusDescription)" -ForegroundColor Red
        Stop-Transcript
        exit 1
    }

    if (-not (Test-Path $UninstallZipPath)) {
        Write-Host "$(Get-Date -format T) Failed to download V1ESUninstallTool.zip. File not found after download." -ForegroundColor Red
        Stop-Transcript
        exit 1
    }

    Write-Host "$(Get-Date -format T) Downloaded V1ESUninstallTool.zip to $UninstallZipPath" -ForegroundColor White
} catch {
    Write-Host "$(Get-Date -format T) Exception while downloading V1ESUninstallTool.zip: $($_.Exception.Message)" -ForegroundColor Red
    Stop-Transcript
    exit 1
}

# ==========================
# Uitpakken van de ZIP
# ==========================

Write-Host "$(Get-Date -format T) Extracting V1ESUninstallTool.zip to $UninstallExtractDir"

try {
    if (Test-Path $UninstallExtractDir) {
        Remove-Item -Path $UninstallExtractDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    Expand-Archive -Path $UninstallZipPath -DestinationPath $UninstallExtractDir -Force

    Write-Host "$(Get-Date -format T) Extraction completed." -ForegroundColor White
} catch {
    Write-Host "$(Get-Date -format T) Failed to extract V1ESUninstallTool.zip: $($_.Exception.Message)" -ForegroundColor Red
    Stop-Transcript
    exit 1
}

# ==========================
# Auto-detect uninstaller + token
# ==========================

Write-Host "$(Get-Date -format T) Searching for V1ES uninstaller and token file..." -ForegroundColor White

# Zoek recursief naar een EXE die lijkt op V1ESUninstall*.exe
$UninstallExe = Get-ChildItem -Path $UninstallExtractDir -Recurse -File |
    Where-Object { $_.Name -match '^V1ESUninstall.*\.exe$' } |
    Select-Object -First 1

# Zoek recursief naar een tokenfile die lijkt op V1ESUninstallToken*.txt
$TokenFile = Get-ChildItem -Path $UninstallExtractDir -Recurse -File |
    Where-Object { $_.Name -match '^V1ESUninstallToken.*\.txt$' } |
    Select-Object -First 1

if (-not $UninstallExe) {
    Write-Host "$(Get-Date -format T) Could not find a file matching 'V1ESUninstall*.exe' in $UninstallExtractDir." -ForegroundColor Red
    Write-Host "$(Get-Date -format T) Available .exe files:" -ForegroundColor Yellow

    Get-ChildItem -Path $UninstallExtractDir -Recurse -File -Filter *.exe |
        ForEach-Object { Write-Host " - $($_.FullName)" -ForegroundColor Yellow }

    Stop-Transcript
    exit 1
}

if (-not $TokenFile) {
    Write-Host "$(Get-Date -format T) Could not find a file matching 'V1ESUninstallToken*.txt' in $UninstallExtractDir." -ForegroundColor Red
    Write-Host "$(Get-Date -format T) Available .txt files:" -ForegroundColor Yellow

    Get-ChildItem -Path $UninstallExtractDir -Recurse -File -Filter *.txt |
        ForEach-Object { Write-Host " - $($_.FullName)" -ForegroundColor Yellow }

    Stop-Transcript
    exit 1
}

$UninstallExePath = $UninstallExe.FullName
$TokenFilePath    = $TokenFile.FullName

Write-Host "$(Get-Date -format T) Using uninstaller: $UninstallExePath" -ForegroundColor White
Write-Host "$(Get-Date -format T) Using token file: $TokenFilePath" -ForegroundColor White

# Optionele digitale handtekening-check
try {
    $sig = Get-AuthenticodeSignature -FilePath $UninstallExePath
    if ($sig.Status -ne "Valid") {
        Write-Host "$(Get-Date -format T) Digital signature of '$UninstallExePath' is not valid: $($sig.Status)." -ForegroundColor Yellow
        # Desnoods hier exit 1 doen als je het hard wil afdwingen
    }
} catch {
    Write-Host "$(Get-Date -format T) Unable to check digital signature: $($_.Exception.Message)" -ForegroundColor Yellow
}

# ==========================
# Uninstall uitvoeren
# ==========================

Write-Host "$(Get-Date -format T) Running V1ES uninstaller."

# Pas dit aan op basis van Trend Micro documentatie:
$UninstallArguments = @(
    "/tokenfile:`"$TokenFilePath`""
    "/silent"
)

try {
    $process = Start-Process -FilePath $UninstallExePath `
                             -ArgumentList $UninstallArguments `
                             -Wait `
                             -PassThru

    $exitCode = $process.ExitCode
    Write-Host "$(Get-Date -format T) Uninstaller finished with exit code $exitCode."

    if ($exitCode -ne 0) {
        Write-Host "$(Get-Date -format T) Uninstall failed. Please check Trend Micro logs or the portal for details." -ForegroundColor Red
        Stop-Transcript
        exit $exitCode
    }
} catch {
    Write-Host "$(Get-Date -format T) Exception while running uninstaller: $($_.Exception.Message)" -ForegroundColor Red
    Stop-Transcript
    exit 1
}

# ==========================
# Cleanup (optioneel)
# ==========================

try {
    if (Test-Path $UninstallZipPath) {
        Remove-Item -Path $UninstallZipPath -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path $UninstallExtractDir) {
        Remove-Item -Path $UninstallExtractDir -Recurse -Force -ErrorAction SilentlyContinue
    }
} catch {
    Write-Host "$(Get-Date -format T) Cleanup failed: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host "$(Get-Date -format T) Uninstall procedure completed. Please verify sensor removal if required." -ForegroundColor White

Stop-Transcript
exit 0
