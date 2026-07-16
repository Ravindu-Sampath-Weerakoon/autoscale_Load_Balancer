# autoscaler.ps1 - Simple SRE Autoscaling Daemon for ResiliaProxy

$MIN_CONTAINERS = 2
$MAX_CONTAINERS = 5
$SCALE_UP_THRESHOLD = 15.0    # CPU percentage threshold to trigger scale up
$SCALE_DOWN_THRESHOLD = 3.0   # CPU percentage threshold to trigger scale down
$CHECK_INTERVAL_SECS = 5

Write-Host "=============================================" -ForegroundColor Green
Write-Host "  ResiliaProxy SRE Autoscaler Daemon Started " -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green
Write-Host "Monitoring container CPU usage... (Press Ctrl+C to stop)" -ForegroundColor Cyan
Write-Host "Config: Min=$MIN_CONTAINERS, Max=$MAX_CONTAINERS, ScaleUp=$SCALE_UP_THRESHOLD%, ScaleDown=$SCALE_DOWN_THRESHOLD%`n" -ForegroundColor Yellow

# Initialize cluster to minimum scale
$currentScale = $MIN_CONTAINERS
Write-Host "Initializing cluster to minimum scale of $currentScale instances..." -ForegroundColor Gray
docker compose up -d --scale web=$currentScale
# Reload Nginx config to update dynamic host IP resolution
docker exec resiliaproxy_nginx nginx -s reload

while ($true) {
    # Get active container names for the 'web' service dynamically
    $containerNames = docker compose ps web --format "{{.Name}}"
    
    if (-not $containerNames) {
        Write-Host "Warning: No running web containers found. Retrying..." -ForegroundColor Red
        Start-Sleep -Seconds $CHECK_INTERVAL_SECS
        continue
    }
    
    # Get CPU statistics for those specific containers
    $stats = docker stats --no-stream --format "{{.Name}},{{.CPUPerc}}" $containerNames
    
    $cpuTotal = 0.0
    $count = 0
    
    foreach ($line in $stats) {
        $parts = $line.Split(',')
        if ($parts.Length -lt 2) { continue }
        $name = $parts[0]
        # Remove '%' and parse to float/double
        $cpuStr = $parts[1].Replace('%', '').Trim()
        if ([double]::TryParse($cpuStr, [ref]$cpuVal)) {
            $cpuTotal += $cpuVal
            $count++
        }
    }
    
    if ($count -eq 0) {
        Write-Host "Warning: Failed to parse stats. Retrying..." -ForegroundColor Red
        Start-Sleep -Seconds $CHECK_INTERVAL_SECS
        continue
    }
    
    $avgCpu = $cpuTotal / $count
    $timestamp = Get-Date -Format "HH:mm:ss"
    Write-Host "[$timestamp] Active Backend Instances: $count | Avg CPU Load: $($avgCpu.ToString('F2'))%" -ForegroundColor Gray
    
    # --- Scaling Logic ---
    if ($avgCpu -gt $SCALE_UP_THRESHOLD) {
        if ($count -lt $MAX_CONTAINERS) {
            $newScale = $count + 1
            Write-Host "[$timestamp] ⚠️ Alert: Avg CPU ($($avgCpu.ToString('F2'))%) exceeded Scale-Up Threshold ($SCALE_UP_THRESHOLD%)!" -ForegroundColor Red
            Write-Host "[$timestamp] Actions: Scaling UP from $count to $newScale instances..." -ForegroundColor Green
            
            docker compose up -d --scale web=$newScale
            docker exec resiliaproxy_nginx nginx -s reload
            
            Write-Host "[$timestamp] Scale-Up completed. Cooling down for 10 seconds..." -ForegroundColor Gray
            Start-Sleep -Seconds 10
        } else {
            Write-Host "[$timestamp] Warning: Max scale limit ($MAX_CONTAINERS) reached. Cannot scale up further." -ForegroundColor Yellow
        }
    }
    elseif ($avgCpu -lt $SCALE_DOWN_THRESHOLD) {
        if ($count -gt $MIN_CONTAINERS) {
            $newScale = $count - 1
            Write-Host "[$timestamp] ℹ️ Info: Avg CPU ($($avgCpu.ToString('F2'))%) dropped below Scale-Down Threshold ($SCALE_DOWN_THRESHOLD%)!" -ForegroundColor Blue
            Write-Host "[$timestamp] Actions: Scaling DOWN from $count to $newScale instances..." -ForegroundColor DarkYellow
            
            docker compose up -d --scale web=$newScale
            docker exec resiliaproxy_nginx nginx -s reload
            
            Write-Host "[$timestamp] Scale-Down completed. Cooling down for 10 seconds..." -ForegroundColor Gray
            Start-Sleep -Seconds 10
        }
    }
    
    Start-Sleep -Seconds $CHECK_INTERVAL_SECS
}
