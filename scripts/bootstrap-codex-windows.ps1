param(
    [string]$GitUserName = "",
    [string]$GitUserEmail = "",
    [switch]$ConfigureGit,
    [switch]$AutoInstall,
    [switch]$InstallOptionalTools,
    [switch]$PromptOptionalTools,
    [switch]$InstallPdfTools,
    [switch]$PromptPdfTools
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "SilentlyContinue"

function Test-Command {
    param(
        [string]$Name,
        [string]$VersionArgs = "--version"
    )
    $result = [ordered]@{
        Name = $Name
        Ok = $false
        Details = ""
    }
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if (-not $cmd) {
        return [pscustomobject]$result
    }
    $out = & $Name $VersionArgs 2>&1
    if ($LASTEXITCODE -eq 0) {
        $result.Ok = $true
    }
    $result.Details = ($out | Out-String).Trim()
    return [pscustomobject]$result
}

function Add-CheckResult {
    param(
        [ref]$List,
        [string]$Name,
        [bool]$Ok,
        [string]$Details
    )
    $List.Value += [pscustomobject]@{
        Name = $Name
        Ok = $Ok
        Details = $Details
    }
}

function Install-WingetPackage {
    param(
        [string]$Id
    )
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $winget) {
        return [pscustomobject]@{
            Id = $Id
            Ok = $false
            Details = "winget not found"
        }
    }
    $out = winget install --id $Id -e --accept-package-agreements --accept-source-agreements 2>&1
    $ok = ($LASTEXITCODE -eq 0)
    [pscustomobject]@{
        Id = $Id
        Ok = $ok
        Details = ($out | Out-String).Trim()
    }
}

function Get-OptionalWingetPackageIds {
    return @(
        "jqlang.jq",
        "sharkdp.fd",
        "sharkdp.bat",
        "GitHub.GitLFS",
        "Docker.DockerDesktop"
    )
}

function Get-PdfPythonPackages {
    return @(
        [pscustomobject]@{ Package = "reportlab"; ImportName = "reportlab" },
        [pscustomobject]@{ Package = "pypdf"; ImportName = "pypdf" },
        [pscustomobject]@{ Package = "pdfplumber"; ImportName = "pdfplumber" },
        [pscustomobject]@{ Package = "pdf2image"; ImportName = "pdf2image" },
        [pscustomobject]@{ Package = "pillow"; ImportName = "PIL" }
    )
}

function Get-PdfWingetPackageIds {
    return @(
        "oschwartz10612.Poppler",
        "QPDF.QPDF"
    )
}

function Test-PythonImport {
    param(
        [string]$ImportName,
        [string]$CheckName = ""
    )

    $name = if ([string]::IsNullOrWhiteSpace($CheckName)) { $ImportName } else { $CheckName }
    $result = [ordered]@{
        Name = "python.$name"
        Ok = $false
        Details = ""
    }

    $python = Get-Command python -ErrorAction SilentlyContinue
    if (-not $python) {
        $result.Details = "python not found"
        return [pscustomobject]$result
    }

    $code = "import importlib.util, sys; name='$ImportName'; spec=importlib.util.find_spec(name); print(spec.origin if spec and spec.origin else ('present' if spec else 'missing')); sys.exit(0 if spec else 1)"
    $out = python -c $code 2>&1
    if ($LASTEXITCODE -eq 0) {
        $result.Ok = $true
    }
    $result.Details = ($out | Out-String).Trim()
    return [pscustomobject]$result
}

function Test-PythonModule {
    param(
        [string]$ModuleName
    )

    $result = [ordered]@{
        Name = "python.$ModuleName"
        Ok = $false
        Details = ""
    }

    $python = Get-Command python -ErrorAction SilentlyContinue
    if (-not $python) {
        $result.Details = "python not found"
        return [pscustomobject]$result
    }

    $out = python -m $ModuleName --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        $result.Ok = $true
    }
    $result.Details = ($out | Out-String).Trim()
    return [pscustomobject]$result
}

