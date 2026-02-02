# Test MCP Direct Connection
Write-Host "=== Testing MCP Direct Connection ===" -ForegroundColor Cyan

# Test Fetch MCP Server directly
Write-Host "`n1. Testing Fetch MCP Server SSE endpoint..." -ForegroundColor Yellow
$uri = 'https://fetch-mcp-server-production-666.up.railway.app/sse'
$req = [System.Net.WebRequest]::Create($uri)
$req.Method = 'GET'
$req.Accept = 'text/event-stream'
$req.Timeout = 5000

try {
    $resp = $req.GetResponse()
    Write-Host "   Status: $($resp.StatusCode)" -ForegroundColor Green
    $reader = New-Object System.IO.StreamReader($resp.GetResponseStream())
    $buffer = New-Object char[] 500
    $count = $reader.Read($buffer, 0, 500)
    $content = New-Object string($buffer, 0, $count)
    Write-Host "   Response: $content" -ForegroundColor White
    
    # Extract session ID
    if ($content -match '/messages\?session_id=([a-f0-9]+)') {
        $sessionId = $matches[1]
        Write-Host "   Session ID: $sessionId" -ForegroundColor Green
        
        # Test sending tools/list request
        Write-Host "`n2. Sending tools/list request..." -ForegroundColor Yellow
        $sessionUrl = "https://fetch-mcp-server-production-666.up.railway.app/messages?session_id=$sessionId"
        $requestBody = @{
            jsonrpc = "2.0"
            method = "tools/list"
            params = @{}
            id = 1
        } | ConvertTo-Json
        
        $postResp = Invoke-RestMethod -Uri $sessionUrl -Method Post -Body $requestBody -ContentType 'application/json' -TimeoutSec 5
        Write-Host "   POST Response: $postResp" -ForegroundColor White
        
        # Wait a bit for SSE response
        Write-Host "`n3. Waiting for SSE response (5 seconds)..." -ForegroundColor Yellow
        Start-Sleep -Seconds 2
        
        # Try to read more from SSE stream
        $buffer2 = New-Object char[] 2000
        $count2 = $reader.Read($buffer2, 0, 2000)
        if ($count2 -gt 0) {
            $content2 = New-Object string($buffer2, 0, $count2)
            Write-Host "   SSE Response: $content2" -ForegroundColor White
        } else {
            Write-Host "   No SSE response received" -ForegroundColor Yellow
        }
    }
    
    $reader.Close()
    $resp.Close()
} catch {
    Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n=== Test Complete ===" -ForegroundColor Cyan
