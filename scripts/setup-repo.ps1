[CmdletBinding()]
param(
    [switch]$SkipPathRegistration
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$env:PYTHONDONTWRITEBYTECODE = '1'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$ToolsRoot = Join-Path $RepoRoot 'tools'
$DownloadRoot = Join-Path $ToolsRoot 'downloads'
$PythonRoot = Join-Path $RepoRoot '.venv'
$PythonExe = Join-Path $PythonRoot 'python.exe'
$PrismRoot = Join-Path $ToolsRoot 'prism-cuda'
$PrismServer = Join-Path $PrismRoot 'llama-server.exe'
$RequirementsFile = Join-Path $RepoRoot 'requirements.txt'
$PythonVersion = '3.13.16'
$PythonArchiveName = "python-$PythonVersion-embed-amd64.zip"
$PythonArchiveUrl = "https://www.python.org/ftp/python/$PythonVersion/$PythonArchiveName"
$PythonArchiveSha256 = '97dae5274cc54867065e8d5a3226e48c35017ed332a0fdb0e27d5b5821961297'
$PipVersion = '26.2.1'
$PipArchiveName = "pip-$PipVersion-py3-none-any.zip"
$PipArchiveSha256 = '71138adf1f4ca900cdb7d289c21b7494329f2332b6d85f0e1c42108c0384ed3e'
$PrismRelease = 'prism-b10709-9a9394a'
$PrismReleaseUrl = "https://github.com/PrismML-Eng/llama.cpp/releases/download/$PrismRelease"
$PrismArchiveName = 'llama-prism-b10709-9a9394a-bin-win-cuda-12.4-x64.zip'
$PrismArchiveSha256 = 'F565C8428C1F108311F65ED97F02425188B3AA3C745C2BC597521BBD24BCBBC9'
$CudaArchiveName = 'cudart-llama-bin-win-cuda-12.4-x64.zip'
$CudaArchiveSha256 = '8C79A9B226DE4B3CACFD1F83D24F962D0773BE79F1E7B75C6AF4DED7E32AE1D6'

function Get-Sha256 {
    param([Parameter(Mandatory = $true)][string]$Path)
    $Stream = [IO.File]::OpenRead($Path)
    $Algorithm = [Security.Cryptography.SHA256]::Create()
    try {
        $HashBytes = $Algorithm.ComputeHash($Stream)
        return ([BitConverter]::ToString($HashBytes)).Replace('-', '').ToUpperInvariant()
    } finally {
        $Algorithm.Dispose()
        $Stream.Dispose()
    }
}

function Get-VerifiedDownload {
    param(
        [Parameter(Mandatory = $true)][string]$Uri,
        [Parameter(Mandatory = $true)][string]$Destination,
        [Parameter(Mandatory = $true)][string]$ExpectedSha256
    )

    if (Test-Path -LiteralPath $Destination -PathType Leaf) {
        if ((Get-Sha256 -Path $Destination) -eq $ExpectedSha256.ToUpperInvariant()) {
            return $Destination
        }
        Write-Warning "Ignoring a cached file with an unexpected checksum: $Destination"
    }

    $PartialPath = "$Destination.partial"
    if (Test-Path -LiteralPath $PartialPath -PathType Leaf) {
        if ((Get-Sha256 -Path $PartialPath) -eq $ExpectedSha256.ToUpperInvariant()) {
            Move-Item -LiteralPath $PartialPath -Destination $Destination -Force
            return $Destination
        }
    }
    Write-Host "Downloading $([IO.Path]::GetFileName($Destination)) ..."
    Invoke-WebRequest -Uri $Uri -OutFile $PartialPath -UseBasicParsing -TimeoutSec 3600
    $ActualSha256 = Get-Sha256 -Path $PartialPath
    if ($ActualSha256 -ne $ExpectedSha256.ToUpperInvariant()) {
        throw "SHA-256 mismatch for $Uri. Expected $ExpectedSha256; received $ActualSha256."
    }
    Move-Item -LiteralPath $PartialPath -Destination $Destination -Force
    return $Destination
}

function Get-VerifiedAsset {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Uri,
        [Parameter(Mandatory = $true)][string]$ExpectedSha256
    )

    $DownloadedAsset = Join-Path $DownloadRoot $Name
    return Get-VerifiedDownload -Uri $Uri -Destination $DownloadedAsset -ExpectedSha256 $ExpectedSha256
}

