# load_test.ps1 - Simulate concurrent traffic load on ResiliaProxy

$url = "http://localhost:8080/"
$totalRequests = 100
$jobs = @()

Write-Host "Simulating $totalRequests concurrent requests to ResiliaProxy at $url..." -ForegroundColor Cyan

# Start background jobs to send requests concurrently
for ($i = 1; $i -le $totalRequests; $i++) {
    $jobs += Start-Job -ScriptBlock {
        param($targetUrl)
        try {
            # Disable progress bar to make it faster
            $ProgressPreference = 'SilentlyContinue'
            $resp = Invoke-RestMethod -Uri $targetUrl -Method Get -TimeoutSec 2
            return $resp.hostname
        } catch {
            return "Failed: $_"
        }
    } -ArgumentList $url
}

# Wait for all requests to finish
Write-Host "Waiting for responses..." -ForegroundColor Yellow
$results = $jobs | Wait-Job | Receive-Job
Remove-Job $jobs

# Group and count the responses to see load distribution
Write-Host "`n--- Traffic Distribution Results ---" -ForegroundColor Green
$results | Group-Object | Select-Object Name, Count | Format-Table -AutoSize