function Install-PythonPackage {
    param(
        [string]$Package
    )

    $python = Get-Command python -ErrorAction SilentlyContinue
    if (-not $python) {
        return [pscustomobject]@{
            Id = "python-package:$Package"
            Ok = $false
            Details = "python not found"
        }
    }

    $out = python -m pip install --user $Package 2>&1
    $ok = ($LASTEXITCODE -eq 0)
    [pscustomobject]@{
        Id = "python-package:$Package"
        Ok = $ok
        Details = ($out | Out-String).Trim()
    }
}

function Get-PythonUserScriptsPath {
    $python = Get-Command python -ErrorAction SilentlyContinue
    if (-not $python) {
        return $null
    }

    $scriptsPath = python -c "import sysconfig; print(sysconfig.get_path('scripts', scheme='nt_user'))" 2>&1
    if ($LASTEXITCODE -ne 0) {
        return $null
    }

    $scriptsPathText = ($scriptsPath | Out-String).Trim()
    if ([string]::IsNullOrWhiteSpace($scriptsPathText)) {
        return $null
    }

    return $scriptsPathText
}

function Get-PythonLegacyUserScriptsPath {
    $python = Get-Command python -ErrorAction SilentlyContinue
    if (-not $python) {
        return $null
    }

    $userBase = python -m site --user-base 2>&1
    if ($LASTEXITCODE -ne 0) {
        return $null
    }

    $userBaseText = ($userBase | Out-String).Trim()
    if ([string]::IsNullOrWhiteSpace($userBaseText)) {
        return $null
    }

    return (Join-Path $userBaseText "Scripts")
}

function Convert-ToUserProfilePath {
    param(
        [string]$PathValue
    )

    if ([string]::IsNullOrWhiteSpace($PathValue)) {
        return $PathValue
    }

    $expandedHome = [Environment]::ExpandEnvironmentVariables("%USERPROFILE%")
    if ([string]::IsNullOrWhiteSpace($expandedHome)) {
        return $PathValue
    }

    if ($PathValue.StartsWith($expandedHome, [System.StringComparison]::OrdinalIgnoreCase)) {
        return "%USERPROFILE%" + $PathValue.Substring($expandedHome.Length)
    }

    return $PathValue
}

