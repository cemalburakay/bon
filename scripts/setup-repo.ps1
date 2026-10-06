[CmdletBinding()]
param(
    [switch]$SkipPathRegistration,
    [switch]$AcceptNvidiaCudaLicense
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$env:PYTHONDONTWRITEBYTECODE = '1'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$ToolsRoot = Join-Path $RepoRoot 'tools'
$ToolLockPath = Join-Path $ToolsRoot 'tool-lock.json'
try {
    $ToolLock = Get-Content -LiteralPath $ToolLockPath -Raw -Encoding UTF8 | ConvertFrom-Json
} catch {
    [Console]::Error.WriteLine("[ERROR] Could not read tool lock: $ToolLockPath ($($_.Exception.Message))")
    exit 1
}
$DownloadRoot = Join-Path $ToolsRoot $ToolLock.layout.download_dir
$PythonRoot = Join-Path $ToolsRoot $ToolLock.layout.python_dir
$PythonExe = Join-Path $PythonRoot 'python.exe'
$VenvRoot = Join-Path $RepoRoot '.venv'
$VenvPythonExe = Join-Path $VenvRoot 'Scripts\python.exe'
$PrismRoot = Join-Path $ToolsRoot $ToolLock.layout.runtime_dir
$PrismServer = Join-Path $PrismRoot $ToolLock.runtime.server_executable
$PythonVersion = $ToolLock.python.version
$PythonArchiveName = $ToolLock.python.embedded_archive
$PythonArchiveUrl = "https://www.python.org/ftp/python/$PythonVersion/$PythonArchiveName"
$PythonArchiveSha256 = $ToolLock.python.sha256
$PipVersion = $ToolLock.pip.version
$PipArchiveName = $ToolLock.pip.archive_name
$PipWheelName = $ToolLock.pip.wheel
$PipArchiveSha256 = $ToolLock.pip.sha256
$PrismRelease = $ToolLock.runtime.release
$PrismReleaseUrl = "https://github.com/$($ToolLock.runtime.repository)/releases/download/$PrismRelease"

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
    foreach ($RequiredFile in @('bon.cmd', 'setup-repo.cmd', 'tools\tool-lock.json')) {
        if (-not (Test-Path -LiteralPath (Join-Path $RepoRoot $RequiredFile) -PathType Leaf)) {
            throw "Required source file is missing: $RequiredFile"
        }
    }
    $BonSourceFile = Join-Path (Join-Path $RepoRoot $ToolLock.layout.scripts_dir) 'bon.py'
    if (-not (Test-Path -LiteralPath $BonSourceFile -PathType Leaf)) {
        throw "Required application source is missing: $BonSourceFile"
    }
    $InstructionsPath = Join-Path (Join-Path $RepoRoot $ToolLock.layout.instructions_dir) 'bon-general-assistant.md'
    if (-not (Test-Path -LiteralPath $InstructionsPath -PathType Leaf)) {
        throw "Required system instructions are missing: $InstructionsPath"
    }

    $DriveRoot = [IO.Path]::GetPathRoot($RepoRoot)
    $FreeBytes = ([IO.DriveInfo]::new($DriveRoot)).AvailableFreeSpace
    if ($FreeBytes -lt 9GB) {
        throw ('At least 9 GiB of free space is recommended; {0:N2} GiB is available.' -f ($FreeBytes / 1GB))
    }

    $ModelRoot = Join-Path $RepoRoot $ToolLock.layout.model_dir
    New-Item -ItemType Directory -Path $ToolsRoot, $DownloadRoot, $PythonRoot, $PrismRoot, $ModelRoot -Force | Out-Null

    $PythonVersionText = ''
    if (Test-Path -LiteralPath $PythonExe -PathType Leaf) {
        $PythonVersionText = (& $PythonExe --version 2>&1 | Out-String).Trim()
    }
    if ($PythonVersionText -ne "Python $PythonVersion") {
        $PythonArchive = Get-VerifiedDownload -Uri $PythonArchiveUrl -Destination (Join-Path $DownloadRoot $PythonArchiveName) -ExpectedSha256 $PythonArchiveSha256
        if (Test-Path -LiteralPath $PythonRoot -PathType Container) {
            $ResolvedPythonRoot = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $PythonRoot).Path)
            $ResolvedExpectedPythonRoot = [IO.Path]::GetFullPath((Join-Path $ToolsRoot $ToolLock.layout.python_dir))
            if (-not [StringComparer]::OrdinalIgnoreCase.Equals($ResolvedPythonRoot, $ResolvedExpectedPythonRoot)) {
                throw "Refusing to replace a Python directory outside the pinned tools location: $ResolvedPythonRoot"
            }
            Get-ChildItem -LiteralPath $PythonRoot -Force | Remove-Item -Recurse -Force
        }
        Expand-Archive -Path $PythonArchive -DestinationPath $PythonRoot -Force
    } else {
        Write-Host "Portable Python $PythonVersion is already installed."
    }
    if (-not (Test-Path -LiteralPath $PythonExe -PathType Leaf)) {
        throw "The embedded Python archive did not create the expected interpreter: $PythonExe"
    }

    $PythonPth = Join-Path $PythonRoot $ToolLock.python.pth_file
    $PythonStdlib = Join-Path $PythonRoot $ToolLock.python.stdlib_archive
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
    $PipMetadata = Invoke-RestMethod -Uri "https://pypi.org/pypi/pip/$PipVersion/json" -TimeoutSec 60
    $PipWheel = $PipMetadata.urls | Where-Object { $_.filename -eq $PipWheelName } | Select-Object -First 1
    if (-not $PipWheel -or $PipWheel.digests.sha256 -ne $PipArchiveSha256) {
        throw 'The pinned pip wheel metadata did not match its expected SHA-256.'
    }
    $PipArchive = Get-VerifiedDownload -Uri $PipWheel.url -Destination (Join-Path $DownloadRoot $PipArchiveName) -ExpectedSha256 $PipArchiveSha256
    $PipMetadataDirectory = Join-Path $SitePackages "pip-$PipVersion.dist-info"
    if (-not (Test-Path -LiteralPath $PipMetadataDirectory -PathType Container)) {
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

    Write-Host 'Checking the pinned virtual-environment bootstrap packages ...'
    $PreviousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $BootstrapSpecs = @($ToolLock.bootstrap_packages | ForEach-Object { "$($_.name)==$($_.version)" })
    & $PythonExe -m pip install --disable-pip-version-check --no-deps @BootstrapSpecs
    $PipExitCode = $LASTEXITCODE
    $ErrorActionPreference = $PreviousErrorActionPreference
    if ($PipExitCode -ne 0) { throw "Virtual-environment bootstrap installation failed with exit code $PipExitCode." }

    $VenvEntry = Get-Item -LiteralPath $VenvRoot -Force -ErrorAction SilentlyContinue
    if ($VenvEntry -and (($VenvEntry.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) {
        $VenvTarget = [IO.Path]::GetFullPath([string]$VenvEntry.Target)
        $ExpectedVenvTarget = [IO.Path]::GetFullPath($PythonRoot)
        if (-not [StringComparer]::OrdinalIgnoreCase.Equals($VenvTarget, $ExpectedVenvTarget)) {
            throw "Refusing to replace an unmanaged .venv reparse point: $VenvRoot -> $VenvTarget"
        }
        [IO.Directory]::Delete($VenvRoot, $false)
        $VenvEntry = $null
    }
    if ($VenvEntry -and -not (Test-Path -LiteralPath (Join-Path $VenvRoot 'pyvenv.cfg') -PathType Leaf)) {
        throw "The .venv directory exists but is not a managed virtual environment: $VenvRoot"
    }
    if ($VenvEntry) {
        $PreviousVenvVersion = ''
        if (Test-Path -LiteralPath $VenvPythonExe -PathType Leaf) {
            $PreviousVenvVersion = (& $VenvPythonExe --version 2>&1 | Out-String).Trim()
        }
        if ($PreviousVenvVersion -ne "Python $PythonVersion") {
            Write-Host "Rebuilding the managed .venv for Python $PythonVersion ..."
            Remove-Item -LiteralPath $VenvRoot -Recurse -Force
            $VenvEntry = $null
        }
    }
    if (-not $VenvEntry) {
        Write-Host 'Creating the independent repo-local .venv ...'
        & $PythonExe -m virtualenv --no-download --no-seed --copies --python $PythonExe $VenvRoot
        if ($LASTEXITCODE -ne 0) { throw "Could not create .venv (exit code $LASTEXITCODE)." }
    }
    if (-not (Test-Path -LiteralPath $VenvPythonExe -PathType Leaf)) {
        throw "The virtual environment did not create its interpreter: $VenvPythonExe"
    }

    $VenvScripts = Join-Path $VenvRoot 'Scripts'
    $VenvStdlib = Join-Path $VenvScripts $ToolLock.python.stdlib_archive
    if (-not (Test-Path -LiteralPath $VenvStdlib -PathType Leaf)) {
        throw "The virtual environment is missing its embedded standard library: $VenvStdlib"
    }
    $VenvPth = Join-Path $VenvScripts $ToolLock.python.pth_file
    $VenvPthLines = @($ToolLock.python.stdlib_archive, '.', '..\Lib\site-packages', 'import site')
    [IO.File]::WriteAllLines($VenvPth, $VenvPthLines, [Text.Encoding]::ASCII)
    $VenvSitePackages = Join-Path $VenvRoot 'Lib\site-packages'
    New-Item -ItemType Directory -Path $VenvSitePackages -Force | Out-Null
    if (-not (Test-Path -LiteralPath (Join-Path $VenvSitePackages "pip-$PipVersion.dist-info") -PathType Container)) {
        Expand-Archive -Path $PipArchive -DestinationPath $VenvSitePackages -Force
    }
    $VenvBytecodePolicy = Join-Path $VenvSitePackages 'disable-bytecode.pth'
    [IO.File]::WriteAllText($VenvBytecodePolicy, "import sys; sys.dont_write_bytecode = True`r`n", [Text.Encoding]::ASCII)

    $VenvVersionText = (& $VenvPythonExe --version 2>&1 | Out-String).Trim()
    if ($VenvVersionText -ne "Python $PythonVersion") {
        throw "The .venv uses an unexpected Python version: $VenvVersionText"
    }
    $VenvIsolation = @(& $VenvPythonExe -c "import sys; print(sys.dont_write_bytecode); print(any('AppData' in p for p in sys.path))" 2>&1)
    if ($LASTEXITCODE -ne 0 -or $VenvIsolation.Count -ne 2 -or [string]$VenvIsolation[0] -ne 'True' -or [string]$VenvIsolation[1] -ne 'False') {
        throw "The .venv failed bytecode or portable-path isolation checks: $($VenvIsolation -join '; ')"
    }

    Write-Host 'Installing the pinned application dependencies into .venv ...'
    $PreviousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $PackageSpecs = @($ToolLock.python_packages | ForEach-Object { "$($_.name)==$($_.version)" })
    & $VenvPythonExe -m pip install --disable-pip-version-check --no-deps @PackageSpecs
    $PipExitCode = $LASTEXITCODE
    $ErrorActionPreference = $PreviousErrorActionPreference
    if ($PipExitCode -ne 0) { throw "Python package installation failed with exit code $PipExitCode." }
    $ErrorActionPreference = 'Continue'
    & $VenvPythonExe -c "import huggingface_hub; print('huggingface_hub', huggingface_hub.__version__)"
    $HubImportExitCode = $LASTEXITCODE
    $ErrorActionPreference = $PreviousErrorActionPreference
    if ($HubImportExitCode -ne 0) {
        throw 'huggingface_hub could not be imported by the repo-local .venv.'
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
    if ($PrismExitCode -ne 0 -or $PrismVersion -notmatch [regex]::Escape($ToolLock.runtime.version_contains)) {
        if (-not $AcceptNvidiaCudaLicense) {
            Write-Host 'The pinned Prism CUDA runtime bundle includes NVIDIA CUDA 12.4 runtime libraries.'
            Write-Host 'Review the applicable NVIDIA terms before installation:'
            Write-Host 'https://docs.nvidia.com/cuda/archive/12.4.0/eula/index.html'
            $LicenseDecision = Read-Host 'Type ACCEPT to continue after reviewing the NVIDIA terms'
            if ($LicenseDecision -cne 'ACCEPT') {
                throw 'NVIDIA CUDA runtime installation was not accepted; setup stopped before downloading runtime binaries.'
            }
        }
        $PrismBinaryLock = $ToolLock.runtime.archives[0]
        $CudaRuntimeLock = $ToolLock.runtime.archives[1]
        $PrismArchive = Get-VerifiedAsset -Name $PrismBinaryLock.filename -Uri "$PrismReleaseUrl/$($PrismBinaryLock.filename)" -ExpectedSha256 $PrismBinaryLock.sha256
        $CudaArchive = Get-VerifiedAsset -Name $CudaRuntimeLock.filename -Uri "$PrismReleaseUrl/$($CudaRuntimeLock.filename)" -ExpectedSha256 $CudaRuntimeLock.sha256
        Expand-Archive -Path $PrismArchive -DestinationPath $PrismRoot -Force
        Expand-Archive -Path $CudaArchive -DestinationPath $PrismRoot -Force
        if (-not (Test-Path -LiteralPath $PrismServer -PathType Leaf)) {
            throw "The Prism archive did not contain llama-server.exe at the expected path: $PrismServer"
        }
        $ErrorActionPreference = 'Continue'
        $PrismVersion = (& $PrismServer --version 2>&1 | Out-String).Trim()
        $PrismExitCode = $LASTEXITCODE
        $ErrorActionPreference = $PreviousErrorActionPreference
        if ($PrismExitCode -ne 0 -or $PrismVersion -notmatch [regex]::Escape($ToolLock.runtime.version_contains)) {
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

    $ConfiguredDefault = (& $VenvPythonExe -c "import runpy,sys; print(runpy.run_path(sys.argv[1])['DEFAULT_MODEL_TAG'])" $BonSourceFile 2>&1 | Out-String).Trim()
    $DefaultModelTag = $ToolLock.models.default
    if ($LASTEXITCODE -ne 0 -or $ConfiguredDefault -ne $DefaultModelTag -or $DefaultModelTag -ne 'bon2:27b-5gb') {
        throw "The application default model must remain bon2:27b-5gb; found '$ConfiguredDefault'."
    }
    & $VenvPythonExe $BonSourceFile pull $DefaultModelTag
    if ($LASTEXITCODE -ne 0) {
        throw "The default $DefaultModelTag model download/verification failed with exit code $LASTEXITCODE."
    }

    foreach ($BytecodeRoot in @($PythonRoot, $VenvRoot)) {
        $BytecodeCaches = @(Get-ChildItem -LiteralPath $BytecodeRoot -Directory -Filter '__pycache__' -Recurse -Force -ErrorAction SilentlyContinue)
        foreach ($BytecodeCache in $BytecodeCaches) {
            Remove-Item -LiteralPath $BytecodeCache.FullName -Recurse -Force
        }
    }

    if (-not $SkipPathRegistration) {
        Add-RepositoryToUserPath
    }

    Write-Host ''
    Write-Host 'Setup completed.'
    Write-Host 'Default model: bon2:27b-5gb (installed).'
    Write-Host 'Optional model bon2:27b-7gb is not pulled automatically; use: bon pull bon2:27b-7gb'
    Write-Host 'Start chatting with: bon'
    if (-not $SkipPathRegistration) {
        Write-Host 'Open a new terminal before using the bon command from another directory.'
    }
} catch {
    [Console]::Error.WriteLine("[ERROR] $($_.Exception.Message)")
    exit 1
}
