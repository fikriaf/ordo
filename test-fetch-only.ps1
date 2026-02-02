# Test with Fetch MCP Only
Write-Host "=== Testing with Fetch MCP Server Only ===" -ForegroundColor Cyan

# Login
$loginBody = @{email='admin@daemonprotocol.com'; password='Rade-OrdoApp-Mobile-Bekasi'} | ConvertTo-Json
$login = Invoke-RestMethod -Uri 'https://api.ordo-assistant.com/api/v1/auth/login' -Method Post -Body $loginBody -ContentType 'application/json'
$headers = @{Authorization="Bearer $($login.data.token)"; 'Content-Type'='application/json'}

# Get all servers
$servers = Invoke-RestMethod -Uri 'https://api.ordo-assistant.com/api/v1/admin/mcp-servers' -Headers $headers

# Disable all except Fetch
Write-Host "`n1. Disabling all MCP servers except Fetch..." -ForegroundColor Yellow
foreach ($server in $servers.data) {
    if ($server.name -ne 'Fetch MCP Server' -and $server.is_enabled) {
        Write-Host "   Disabling: $($server.name)"
        Invoke-RestMethod -Uri "https://api.ordo-assistant.com/api/v1/admin/mcp-servers/$($server.id)/disable" -Method Put -Headers $headers | Out-Null
    }
}

# Verify Fetch is enabled
$fetchServer = $servers.data | Where-Object { $_.name -eq 'Fetch MCP Server' }
if (-not $fetchServer.is_enabled) {
    Write-Host "   Enabling Fetch MCP Server..."
    Invoke-RestMethod -Uri "https://api.ordo-assistant.com/api/v1/admin/mcp-servers/$($fetchServer.id)/enable" -Method Put -Headers $headers | Out-Null
}

Write-Host "   Done!" -ForegroundColor Green

# Wait a bit
Start-Sleep -Seconds 2

# Test chat
Write-Host "`n2. Testing chat..." -ForegroundColor Yellow
$chatBody = @{message='List all available tools'} | ConvertTo-Json
$chat = Invoke-RestMethod -Uri 'https://api.ordo-assistant.com/api/v1/chat' -Method Post -Body $chatBody -Headers $headers -TimeoutSec 45

Write-Host "   Response:" -ForegroundColor Green
Write-Host $chat.data.message

Write-Host "`n=== Test Complete ===" -ForegroundColor Cyan
