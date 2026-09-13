param([int]$PriorPid = 34876, [string]$BuildName = 'r11-account-v2', [string]$CodeSha = 'c17ca4cb7')
$ErrorActionPreference = 'Stop'
$root = 'C:/Users/adrie/Documents/Coelo'
$privateRoot = 'C:/Users/adrie/Documents/Coelo-backups'
$server = "$privateRoot/consolidacao-20260913/runtime-r10/serve.py"
if ($BuildName -notmatch '^r11-account(-v[0-9]+)?$') { throw 'Unexpected build target' }
$build = "$root/apps/superadmin/build/$BuildName"
$prior = Get-CimInstance Win32_Process -Filter "ProcessId=$PriorPid"
if ($prior -and ($prior.CommandLine -notlike '*runtime-r10/serve.py*' -or $prior.CommandLine -notlike '* 3000 127.0.0.1*')) { throw 'Runtime ownership mismatch' }
if (!(Test-Path "$build/main.dart.js")) { throw 'Build missing' }
if ($prior) { Stop-Process -Id $PriorPid }
$runtime = Start-Process python -ArgumentList @($server,$build,'3000','127.0.0.1') -WindowStyle Hidden -RedirectStandardOutput "$privateRoot/r11-runtime.stdout.log" -RedirectStandardError "$privateRoot/r11-runtime.stderr.log" -PassThru
$manifest = @{ code_sha = (git rev-parse $CodeSha); main_dart_js_sha256 = (Get-FileHash "$build/main.dart.js" -Algorithm SHA256).Hash.ToLower(); build = $build; origin = 'http://127.0.0.1:3000'; runtime_pid = $runtime.Id; environment = 'Supabase production; synthetic QA; local QA entrypoint'; generated_at = (Get-Date -Format o) }
$manifest | ConvertTo-Json | Set-Content -Encoding utf8 "$root/docs/reviews/evidence/etapa-2/r11-coordenacao/build-manifest.json"
$manifest | ConvertTo-Json
