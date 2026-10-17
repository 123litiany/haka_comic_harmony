# HarmonyOS port preparation by 123litiany, 2026-10-15. GPL-3.0; see LICENSE.
# Dot-source this file; changes affect only the current PowerShell process.
param(
    [string]$DevEcoRoot = $env:DEVECO_ROOT,
    [string]$FlutterRoot = $env:FLUTTER_OHOS_ROOT
)
$ErrorActionPreference = 'Stop'
$workspaceRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
if (-not $DevEcoRoot) { $DevEcoRoot = 'D:\DEV\DevEco Studio' }
if (-not $FlutterRoot) { $FlutterRoot = Join-Path $workspaceRoot 'flutter-ohos' }
foreach ($requiredPath in @(
    (Join-Path $DevEcoRoot 'sdk\default\sdk-pkg.json'),
    (Join-Path $DevEcoRoot 'tools\node\node.exe'),
    (Join-Path $FlutterRoot 'bin\flutter.bat')
)) {
    if (-not (Test-Path -LiteralPath $requiredPath)) {
        throw "Missing tool: $requiredPath. Set DEVECO_ROOT / FLUTTER_OHOS_ROOT."
    }
}
$env:DEVECO_SDK_HOME = Join-Path $DevEcoRoot 'sdk'
$env:JAVA_HOME = Join-Path $DevEcoRoot 'jbr'
$env:PUB_CACHE = Join-Path $workspaceRoot '.pub-cache'
$env:FLUTTER_OHOS_ROOT = $FlutterRoot
# Skip unrelated desktop plugin symlinks without changing Windows settings.
$env:FLUTTER_WINDOWS = 'false'
$env:FLUTTER_LINUX = 'false'
$env:Path = (@(
    (Join-Path $FlutterRoot 'bin'),
    (Join-Path $DevEcoRoot 'tools\node'),
    (Join-Path $DevEcoRoot 'tools\ohpm\bin'),
    (Join-Path $DevEcoRoot 'tools\hvigor\bin'),
    (Join-Path $DevEcoRoot 'sdk\default\openharmony\toolchains'),
    $env:Path
) -join ';')
