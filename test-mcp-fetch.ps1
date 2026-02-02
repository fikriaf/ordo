# Test MCP Fetch Integration
Write-Host "=== Testing MCP Fetch Integration ===" -ForegroundColor Cyan

# Login
Write-Host "`n1. Logging in..." -ForegroundColor Yellow
$loginBody = @{
    email = 'admin@daemonprotocol.com'
    password = 'Rade-OrdoApp-Mobile-Bekasi'
} | ConvertTo-Json

$login = Invoke-RestMethod -Uri 'https://api.ordo-assistant.com/api/v1/auth/login' -Method Post -Body $loginBody -ContentType 'application/json'
$headers = @{
    Authorization = "Bearer $($login.data.token)"
    'Content-Type' = 'application/json'
}
Write-Host "   Login successful!" -ForegroundColor Green

# List MCP Servers
Write-Host "`n2. Listing MCP servers..." -ForegroundColor Yellow
$servers = Invoke-RestMethod -Uri 'https://api.ordo-assistant.com/api/v1/admin/mcp-servers' -Headers $headers
Write-Host "   Found $($servers.count) servers:" -ForegroundColor Green
$servers.data | ForEach-Object {
    $status = if ($_.is_enabled) { "ENABLED" } else { "DISABLED" }
    Write-Host "   - $($_.name) ($($_.transport_type)) - $status"
}

# Test Chat
Write-Host "`n3. Testing chat with simple question..." -ForegroundColor Yellow
$chatBody = @{
    message = 'Hello! Can you list what tools you have available?'
} | ConvertTo-Json

try {
    $chat = Invoke-RestMethod -Uri 'https://api.ordo-assistant.com/api/v1/chat' -Method Post -Body $chatBody -Headers $headers -TimeoutSec 45
    Write-Host "   Chat response received!" -ForegroundColor Green
    if ($chat.data.response) {
        $responseText = $chat.data.response
        $preview = if ($responseText.Length -gt 300) { $responseText.Substring(0, 300) + "..." } else { $responseText }
        Write-Host "   Response: $preview" -ForegroundColor White
    } else {
        Write-Host "   Response: $($chat | ConvertTo-Json -Depth 3)" -ForegroundColor White
    }
} catch {
    Write-Host "   Chat failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n=== Test Complete ===" -ForegroundColor Cyan
