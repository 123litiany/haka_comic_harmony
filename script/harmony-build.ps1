# HarmonyOS port by 123litiany, 2026-10-16. GPL-3.0; see LICENSE.
[CmdletBinding()]
param([ValidateSet('arm64','x64')][string]$Architecture = 'arm64')
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'harmony-env.ps1')
& (Join-Path $PSScriptRoot 'harmony-toolchain.ps1')
$projectRoot = Split-Path $PSScriptRoot -Parent
$abi = if ($Architecture -eq 'arm64') { 'arm64-v8a' } else { 'x86_64' }
$outputDir = Join-Path $projectRoot 'harmony-artifacts'
Push-Location $projectRoot
try {
    # Clear generated caches when switching ABI; the Flutter fork otherwise
    # retains native code assets from the previous architecture in entry/libs.
    flutter clean
    if ($LASTEXITCODE -ne 0) { throw 'Flutter clean failed.' }
    foreach ($oldAbi in @('arm64-v8a','x86_64')) {
        foreach ($name in @('libsqlite3.so','libsqlite3_connection_pool.so','librust_lib_haka_comic.so')) {
            $generatedFile = Join-Path $projectRoot "ohos\entry\libs\$oldAbi\$name"
            if (Test-Path -LiteralPath $generatedFile) { Remove-Item -LiteralPath $generatedFile -Force }
        }
    }
    & (Join-Path $PSScriptRoot 'harmony-native.ps1') -Architecture $Architecture
    flutter pub get --offline
    if ($LASTEXITCODE -ne 0) { throw 'Dependency resolution failed. Run flutter pub get once with network access.' }
    $hapPath = Join-Path $projectRoot 'ohos\entry\build\default\outputs\default\entry-default-unsigned.hap'
    if (Test-Path -LiteralPath $hapPath) { Remove-Item -LiteralPath $hapPath -Force }
    flutter build hap --debug --target-platform "ohos-$Architecture" --no-pub
    $buildExit = $LASTEXITCODE
    if (!(Test-Path -LiteralPath $hapPath)) { throw "No unsigned HAP produced (Flutter exit $buildExit)." }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [IO.Compression.ZipFile]::OpenRead($hapPath)
    try {
        $names = @($archive.Entries | ForEach-Object FullName)
        $manifest = $archive.GetEntry('resources/rawfile/flutter_assets/NativeAssetsManifest.json')
        if (!$manifest) { throw 'Missing native-assets manifest; apply script/harmony-toolchain.ps1 and rebuild.' }
        $reader = [IO.StreamReader]::new($manifest.Open())
        try { $nativeManifest = $reader.ReadToEnd() | ConvertFrom-Json } finally { $reader.Dispose() }
        $nativeAssets = $nativeManifest.'native-assets'.("ohos_$Architecture")
        foreach ($asset in @('package:sqlite3/src/ffi/libsqlite3.g.dart', 'package:sqlite3_connection_pool/sqlite3_connection_pool.dart')) {
            if (!$nativeAssets.$asset) { throw "Missing runtime native asset mapping: $asset" }
        }
        foreach ($name in @('libflutter.so','libsqlite3.so','libsqlite3_connection_pool.so','librust_lib_haka_comic.so')) {
            if ($names -notcontains "libs/$abi/$name") { throw "HAP is missing $abi/$name" }
        }
        $wrongAbi = $names | Where-Object { $_ -match '^libs/([^/]+)/.*\.so$' -and $Matches[1] -ne $abi }
        if ($wrongAbi) { throw "Unexpected architectures in HAP: $wrongAbi" }
    } finally { $archive.Dispose() }
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    $destination = Join-Path $outputDir "haka-ohos-$Architecture-debug-unsigned.hap"
    Copy-Item -LiteralPath $hapPath -Destination $destination -Force
    Get-FileHash -LiteralPath $destination -Algorithm SHA256
    Write-Output "Unsigned debug artifact only; installation and runtime are NOT verified: $destination"
    if ($buildExit -ne 0) { Write-Warning "Flutter exited $buildExit. The archive checks passed, but inspect its output (including signing) before proceeding." }
} finally { Pop-Location }
