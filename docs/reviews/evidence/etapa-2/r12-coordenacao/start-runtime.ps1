param([string]$BuildName = 'r11-account-v3')
$ErrorActionPreference = 'Stop'
$root = 'C:/Users/adrie/Documents/Coelo'
$privateRoot = 'C:/Users/adrie/Documents/Coelo-backups'
if ($BuildName -notmatch '^(r11-account-v3|r12-focal)$') { throw 'Unexpected build target' }
if (Get-NetTCPConnection -LocalPort 3000 -State Listen -ErrorAction SilentlyContinue) { throw 'Port 3000 already owned' }
$build = "$root/apps/superadmin/build/$BuildName"
if (!(Test-Path "$build/main.dart.js")) { throw 'Build missing' }
& python "$PSScriptRoot/start-runtime.py" $BuildName
exit $LASTEXITCODE
