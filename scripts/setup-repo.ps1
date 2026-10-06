[CmdletBinding()]
param(
    [switch]$SkipPathRegistration
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$env:PYTHONDONTWRITEBYTECODE = '1'
$env:PYTHONUTF8 = '1'
$env:PYTHONUNBUFFERED = '1'
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
$MsvcRoot = Join-Path $ToolsRoot $ToolLock.layout.msvc_dir
$WixRoot = Join-Path $ToolsRoot $ToolLock.layout.wix_dir
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

function Get-PinnedWheel {
    param([Parameter(Mandatory = $true)][object]$Package)

    foreach ($Property in @('name', 'version', 'wheel', 'sha256')) {
        if ([string]::IsNullOrWhiteSpace([string]$Package.$Property)) {
            throw "The tool lock is missing '$Property' for package '$($Package.name)'."
        }
    }
    $WheelPath = Join-Path $DownloadRoot $Package.wheel
    if (Test-Path -LiteralPath $WheelPath -PathType Leaf) {
        if ((Get-Sha256 -Path $WheelPath) -eq $Package.sha256.ToUpperInvariant()) {
            return $WheelPath
        }
        Write-Warning "Ignoring a cached wheel with an unexpected checksum: $WheelPath"
    }

    $PackageName = [Uri]::EscapeDataString([string]$Package.name)
    $PackageVersion = [Uri]::EscapeDataString([string]$Package.version)
    $Metadata = Invoke-RestMethod -Uri "https://pypi.org/pypi/$PackageName/$PackageVersion/json" -TimeoutSec 60
    $Wheel = $Metadata.urls | Where-Object { $_.filename -eq $Package.wheel } | Select-Object -First 1
    if (-not $Wheel -or $Wheel.digests.sha256 -ne $Package.sha256) {
        throw "PyPI metadata did not match the pinned wheel and SHA-256 for $($Package.name)==$($Package.version)."
    }
    return Get-VerifiedDownload -Uri $Wheel.url -Destination $WheelPath -ExpectedSha256 $Package.sha256
}

function Install-PinnedWheels {
    param(
        [Parameter(Mandatory = $true)][string]$PythonExecutable,
        [Parameter(Mandatory = $true)][object[]]$Packages,
        [Parameter(Mandatory = $true)][string]$EnvironmentName
    )

    $WheelPaths = @($Packages | ForEach-Object { Get-PinnedWheel -Package $_ })
    $PreviousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & $PythonExecutable -m pip install --disable-pip-version-check --no-compile --no-deps --no-index --force-reinstall @WheelPaths
    $InstallExitCode = $LASTEXITCODE
    $ErrorActionPreference = $PreviousErrorActionPreference
    if ($InstallExitCode -ne 0) {
        throw "Pinned wheel installation failed for $EnvironmentName (exit code $InstallExitCode)."
    }
}

function Install-PortableMsvcRuntime {
    # Extract the signed redistributable; never run its system-wide installer.
    $MissingFiles = @($ToolLock.msvc_runtime.files | Where-Object {
        $FilePath = Join-Path $MsvcRoot $_.file
        -not (Test-Path -LiteralPath $FilePath -PathType Leaf) -or
            (Get-Sha256 -Path $FilePath) -ne $_.sha256
    })
    if ($MissingFiles.Count -gt 0) {
        $WixLock = $ToolLock.wix
        $DarkExe = Join-Path $WixRoot $WixLock.extractor
        if (-not (Test-Path -LiteralPath $DarkExe -PathType Leaf) -or
            (Get-Sha256 -Path $DarkExe) -ne $WixLock.extractor_sha256) {
            $WixArchive = Get-VerifiedAsset -Name $WixLock.archive -Uri $WixLock.url -ExpectedSha256 $WixLock.sha256
            Expand-Archive -Path $WixArchive -DestinationPath $WixRoot -Force
        }
        if ((Get-Sha256 -Path $DarkExe) -ne $WixLock.extractor_sha256) {
            throw 'The portable WiX extractor failed its checksum check.'
        }
        $MsvcLock = $ToolLock.msvc_runtime
        $MsvcArchive = Get-VerifiedAsset -Name $MsvcLock.archive -Uri $MsvcLock.url -ExpectedSha256 $MsvcLock.sha256
        $Signature = Get-AuthenticodeSignature -LiteralPath $MsvcArchive
        if ($Signature.Status -ne 'Valid' -or $Signature.SignerCertificate.Subject -notmatch 'O=Microsoft Corporation') {
            throw 'The Visual C++ redistributable did not have a valid Microsoft signature.'
        }
        $ExtractionRoot = Join-Path $DownloadRoot "msvc-extract-$($MsvcLock.version)"
        $RuntimeFiles = Join-Path $ExtractionRoot 'runtime-files'
        New-Item -ItemType Directory -Path $ExtractionRoot, $RuntimeFiles -Force | Out-Null
        Write-Host 'Extracting portable Visual C++ DLLs (no global installer or administrator access) ...'
        & $DarkExe -nologo $MsvcArchive -x $ExtractionRoot
        if ($LASTEXITCODE -ne 0) { throw 'WiX could not extract the Visual C++ redistributable.' }
        $CabPath = Join-Path $ExtractionRoot $MsvcLock.cab
        & (Join-Path $env:SystemRoot 'System32\expand.exe') '-F:*' $CabPath $RuntimeFiles | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'Could not expand the Visual C++ runtime cabinet.' }
        foreach ($File in $MsvcLock.files) {
            $ExtractedFile = Join-Path $RuntimeFiles "$($File.file)_amd64"
            if (-not (Test-Path -LiteralPath $ExtractedFile -PathType Leaf) -or
                (Get-Sha256 -Path $ExtractedFile) -ne $File.sha256) {
                throw "Extracted Visual C++ DLL failed its pinned checksum: $($File.file)"
            }
            Copy-Item -LiteralPath $ExtractedFile -Destination (Join-Path $MsvcRoot $File.file) -Force
        }
        Copy-Item -LiteralPath (Join-Path $ExtractionRoot 'UX\thm.wxl') -Destination (Join-Path $MsvcRoot 'vendor-license-reference.xml') -Force
        [IO.File]::WriteAllText((Join-Path $MsvcRoot 'LICENSE-SOURCE.txt'),
            "Microsoft Visual C++ Runtime $($MsvcLock.version)`r`nOriginal package: $($MsvcLock.url)`r`nApplicable terms: $($MsvcLock.license_url)`r`nThese binaries are not licensed under Bon's MIT license.`r`n", [Text.Encoding]::UTF8)
    } else {
        Write-Host 'The pinned portable Visual C++ runtime is already installed.'
    }
    # App-local DLLs must exist before any inference executable is started.
    foreach ($File in $ToolLock.msvc_runtime.files) {
        $Destination = Join-Path $PrismRoot $File.file
        if (-not (Test-Path -LiteralPath $Destination -PathType Leaf) -or
            (Get-Sha256 -Path $Destination) -ne $File.sha256) {
            Copy-Item -LiteralPath (Join-Path $MsvcRoot $File.file) -Destination $Destination -Force
        }
    }
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
    # Do not resolve a same-named module from a parent PowerShell's module path.
    Import-Module (Join-Path $PSHOME 'Modules\Microsoft.PowerShell.Security\Microsoft.PowerShell.Security.psd1') -ErrorAction Stop
    Write-Host 'UNATTENDED SETUP: upstream terms are acknowledged and accepted by the installing operator.'
    Write-Host 'Run this setup only if you accept the following applicable terms; no acceptance prompt will be shown.'
    Write-Host 'Bon source: MIT (LICENSE). External components retain their own licenses; see THIRD-PARTY-NOTICES.md.'
    Write-Host 'NVIDIA CUDA 12.4: https://docs.nvidia.com/cuda/archive/12.4.0/eula/index.html'
    Write-Host "Microsoft Visual C++ Runtime: $($ToolLock.msvc_runtime.license_url)"
    Write-Host "WiX extractor (MS-RL): $($ToolLock.wix.license_url)"
    Write-Host 'Python: https://docs.python.org/3.12/license.html'
    Write-Host 'Bonsai model (Apache-2.0): https://huggingface.co/prism-ml/Ternary-Bonsai-2-27B-gguf'
    Write-Host 'This notice does not waive upstream obligations, certify redistribution rights, or record individual consent.'
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
    New-Item -ItemType Directory -Path $ToolsRoot, $DownloadRoot, $PythonRoot, $PrismRoot, $ModelRoot, $MsvcRoot, $WixRoot -Force | Out-Null
    Install-PortableMsvcRuntime

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

    Write-Host 'Verifying and installing pinned virtual-environment bootstrap wheels ...'
    Install-PinnedWheels -PythonExecutable $PythonExe -Packages $ToolLock.bootstrap_packages -EnvironmentName 'the embedded Python bootstrap'

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
        & $PythonExe -m virtualenv --no-download --no-seed --copies --app-data (Join-Path $DownloadRoot 'virtualenv') --python $PythonExe $VenvRoot
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

    Write-Host 'Verifying and installing pinned application wheels into .venv ...'
    Install-PinnedWheels -PythonExecutable $VenvPythonExe -Packages $ToolLock.python_packages -EnvironmentName '.venv'
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

    $RuntimeLicenseExe = Join-Path $PrismRoot $ToolLock.runtime.license_executable
    if (-not (Test-Path -LiteralPath $RuntimeLicenseExe -PathType Leaf)) {
        throw "The runtime license-report executable is missing: $RuntimeLicenseExe"
    }
    $ErrorActionPreference = 'Continue'
    $RuntimeLicenseText = (& $RuntimeLicenseExe licenses 2>&1 | Out-String)
    $RuntimeLicenseExitCode = $LASTEXITCODE
    $ErrorActionPreference = $PreviousErrorActionPreference
    if ($RuntimeLicenseExitCode -ne 0 -or $RuntimeLicenseText -notmatch 'License for llama.cpp') {
        throw 'The pinned inference runtime could not report its bundled license notices.'
    }
    [IO.File]::WriteAllText((Join-Path $PrismRoot 'THIRD-PARTY-LICENSES.txt'), $RuntimeLicenseText, [Text.UTF8Encoding]::new($false))

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
