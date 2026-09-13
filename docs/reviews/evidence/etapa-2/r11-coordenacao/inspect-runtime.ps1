Get-CimInstance Win32_Process | Where-Object { $_.Name -match '^(dart|dartaotruntime|flutter).*\.exe$' } | Select-Object ProcessId,ParentProcessId,Name,CommandLine | ConvertTo-Json -Compress
