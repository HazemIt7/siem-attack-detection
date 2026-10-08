# Wazuh Active Response: remove-threat.ps1 (Windows)
# Automatically deletes malicious files flagged by VirusTotal

$logFile = "C:\Program Files (x86)\ossec-agent\active-response\active-responses.log"

function Write-ARLog ($msg) {
    $time = (Get-Date).ToString("yyyy/MM/dd HH:mm:ss")
    Add-Content -Path $logFile -Value "$time active-response/remove-threat: $msg" -ErrorAction SilentlyContinue
}

try {
    $rawInput = [Console]::In.ReadToEnd()
    if (-not $rawInput) {
        Write-ARLog "No input data received from stdin."
        exit 0
    }

    $json = $rawInput | ConvertFrom-Json
    $alert = $json.parameters.alert
    if (-not $alert) { $alert = $json.alert }

    # Extract target file path
    $filePath = $alert.data.virustotal.source.file
    if (-not $filePath) { $filePath = $alert.syscheck.path }

    if (-not $filePath) {
        Write-ARLog "Could not find file path in alert JSON."
        exit 0
    }

    # Safety checks
    if ($filePath -match "^C:\\Windows\\System32" -or $filePath -match "^C:\\Windows\\SysWOW64") {
        Write-ARLog "SAFETY ABORT: Refusing to delete System32 path: $filePath"
        exit 0
    }

    if (Test-Path -Path $filePath) {
        Remove-Item -Path $filePath -Force -ErrorAction Stop
        Write-ARLog "SUCCESS: Malicious file permanently removed: $filePath"
    } else {
        Write-ARLog "File was already removed or does not exist: $filePath"
    }
} catch {
    Write-ARLog "ERROR: $($_.Exception.Message)"
}

exit 0
