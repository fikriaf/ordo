# Test with curl to see if behavior is different
Write-Host "Step 1: Connect to SSE and get session ID" -ForegroundColor Cyan

# Start SSE connection in background job
$job = Start-Job -ScriptBlock {
    $url = "https://fetch-mcp-server-production-666.up.railway.app/sse"
    $response = curl.exe -N -H "Accept: text/event-stream" -H "Cache-Control: no-cache" $url 2>&1
    $response
}

# Wait a bit for session to establish
Start-Sleep -Seconds 3

# Check job output
$output = Receive-Job -Job $job -Keep

Write-Host "SSE Output:" -ForegroundColor Yellow
$output | ForEach-Object { Write-Host $_ }

# Extract session ID
$sessionLine = $output | Where-Object { $_ -match "data: (/messages\?session_id=.+)" }
if ($sessionLine -match "data: (/messages\?session_id=\w+)") {
    $sessionEndpoint = $matches[1]
    Write-Host "`nSession found: $sessionEndpoint" -ForegroundColor Green
    
    # Send POST request
    $postUrl = "https://fetch-mcp-server-production-666.up.railway.app$sessionEndpoint"
    $requestId = [DateTimeOffset]::Now.ToUnixTimeMilliseconds()
    $body = @{
        jsonrpc = "2.0"
        method = "tools/list"
        params = @{}
        id = $requestId
    } | ConvertTo-Json
    
    Write-Host "`nSending POST to: $postUrl" -ForegroundColor Cyan
    Write-Host "Request ID: $requestId" -ForegroundColor Cyan
    Write-Host "Body: $body" -ForegroundColor Gray
    
    $postResponse = Invoke-RestMethod -Uri $postUrl -Method POST -Body $body -ContentType "application/json"
    Write-Host "`nPOST Response: $postResponse" -ForegroundColor Yellow
    
    # Continue reading SSE for response
    Write-Host "`nWaiting for SSE response..." -ForegroundColor Cyan
    Start-Sleep -Seconds 5
    
    $moreOutput = Receive-Job -Job $job -Keep
    Write-Host "`nAdditional SSE output:" -ForegroundColor Yellow
    $moreOutput | Select-Object -Last 20 | ForEach-Object { Write-Host $_ }
} else {
    Write-Host "Could not find session ID" -ForegroundColor Red
}

# Cleanup
Stop-Job -Job $job
Remove-Job -Job $job

Write-Host "`nTest complete" -ForegroundColor Cyan