function Test-PathContainsEntry {
    param(
        [string]$PathValue,
        [string]$Entry
    )

    if ([string]::IsNullOrWhiteSpace($PathValue) -or [string]::IsNullOrWhiteSpace($Entry)) {
        return $false
    }

    $target = [System.IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($Entry)).TrimEnd('\')
    foreach ($segment in ($PathValue -split ';')) {
        $segmentText = $segment.Trim()
        if ([string]::IsNullOrWhiteSpace($segmentText)) {
            continue
        }

        $expandedSegment = [Environment]::ExpandEnvironmentVariables($segmentText)
        try {
            $candidate = [System.IO.Path]::GetFullPath($expandedSegment).TrimEnd('\')
        }
        catch {
            continue
        }

        if ($candidate.Equals($target, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }

    return $false
}

function Ensure-UserPathEntry {
    param(
        [string]$Entry
    )

    if ([string]::IsNullOrWhiteSpace($Entry)) {
        return [pscustomobject]@{
            Id = "env:Path"
            Ok = $false
            Details = "path entry was empty"
        }
    }

    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if (Test-PathContainsEntry -PathValue $userPath -Entry $Entry) {
        return [pscustomobject]@{
            Id = "env:Path"
            Ok = $true
            Details = "User PATH already contains $Entry"
        }
    }

    $newUserPath = if ([string]::IsNullOrWhiteSpace($userPath)) { $Entry } else { "$userPath;$Entry" }
    [Environment]::SetEnvironmentVariable("Path", $newUserPath, "User")

    $updatedUserPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $ok = Test-PathContainsEntry -PathValue $updatedUserPath -Entry $Entry
    [pscustomobject]@{
        Id = "env:Path"
        Ok = $ok
        Details = if ($ok) { "Added $Entry to user PATH" } else { "Failed to add $Entry to user PATH" }
    }
}

function Remove-UserPathEntry {
    param(
        [string]$Entry
    )

    if ([string]::IsNullOrWhiteSpace($Entry)) {
        return [pscustomobject]@{
            Id = "env:Path"
            Ok = $true
            Details = "No path entry removal needed"
        }
    }

    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if (-not (Test-PathContainsEntry -PathValue $userPath -Entry $Entry)) {
        return [pscustomobject]@{
            Id = "env:Path"
            Ok = $true
            Details = "User PATH did not contain $Entry"
        }
    }

    $segments = @()
    foreach ($segment in ($userPath -split ';')) {
        $segmentText = $segment.Trim()
        if ([string]::IsNullOrWhiteSpace($segmentText)) {
            continue
        }
        if (-not (Test-PathContainsEntry -PathValue $segmentText -Entry $Entry)) {
            $segments += $segmentText
        }
    }

    [Environment]::SetEnvironmentVariable("Path", ($segments -join ';'), "User")
    $updatedUserPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $ok = -not (Test-PathContainsEntry -PathValue $updatedUserPath -Entry $Entry)
    [pscustomobject]@{
        Id = "env:Path"
        Ok = $ok
        Details = if ($ok) { "Removed $Entry from user PATH" } else { "Failed to remove $Entry from user PATH" }
    }
}

function Get-Checks {
    $checks = @()

    $git = Test-Command -Name "git"
    $python = Test-Command -Name "python"
    $node = Test-Command -Name "node"
    $npm = Test-Command -Name "npm"
    $gh = Test-Command -Name "gh"
    $rg = Test-Command -Name "rg"
    $uv = Test-Command -Name "uv"
    $pyVirtualenv = Test-PythonModule -ModuleName "virtualenv"
    $pyPylint = Test-PythonModule -ModuleName "pylint"
    $pdfPackageChecks = @()
    foreach ($pdfPackage in (Get-PdfPythonPackages)) {
        $pdfPackageChecks += (Test-PythonImport -ImportName $pdfPackage.ImportName -CheckName $pdfPackage.Package)
    }
    $pdftoppm = Test-Command -Name "pdftoppm" -VersionArgs "-v"
    $pdfinfo = Test-Command -Name "pdfinfo" -VersionArgs "-v"
    $qpdf = Test-Command -Name "qpdf"

    Add-CheckResult -List ([ref]$checks) -Name "git" -Ok $git.Ok -Details $git.Details
    Add-CheckResult -List ([ref]$checks) -Name "python" -Ok $python.Ok -Details $python.Details
    Add-CheckResult -List ([ref]$checks) -Name "node" -Ok $node.Ok -Details $node.Details
    Add-CheckResult -List ([ref]$checks) -Name "npm" -Ok $npm.Ok -Details $npm.Details
    Add-CheckResult -List ([ref]$checks) -Name "gh" -Ok $gh.Ok -Details $gh.Details
    Add-CheckResult -List ([ref]$checks) -Name "rg" -Ok $rg.Ok -Details $rg.Details
    Add-CheckResult -List ([ref]$checks) -Name "uv" -Ok $uv.Ok -Details $uv.Details
    Add-CheckResult -List ([ref]$checks) -Name "python.virtualenv" -Ok $pyVirtualenv.Ok -Details $pyVirtualenv.Details
    Add-CheckResult -List ([ref]$checks) -Name "python.pylint" -Ok $pyPylint.Ok -Details $pyPylint.Details
    foreach ($pdfPackageCheck in $pdfPackageChecks) {
        Add-CheckResult -List ([ref]$checks) -Name $pdfPackageCheck.Name -Ok $pdfPackageCheck.Ok -Details $pdfPackageCheck.Details
    }
    Add-CheckResult -List ([ref]$checks) -Name "pdftoppm" -Ok $pdftoppm.Ok -Details $pdftoppm.Details
    Add-CheckResult -List ([ref]$checks) -Name "pdfinfo" -Ok $pdfinfo.Ok -Details $pdfinfo.Details
    Add-CheckResult -List ([ref]$checks) -Name "qpdf" -Ok $qpdf.Ok -Details $qpdf.Details

    $gitName = git config --global --get user.name 2>&1
    $gitEmail = git config --global --get user.email 2>&1
    $gitNameText = ($gitName | Out-String).Trim()
    $gitEmailText = ($gitEmail | Out-String).Trim()
    $gitNameOk = -not [string]::IsNullOrWhiteSpace($gitNameText)
    $gitEmailOk = -not [string]::IsNullOrWhiteSpace($gitEmailText)
    Add-CheckResult -List ([ref]$checks) -Name "git.user.name" -Ok $gitNameOk -Details $gitNameText
    Add-CheckResult -List ([ref]$checks) -Name "git.user.email" -Ok $gitEmailOk -Details $gitEmailText

    $ghAuthOk = $false
    $ghAuthDetails = "gh unavailable"
    if ($gh.Ok) {
        $ghAuth = gh auth status 2>&1
        $ghAuthDetails = ($ghAuth | Out-String).Trim()
        if (($ghAuthDetails -match "Logged in to github.com") -and ($ghAuthDetails -match "Active account: true")) {
            $ghAuthOk = $true
        }
    }
    Add-CheckResult -List ([ref]$checks) -Name "gh.auth" -Ok $ghAuthOk -Details $ghAuthDetails

    return @($checks)
}

$actions = @()

if (($ConfigureGit -or (-not [string]::IsNullOrWhiteSpace($GitUserName) -or -not [string]::IsNullOrWhiteSpace($GitUserEmail))) `
    -and -not [string]::IsNullOrWhiteSpace($GitUserName) `
    -and -not [string]::IsNullOrWhiteSpace($GitUserEmail)) {
    git config --global user.name "$GitUserName" | Out-Null
    git config --global user.email "$GitUserEmail" | Out-Null
    $actions += [pscustomobject]@{
        Name = "configure.git"
        Ok = ($LASTEXITCODE -eq 0)
        Details = "Set git.user.name and git.user.email"
    }
}

$checks = Get-Checks

if ($AutoInstall) {
    $needNode = (($checks | Where-Object { $_.Name -eq "node" }).Ok -eq $false) -or (($checks | Where-Object { $_.Name -eq "npm" }).Ok -eq $false)
    $needGh = (($checks | Where-Object { $_.Name -eq "gh" }).Ok -eq $false)
    $needRg = (($checks | Where-Object { $_.Name -eq "rg" }).Ok -eq $false)
    $needUv = (($checks | Where-Object { $_.Name -eq "uv" }).Ok -eq $false)
    $pythonOk = (($checks | Where-Object { $_.Name -eq "python" }).Ok -eq $true)
    $needPyVirtualenv = (($checks | Where-Object { $_.Name -eq "python.virtualenv" }).Ok -eq $false)
    $needPyPylint = (($checks | Where-Object { $_.Name -eq "python.pylint" }).Ok -eq $false)
    $pythonScriptsPath = Convert-ToUserProfilePath -PathValue (Get-PythonUserScriptsPath)
    $legacyPythonScriptsPath = Convert-ToUserProfilePath -PathValue (Get-PythonLegacyUserScriptsPath)
    $shouldInstallPdfTools = $InstallPdfTools.IsPresent

    if ($needNode) {
        $actions += (Install-WingetPackage -Id "OpenJS.NodeJS.LTS")
    }
    if ($needGh) {
        $actions += (Install-WingetPackage -Id "GitHub.cli")
    }
    if ($needRg) {
        $actions += (Install-WingetPackage -Id "BurntSushi.ripgrep.MSVC")
    }
    if ($needUv) {
        $actions += (Install-WingetPackage -Id "astral-sh.uv")
    }

    $shouldInstallOptionalTools = $InstallOptionalTools.IsPresent
    if ($PromptOptionalTools) {
        $optionalPrompt = "Install optional tools (jq, fd, bat, Git LFS, Docker Desktop)? [y/N]"
        $optionalResponse = (Read-Host $optionalPrompt | Out-String).Trim().ToLowerInvariant()
        if ($optionalResponse -in @("y", "yes")) {
            $shouldInstallOptionalTools = $true
        }
    }
    if ($shouldInstallOptionalTools) {
        foreach ($optionalPackageId in (Get-OptionalWingetPackageIds)) {
            $actions += (Install-WingetPackage -Id $optionalPackageId)
        }
    }
    if ($PromptPdfTools) {
        $pdfPrompt = "Install PDF tools (reportlab, pypdf, pdfplumber, pdf2image, Pillow, Poppler, QPDF)? [y/N]"
        $pdfResponse = (Read-Host $pdfPrompt | Out-String).Trim().ToLowerInvariant()
        if ($pdfResponse -in @("y", "yes")) {
            $shouldInstallPdfTools = $true
        }
    }
    if ($shouldInstallPdfTools) {
        if ($pythonOk) {
            foreach ($pdfPackage in (Get-PdfPythonPackages)) {
                $checkName = "python.$($pdfPackage.Package)"
                $needPackage = (($checks | Where-Object { $_.Name -eq $checkName }).Ok -eq $false)
                if ($needPackage) {
                    $actions += (Install-PythonPackage -Package $pdfPackage.Package)
                }
            }
        }
        $needPoppler = (($checks | Where-Object { $_.Name -eq "pdftoppm" }).Ok -eq $false) -or (($checks | Where-Object { $_.Name -eq "pdfinfo" }).Ok -eq $false)
        $needQpdf = (($checks | Where-Object { $_.Name -eq "qpdf" }).Ok -eq $false)
        if ($needPoppler) {
            $actions += (Install-WingetPackage -Id "oschwartz10612.Poppler")
        }
        if ($needQpdf) {
            $actions += (Install-WingetPackage -Id "QPDF.QPDF")
        }
    }

    if ($pythonOk -and $needPyVirtualenv) {
        $actions += (Install-PythonPackage -Package "virtualenv")
    }
    if ($pythonOk -and $needPyPylint) {
        $actions += (Install-PythonPackage -Package "pylint")
    }
    if ($pythonOk -and -not [string]::IsNullOrWhiteSpace($legacyPythonScriptsPath) -and $legacyPythonScriptsPath -ne $pythonScriptsPath) {
        $actions += (Remove-UserPathEntry -Entry $legacyPythonScriptsPath)
    }
    if ($pythonOk -and -not [string]::IsNullOrWhiteSpace($pythonScriptsPath)) {
        $actions += (Ensure-UserPathEntry -Entry $pythonScriptsPath)
    }

    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $env:Path = [Environment]::ExpandEnvironmentVariables("$userPath;$machinePath")

    $checks = Get-Checks
}

$installed = @($checks | Where-Object { $_.Ok })
$missing = @($checks | Where-Object { -not $_.Ok -and $_.Name -in @("node", "npm", "gh", "rg", "uv", "python.virtualenv", "python.pylint") })
$pdfCheckNames = @("python.reportlab", "python.pypdf", "python.pdfplumber", "python.pdf2image", "python.pillow", "pdftoppm", "pdfinfo", "qpdf")
$pdfMissing = @($checks | Where-Object { -not $_.Ok -and $_.Name -in $pdfCheckNames })
$misconfigured = @($checks | Where-Object { -not $_.Ok -and $_.Name -in @("git.user.name", "git.user.email", "gh.auth") })
$ready = (($missing.Length -eq 0) -and ($misconfigured.Length -eq 0) -and ((-not $InstallPdfTools.IsPresent) -or ($pdfMissing.Length -eq 0)))

[pscustomobject]@{
    Status = if ($ready) { "Ready" } else { "Not Ready" }
    AutoInstallAttempted = [bool]$AutoInstall
    Actions = @($actions)
    Installed = $installed
    Missing = $missing
    PdfMissing = $pdfMissing
    Misconfigured = $misconfigured
    AllChecks = @($checks)
} | ConvertTo-Json -Depth 6
