#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$Destination = (Join-Path $env:LOCALAPPDATA 'ChatGPT-Extension-Helper'),
    [switch]$PrepareOnly,
    [string]$CrxPath
)
$ErrorActionPreference = 'Stop'
$ExtensionId = 'hehggadaopoacecdllhhajmbjkdcmajg'
$StoreUrl = 'https://chromewebstore.google.com/detail/chatgpt/' + $ExtensionId
$Utf8 = New-Object System.Text.UTF8Encoding($false)
try {
    $chrome = @(
        "${env:ProgramFiles}\Google\Chrome\Application\chrome.exe",
        "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
        "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
    ) | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
    if (-not $chrome -and -not $PrepareOnly) { throw 'Google Chrome was not found. Install Chrome first.' }
    $version = if ($chrome) { (Get-Item -LiteralPath $chrome).VersionInfo.ProductVersion } else { '149.0.0.0' }
    if ($version -notmatch '^\d+\.\d+\.\d+\.\d+$') { throw 'Cannot determine Chrome version.' }
    $root = [IO.Path]::GetFullPath($Destination)
    New-Item -ItemType Directory -Force -Path $root | Out-Null
    # Every run gets a new directory: never replace an already loaded extension.
    $run = Join-Path $root ('run-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $run | Out-Null
    $package = Join-Path $run 'official.crx'
    $zip = Join-Path $run 'verified.zip'
    $extension = Join-Path $run 'extension'
    Write-Host 'ChatGPT extension preparation helper (Windows)' -ForegroundColor Cyan
    Write-Host "Target: $ExtensionId"
    if ($CrxPath) {
        Copy-Item -LiteralPath $CrxPath -Destination $package
    } else {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $url = 'https://clients2.google.com/service/update2/crx?response=redirect&prodversion=' + $version + '&acceptformat=crx3&x=' + [uri]::EscapeDataString("id=$ExtensionId&uc")
        Write-Host 'Downloading from Google. This may take a minute...'
        Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $package -TimeoutSec 90
    }
    if (-not ('VerifyCrx' -as [type])) { Add-Type -Path (Join-Path $PSScriptRoot 'VerifyCrx.cs') }
    $publicKey = [VerifyCrx]::ExtractZip($package, $zip, $ExtensionId)
    Write-Host 'Extension ID and RSA developer signature verified.'
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    New-Item -ItemType Directory -Path $extension | Out-Null
    $archive = [IO.Compression.ZipFile]::OpenRead($zip)
    try {
        $prefix = [IO.Path]::GetFullPath($extension) + [IO.Path]::DirectorySeparatorChar
        [long]$total = 0
        if ($archive.Entries.Count -gt 20000) { throw 'Too many files in package.' }
        foreach ($entry in $archive.Entries) {
            $total += $entry.Length
            if ($total -gt 500MB) { throw 'Unpacked package is too large.' }
            $name = $entry.FullName.Replace('/', '\')
            if ($name.Contains(':') -or [IO.Path]::IsPathRooted($name) -or $name -match '(^|\\)\.\.(\\|$)') { throw 'Unsafe ZIP path.' }
            $target = [IO.Path]::GetFullPath((Join-Path $extension $name))
            if (-not $target.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { throw 'ZIP path escapes destination.' }
            # Chrome reserves _metadata for store-managed verification files.
            if ($name -eq '_metadata' -or $name.StartsWith('_metadata\', [StringComparison]::OrdinalIgnoreCase)) { continue }
            if ($name.EndsWith('\')) { New-Item -ItemType Directory -Force -Path $target | Out-Null; continue }
            New-Item -ItemType Directory -Force -Path ([IO.Path]::GetDirectoryName($target)) | Out-Null
            [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $target, $false)
        }
    } finally { $archive.Dispose() }
    $manifestPath = Join-Path $extension 'manifest.json'
    $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($manifest.manifest_version -ne 3) { throw 'This helper only supports Manifest V3.' }
    if ($manifest.minimum_chrome_version) {
        $minimum = [string]$manifest.minimum_chrome_version
        if ($minimum -notmatch '\.') { $minimum += '.0' }
        if ([version]$version -lt [version]$minimum) { throw 'Update Chrome before loading this extension.' }
    }
    # Preserve the store ID, needed by the desktop native messaging host.
    $manifest | Add-Member -NotePropertyName key -NotePropertyValue $publicKey -Force
    [IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 100), $Utf8)
    $receipt = [ordered]@{
        status = 'prepared-not-installed'; extensionId = $ExtensionId
        version = $manifest.version; name = $manifest.name; chromeVersion = $version
        storeUrl = $StoreUrl; packageSHA256 = (Get-FileHash -LiteralPath $package -Algorithm SHA256).Hash
        verification = 'RSA developer proof and extension ID; not full Chrome store verification'
        extensionDirectory = $extension; preparedAt = (Get-Date).ToString('o')
        permissions = $manifest.permissions; hostPermissions = $manifest.host_permissions
    }
    [IO.File]::WriteAllText((Join-Path $run 'receipt.json'), ($receipt | ConvertTo-Json -Depth 20), $Utf8)
    Write-Host "Prepared version: $($manifest.version)" -ForegroundColor Green
    Write-Host "Permissions: $($manifest.permissions -join ', ')"
    Write-Host "Host access: $($manifest.host_permissions -join ', ')"
    Write-Host "`nNOT INSTALLED YET. Finish in the intended Chrome profile:"
    Write-Host '1. Open chrome://extensions and enable Developer mode.'
    Write-Host '2. Click Load unpacked and select the folder below.'
    Write-Host $extension -ForegroundColor Yellow
    Write-Host '3. Open ChatGPT from the toolbar and check the desktop app connection.'
    Write-Host 'Keep this folder. Unpacked extensions do not receive normal store auto-updates.'
    if (-not $PrepareOnly) {
        try { Set-Clipboard -Value $extension; Write-Host 'Folder path copied to clipboard.' } catch { Write-Host 'Copy the path above manually.' }
        Start-Process -FilePath $chrome -ArgumentList 'chrome://extensions/'
    }
    exit 0
} catch {
    Write-Host "`nPreparation failed. Installation was NOT completed." -ForegroundColor Red
    Write-Host $_.Exception.Message
    Write-Host "Official listing: $StoreUrl"
    Write-Host 'If Google blocks the download, this helper cannot guarantee regional availability.'
    Write-Host 'If Chrome is organization-managed, ask its administrator about extension policy.'
    exit 1
}