function Add-RepositoryToUserPath {
    $UserPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $PathEntries = @()
    if (-not [string]::IsNullOrWhiteSpace($UserPath)) {
        $PathEntries = @($UserPath -split ';' | ForEach-Object { $_.Trim().Trim('"').TrimEnd('\') })
    }
    $NormalizedRoot = $RepoRoot.TrimEnd('\')
    $AlreadyRegistered = $PathEntries | Where-Object { $_ -ieq $NormalizedRoot }
    if (-not $AlreadyRegistered) {
        $NewUserPath = if ([string]::IsNullOrWhiteSpace($UserPath)) { $RepoRoot } else { "$UserPath;$RepoRoot" }
        if ($NewUserPath.Length -gt 30000) {
            throw 'The user PATH is too long to safely add this repository.'
        }
        [Environment]::SetEnvironmentVariable('Path', $NewUserPath, 'User')
        Write-Host 'Added the repository root to the user PATH.'
    } else {
        Write-Host 'The repository root is already present in the user PATH.'
    }

    if (-not (@($env:Path -split ';') | Where-Object { $_.Trim().Trim('"').TrimEnd('\') -ieq $NormalizedRoot })) {
        $env:Path = "$env:Path;$RepoRoot"
    }
}

try {
    if ($env:OS -ne 'Windows_NT' -or -not [Environment]::Is64BitOperatingSystem) {
        throw 'This setup currently requires 64-bit Windows.'
    }
    foreach ($RequiredFile in @('bn.py', 'bn.cmd', 'requirements.txt')) {
        if (-not (Test-Path -LiteralPath (Join-Path $RepoRoot $RequiredFile) -PathType Leaf)) {
            throw "Required source file is missing: $RequiredFile"
        }
    }
    if (-not (Test-Path -LiteralPath (Join-Path $RepoRoot '.instructions\bn-instructions.md') -PathType Leaf)) {
        throw 'Required system instructions are missing: .instructions\bn-instructions.md'
    }

    $DriveRoot = [IO.Path]::GetPathRoot($RepoRoot)
    $FreeBytes = ([IO.DriveInfo]::new($DriveRoot)).AvailableFreeSpace
    if ($FreeBytes -lt 9GB) {
        throw ('At least 9 GiB of free space is recommended; {0:N2} GiB is available.' -f ($FreeBytes / 1GB))
    }

    New-Item -ItemType Directory -Path $ToolsRoot, $DownloadRoot, $PythonRoot, $PrismRoot, (Join-Path $RepoRoot 'bonsai_env') -Force | Out-Null

    $PythonVersionText = ''
    if (Test-Path -LiteralPath $PythonExe -PathType Leaf) {
        $PythonVersionText = (& $PythonExe --version 2>&1 | Out-String).Trim()
    }
    if ($PythonVersionText -ne "Python $PythonVersion") {
        $PythonArchive = Get-VerifiedDownload -Uri $PythonArchiveUrl -Destination (Join-Path $DownloadRoot $PythonArchiveName) -ExpectedSha256 $PythonArchiveSha256
        Expand-Archive -Path $PythonArchive -DestinationPath $PythonRoot -Force
    } else {
        Write-Host "Portable Python $PythonVersion is already installed."
    }
    if (-not (Test-Path -LiteralPath $PythonExe -PathType Leaf)) {
        throw "The embedded Python archive did not create the expected interpreter: $PythonExe"
    }

    $PythonPth = Join-Path $PythonRoot 'python313._pth'
    $PythonStdlib = Join-Path $PythonRoot 'python313.zip'
    if (-not (Test-Path -LiteralPath $PythonPth -PathType Leaf) -or -not (Test-Path -LiteralPath $PythonStdlib -PathType Leaf)) {
        throw 'The embedded Python archive is missing its expected path configuration or standard library.'
    }
    $PthLines = @(Get-Content -LiteralPath $PythonPth | Where-Object { $_ -ne 'Lib\site-packages' -and $_ -ne 'import site' })
    $PthLines += 'Lib\site-packages'
    $PthLines += 'import site'
    [IO.File]::WriteAllLines($PythonPth, $PthLines, [Text.Encoding]::ASCII)

    $PythonVersionText = (& $PythonExe --version 2>&1 | Out-String).Trim()
    if ($PythonVersionText -ne "Python $PythonVersion") {
        throw "Unexpected Python version: $PythonVersionText"
    }

    $SitePackages = Join-Path $PythonRoot 'Lib\site-packages'
    New-Item -ItemType Directory -Path $SitePackages -Force | Out-Null
    $BytecodePolicyFile = Join-Path $SitePackages 'disable-bytecode.pth'
    [IO.File]::WriteAllText($BytecodePolicyFile, "import sys; sys.dont_write_bytecode = True`r`n", [Text.Encoding]::ASCII)
    $BytecodeDisabled = (& $PythonExe -c "import sys; print(sys.dont_write_bytecode)" 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or $BytecodeDisabled -ne 'True') {
        throw 'The portable Python runtime did not disable bytecode writes.'
    }
    $PipMetadataDirectory = Join-Path $SitePackages "pip-$PipVersion.dist-info"
    if (-not (Test-Path -LiteralPath $PipMetadataDirectory -PathType Container)) {
        $PipMetadata = Invoke-RestMethod -Uri "https://pypi.org/pypi/pip/$PipVersion/json" -TimeoutSec 60
        $PipWheel = $PipMetadata.urls | Where-Object { $_.filename -eq "pip-$PipVersion-py3-none-any.whl" } | Select-Object -First 1
        if (-not $PipWheel -or $PipWheel.digests.sha256 -ne $PipArchiveSha256) {
            throw 'The pinned pip wheel metadata did not match its expected SHA-256.'
        }
        $PipArchive = Get-VerifiedDownload -Uri $PipWheel.url -Destination (Join-Path $DownloadRoot $PipArchiveName) -ExpectedSha256 $PipArchiveSha256
        Expand-Archive -Path $PipArchive -DestinationPath $SitePackages -Force
    }

    $PreviousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $PipVersionText = (& $PythonExe -m pip --version 2>&1 | Out-String).Trim()
    $PipExitCode = $LASTEXITCODE
    $ErrorActionPreference = $PreviousErrorActionPreference
    if ($PipExitCode -ne 0 -or $PipVersionText -notmatch "pip $([regex]::Escape($PipVersion))") {
        throw "Could not bootstrap pip from the pinned embedded wheel: $PipVersionText"
    }

    $HubMetadataDirectory = Join-Path $SitePackages 'huggingface_hub-1.32.0.dist-info'
    if (-not (Test-Path -LiteralPath $HubMetadataDirectory -PathType Container)) {
        Write-Host 'Installing the pinned Python dependencies ...'
        $ErrorActionPreference = 'Continue'
        & $PythonExe -m pip install --disable-pip-version-check --requirement $RequirementsFile
        $PipExitCode = $LASTEXITCODE
        $ErrorActionPreference = $PreviousErrorActionPreference
        if ($PipExitCode -ne 0) { throw "Python package installation failed with exit code $PipExitCode." }
    }
    $ErrorActionPreference = 'Continue'
    & $PythonExe -c "import huggingface_hub; print('huggingface_hub', huggingface_hub.__version__)"
    $HubImportExitCode = $LASTEXITCODE
    $ErrorActionPreference = $PreviousErrorActionPreference
    if ($HubImportExitCode -ne 0) {
        throw 'huggingface_hub could not be imported by the portable Python runtime.'
    }

    $PrismVersion = ''
    $PreviousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    if (Test-Path -LiteralPath $PrismServer -PathType Leaf) {
        $PrismVersion = (& $PrismServer --version 2>&1 | Out-String).Trim()
        $PrismExitCode = $LASTEXITCODE
    } else {
        $PrismExitCode = 1
    }
    $ErrorActionPreference = $PreviousErrorActionPreference
    if ($PrismExitCode -ne 0 -or $PrismVersion -notmatch 'build 10709, commit 9a9394a89') {
        $PrismArchive = Get-VerifiedAsset -Name $PrismArchiveName -Uri "$PrismReleaseUrl/$PrismArchiveName" -ExpectedSha256 $PrismArchiveSha256
        $CudaArchive = Get-VerifiedAsset -Name $CudaArchiveName -Uri "$PrismReleaseUrl/$CudaArchiveName" -ExpectedSha256 $CudaArchiveSha256
        Expand-Archive -Path $PrismArchive -DestinationPath $PrismRoot -Force
        Expand-Archive -Path $CudaArchive -DestinationPath $PrismRoot -Force
        if (-not (Test-Path -LiteralPath $PrismServer -PathType Leaf)) {
            throw "The Prism archive did not contain llama-server.exe at the expected path: $PrismServer"
        }
        $ErrorActionPreference = 'Continue'
        $PrismVersion = (& $PrismServer --version 2>&1 | Out-String).Trim()
        $PrismExitCode = $LASTEXITCODE
        $ErrorActionPreference = $PreviousErrorActionPreference
        if ($PrismExitCode -ne 0 -or $PrismVersion -notmatch 'build 10709, commit 9a9394a89') {
            throw "The Prism runtime failed its version check: $PrismVersion"
        }
    } else {
        Write-Host 'The pinned Prism CUDA runtime is already installed.'
    }

    $ErrorActionPreference = 'Continue'
    $DeviceList = (& $PrismServer --list-devices 2>&1 | Out-String).Trim()
    $DeviceExitCode = $LASTEXITCODE
    $ErrorActionPreference = $PreviousErrorActionPreference
    if ($DeviceExitCode -eq 0 -and $DeviceList -match 'CUDA\d+:') {
        Write-Host $DeviceList
    } else {
        Write-Warning "The Prism runtime did not report a CUDA device. The model can still run on CPU, but GPU acceleration may be unavailable. $DeviceList"
    }

    $BnSourceFile = Join-Path $RepoRoot 'bn.py'
    $ConfiguredDefault = (& $PythonExe -c "import runpy,sys; print(runpy.run_path(sys.argv[1])['DEFAULT_MODEL_TAG'])" $BnSourceFile 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or $ConfiguredDefault -ne 'bn15') {
        throw "The application default model must remain bn15; found '$ConfiguredDefault'."
    }
    & $PythonExe (Join-Path $RepoRoot 'bn.py') pull bn15
    if ($LASTEXITCODE -ne 0) {
        throw "The default bn15 model download/verification failed with exit code $LASTEXITCODE."
    }

    if (-not $SkipPathRegistration) {
        Add-RepositoryToUserPath
    }

    Write-Host ''
    Write-Host 'Setup completed.'
    Write-Host 'Default model: bn15 (installed).'
    Write-Host 'Optional model bn17 is not pulled automatically; use: bn pull bn17'
    Write-Host 'Start chatting with: bn'
    if (-not $SkipPathRegistration) {
        Write-Host 'Open a new terminal before using the bn command from another directory.'
    }
} catch {
    [Console]::Error.WriteLine("[ERROR] $($_.Exception.Message)")
    exit 1
}
