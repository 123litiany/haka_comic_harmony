# HarmonyOS port by 123litiany, 2026-10-16. GPL-3.0; see LICENSE.
# Repairs the pinned Flutter OHOS canary's missing native-assets manifest.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'harmony-env.ps1')
$flutterCommand = (Get-Command flutter.bat).Source
$sdkRoot = Split-Path (Split-Path $flutterCommand -Parent) -Parent
$target = Join-Path $sdkRoot 'packages\flutter_tools\lib\src\build_system\targets\ohos.dart'
$source = [IO.File]::ReadAllText($target).Replace("`r`n", "`n")
$marker = "'NativeAssetsManifest.json': DevFSFileContent("
if ($source.Contains($marker)) {
    Write-Output 'OHOS native-assets manifest patch already present.'
    return
}
$importAnchor = "import '../../base/deferred_component.dart';"
$contentAnchor = '      flavor: environment.defines[kFlavor],'
if (!$source.Contains($importAnchor) -or !$source.Contains($contentAnchor)) {
    throw 'Unknown Flutter OHOS source layout; inspect this SDK before applying the patch.'
}
$source = $source.Replace($importAnchor, "$importAnchor`nimport '../../devfs.dart';")
$addition = @'
      flavor: environment.defines[kFlavor],
      // HaKa port: mirror Android's native asset manifest packaging.
      additionalContent: <String, DevFSContent>{
        'NativeAssetsManifest.json': DevFSFileContent(
          environment.buildDir.childFile('native_assets.json'),
        ),
      },
'@
$source = $source.Replace($contentAnchor, $addition.Replace("`r`n", "`n"))
[IO.File]::WriteAllText($target, $source, (New-Object Text.UTF8Encoding($false)))
# Rebuild only Flutter's generated tool cache, never user files or the SDK tree.
foreach ($file in @('flutter_tools.snapshot','flutter_tools.stamp')) {
    $cacheFile = Join-Path $sdkRoot "bin\cache\$file"
    if (Test-Path -LiteralPath $cacheFile) { Remove-Item -LiteralPath $cacheFile -Force }
}
Write-Output 'Patched OHOS native-assets manifest packaging. Flutter will rebuild its tool cache.'
