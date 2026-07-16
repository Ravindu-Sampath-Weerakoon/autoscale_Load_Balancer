# stress_test.ps1 - Stress test the ResiliaProxy load balancer to trigger autoscaling

$url = "http://localhost:8080/"
$totalRequests = 1500

Write-Host "=============================================" -ForegroundColor Red
Write-Host "    ResiliaProxy Stress Test Load Generator  " -ForegroundColor Red
Write-Host "=============================================" -ForegroundColor Red
Write-Host "Sending $totalRequests requests asynchronously to generate load at $url..." -ForegroundColor Cyan

# Create WebClient for high speed async execution
$client = New-Object System.Net.WebClient

for ($i = 1; $i -le $totalRequests; $i++) {
    try {
        $client.DownloadStringAsync((New-Object System.Uri($url)))
    } catch {
        # Suppress errors if connection is refused due to overload
    }
    
    if ($i % 100 -eq 0) {
        Write-Host "Dispatched $i requests..." -ForegroundColor Yellow
        # Small delay to keep the local machine stable
        Start-Sleep -Milliseconds 50
    }
}

Write-Host "`nAll requests successfully dispatched! Check the Autoscaler terminal for scale up logs." -ForegroundColor Green
