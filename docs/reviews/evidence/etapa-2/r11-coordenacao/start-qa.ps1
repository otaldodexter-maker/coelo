$qaProfile = 'C:/Users/adrie/Documents/Coelo-backups/r11-chrome'
$qaProcess = Start-Process -FilePath 'C:/Program Files/Google/Chrome/Application/chrome.exe' -ArgumentList @('--remote-debugging-port=9427', "--user-data-dir=$qaProfile", '--no-first-run', '--no-default-browser-check', '--use-angle=swiftshader', 'http://127.0.0.1:3000') -WindowStyle Hidden -PassThru
Write-Output "R11 QA Chrome PID=$($qaProcess.Id) CDP=9427; Owner browser preserved"
