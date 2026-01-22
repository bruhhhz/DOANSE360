<#
Synthetic Payment Test (PowerShell)

Usage examples:
# Run 50 requests with 1s interval (default):
#   .\synthetic-payment-test.ps1

# Run 100 requests with 0.2s interval:
#   .\synthetic-payment-test.ps1 -Count 100 -IntervalSeconds 0.2

# Parameters:
#   -Count: number of requests to send
#   -IntervalSeconds: seconds to wait between requests (supports fractional)
#   -Url: target endpoint
#   -TimeoutSeconds: timeout per request (s)
#
# The script requires PowerShell 5.1+ (Windows). It uses Invoke-RestMethod and prints a summary including
# success/fail counts, average duration, p50 and p95 latencies (ms).
#
# The script is safe to run locally against your dev server.
#>

param(
    [int]$Count = 50,
    [double]$IntervalSeconds = 1,
    [string]$Url = 'http://localhost:3004/payments',
    [int]$TimeoutSeconds = 10
)

$headers = @{ 'Content-Type' = 'application/json' }
$results = @()

Write-Host "Running synthetic payment test: Count=$Count, IntervalSeconds=$IntervalSeconds, Url=$Url" -ForegroundColor Cyan

for ($i = 1; $i -le $Count; $i++) {
    $bodyObj = @{ 
        amount = Get-Random -Minimum 100 -Maximum 20000
        trip_id = 1
        user_id = 1
        payment_method = "card"
        currency = "VND"
    }
    $body = $bodyObj | ConvertTo-Json

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $resp = Invoke-RestMethod -Uri $Url -Method Post -Headers $headers -Body $body -TimeoutSec $TimeoutSeconds
        $sw.Stop()
        $results += [pscustomobject]@{
            Index = $i
            Success = $true
            DurationMs = $sw.ElapsedMilliseconds
            Status = if ($resp -is [string]) { $resp } else { ($resp | ConvertTo-Json -Compress) }
            Error = $null
        }
        Write-Host "[$i] OK ${($sw.ElapsedMilliseconds)}ms" -ForegroundColor Green
    }
    catch {
        $sw.Stop()
        $errText = $_ | Out-String
        $results += [pscustomobject]@{
            Index = $i
            Success = $false
            DurationMs = $sw.ElapsedMilliseconds
            Status = $null
            Error = $errText.Trim()
        }
        Write-Host "[$i] FAIL ${($sw.ElapsedMilliseconds)}ms" -ForegroundColor Red
    }

    if ($i -lt $Count) {
        Start-Sleep -Seconds $IntervalSeconds
    }
}

# Summary
$total = $results.Count
$successCount = ($results | Where-Object { $_.Success }).Count
$failCount = $total - $successCount
$successRate = [math]::Round(($successCount / $total) * 100, 2)

$successDurations = $results | Where-Object { $_.Success } | Select-Object -ExpandProperty DurationMs

if ($successDurations.Count -gt 0) {
    $avg = [math]::Round(($successDurations | Measure-Object -Average).Average, 2)
    $sorted = $successDurations | Sort-Object
    $n = $sorted.Count
    $p50idx = [math]::Max([math]::Ceiling(0.5 * $n) - 1, 0)
    $p95idx = [math]::Max([math]::Ceiling(0.95 * $n) - 1, 0)
    $p50 = $sorted[$p50idx]
    $p95 = $sorted[$p95idx]
} else {
    $avg = $null
    $p50 = $null
    $p95 = $null
}

Write-Host "\n=== Synthetic Test Summary ===" -ForegroundColor Cyan
Write-Host "Total requests: $total"
Write-Host "Success: $successCount, Fail: $failCount, SuccessRate: $successRate%"
if ($avg -ne $null) {
    Write-Host "Avg Duration (ms): $avg"
    Write-Host "p50 Duration (ms): $p50"
    Write-Host "p95 Duration (ms): $p95"
}

# Optionally write results to a CSV file in the current directory
$timestamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
$csvPath = "synthetic-payment-results-$timestamp.csv"
$results | Export-Csv -Path $csvPath -NoTypeInformation | Out-Null
Write-Host "Detailed results exported to $csvPath"
