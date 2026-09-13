param([string]$BuildName = 'r11-account-v3')
$ErrorActionPreference = 'Stop'
$root = 'C:/Users/adrie/Documents/Coelo'
$privateRoot = 'C:/Users/adrie/Documents/Coelo-backups'
if ($BuildName -notmatch '^(r11-account-v3|r12-focal)$') { throw 'Unexpected build target' }
if (Get-NetTCPConnection -LocalPort 3000 -State Listen -ErrorAction SilentlyContinue) { throw 'Port 3000 already owned' }
$build = "$root/apps/superadmin/build/$BuildName"
if (!(Test-Path "$build/main.dart.js")) { throw 'Build missing' }
$runtime = Start-Process python -ArgumentList @("$privateRoot/consolidacao-20260913/runtime-r10/serve.py", $build, '3000', '127.0.0.1') -WindowStyle Hidden -RedirectStandardOutput "$privateRoot/r12-runtime.stdout.log" -RedirectStandardError "$privateRoot/r12-runtime.stderr.log" -PassThru
Write-Output "R12 runtime PID=$($runtime.Id) port=3000 build=$BuildName"
