# HarmonyOS port by 123litiany, 2026-10-16. GPL-3.0; see LICENSE.
[CmdletBinding()]
param([ValidateSet('arm64','x64')][string]$Architecture = 'arm64')
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'harmony-env.ps1')
$projectRoot = Split-Path $PSScriptRoot -Parent
$workspaceRoot = Split-Path $projectRoot -Parent
$nativeSdk = Join-Path $env:DEVECO_SDK_HOME 'default\openharmony\native'
$clang = Join-Path $nativeSdk 'llvm\bin\clang.exe'
$sysroot = Join-Path $nativeSdk 'sysroot'
$env:CARGO_HOME = Join-Path $workspaceRoot 'cargo'
$env:RUSTUP_HOME = Join-Path $workspaceRoot 'rustup'
$env:Path = (Join-Path $env:CARGO_HOME 'bin') + ';' + $env:Path
$triple = if ($Architecture -eq 'arm64') { 'aarch64-unknown-linux-ohos' } else { 'x86_64-unknown-linux-ohos' }
$abi = if ($Architecture -eq 'arm64') { 'arm64-v8a' } else { 'x86_64' }
$targetKey = $triple.Replace('-','_')
Set-Item -Path ('Env:CARGO_TARGET_' + $targetKey.ToUpperInvariant() + '_LINKER') -Value $clang
Set-Item -Path ('Env:CC_' + $targetKey) -Value $clang
Set-Item -Path ('Env:AR_' + $targetKey) -Value (Join-Path $nativeSdk 'llvm\bin\llvm-ar.exe')
$env:CC_SHELL_ESCAPED_FLAGS = '1'
Set-Item -Path ('Env:CFLAGS_' + $targetKey) -Value ('--target=' + $triple + ' --sysroot="' + $sysroot.Replace('\','/') + '"')
$env:CARGO_ENCODED_RUSTFLAGS = @('-C',"link-arg=--target=$triple",'-C',"link-arg=--sysroot=$sysroot") -join [char]31
$rustHost = Join-Path $env:RUSTUP_HOME 'toolchains\stable-x86_64-pc-windows-gnu\lib\rustlib\x86_64-pc-windows-gnu\bin\rust-lld.exe'
if (Test-Path -LiteralPath $rustHost) { $env:CARGO_TARGET_X86_64_PC_WINDOWS_GNU_LINKER = $rustHost }

$sqliteOut = Join-Path $projectRoot "third_party\sqlite3\ohos-lib\$Architecture"
$poolOut = Join-Path $projectRoot "third_party\sqlite3_connection_pool\ohos-lib\$Architecture"
$rustOut = Join-Path $projectRoot "ohos\entry\libs\$abi"
foreach ($outDir in @($sqliteOut,$poolOut,$rustOut)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
& $clang "--target=$triple" "--sysroot=$sysroot" -shared -fPIC -O2 '-Wl,-soname,libsqlite3.so' -DSQLITE_THREADSAFE=1 -DSQLITE_ENABLE_FTS5 -DSQLITE_ENABLE_RTREE -DSQLITE_ENABLE_DBSTAT_VTAB -DSQLITE_ENABLE_COLUMN_METADATA -DSQLITE_ENABLE_SESSION -DSQLITE_ENABLE_PREUPDATE_HOOK -DSQLITE_ENABLE_SNAPSHOT -DSQLITE_ENABLE_MATH_FUNCTIONS (Join-Path $projectRoot 'third_party\sqlite-amalgamation\sqlite3.c') -lm -o (Join-Path $sqliteOut 'libsqlite3.so')
if ($LASTEXITCODE -ne 0) { throw 'SQLite cross-compilation failed.' }

$env:CARGO_TARGET_DIR = Join-Path $workspaceRoot 'native-build\pool'
cargo build --manifest-path (Join-Path $projectRoot 'third_party\sqlite3_connection_pool\Cargo.toml') --release --target $triple --locked
if ($LASTEXITCODE -ne 0) { throw 'SQLite pool cross-compilation failed.' }
Copy-Item -LiteralPath (Join-Path $env:CARGO_TARGET_DIR "$triple\release\libsqlite3_connection_pool.so") -Destination $poolOut -Force

$env:CARGO_TARGET_DIR = Join-Path $workspaceRoot 'native-build\haka'
cargo build --manifest-path (Join-Path $projectRoot 'rust\Cargo.toml') --release --target $triple --locked
if ($LASTEXITCODE -ne 0) { throw 'HaKa Rust cross-compilation failed.' }
Copy-Item -LiteralPath (Join-Path $env:CARGO_TARGET_DIR "$triple\release\librust_lib_haka_comic.so") -Destination $rustOut -Force

# Fail before packaging if any generated library accidentally targets glibc.
$readelf = Join-Path $nativeSdk 'llvm\bin\llvm-readelf.exe'
foreach ($library in @((Join-Path $sqliteOut 'libsqlite3.so'),(Join-Path $poolOut 'libsqlite3_connection_pool.so'),(Join-Path $rustOut 'librust_lib_haka_comic.so'))) {
    $dynamic = & $readelf -d $library
    if ($LASTEXITCODE -ne 0 -or ($dynamic -match 'libc\.so\.6|ld-linux')) { throw "Invalid OHOS library: $library" }
}
Write-Output "Native libraries ready: $Architecture"
