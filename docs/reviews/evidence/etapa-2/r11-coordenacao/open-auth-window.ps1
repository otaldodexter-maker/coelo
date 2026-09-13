Start-Process -FilePath 'C:/Program Files/Google/Chrome/Application/chrome.exe' -ArgumentList @('--user-data-dir=C:/Users/adrie/Documents/Coelo-backups/r11-chrome', '--incognito', '--new-window', 'http://127.0.0.1:3000/login') -WindowStyle Hidden
Write-Output 'Auth window requested in the same QA Chrome; regular QA session preserved.'
