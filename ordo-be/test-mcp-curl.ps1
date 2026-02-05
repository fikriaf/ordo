# Test MCP with PowerShell
$API_URL = "http://localhost:3000/api/v1"
$EMAIL = "admin@daemonprotocol.com"
$PASSWORD = "Rade-OrdoApp-Mobile-Bekasi"

Write-Host "Logging in..." -ForegroundColor Yellow
$loginBody = @{email=$EMAIL; password=$PASSWORD} | ConvertTo-Json
$loginResponse = Invoke-RestMethod -Uri "$API_URL/auth/login" -Method Post -Body $loginBody -ContentType "application/json"
$token = $loginResponse.token
Write-Host "Logged in successfully" -ForegroundColor Green

Write-Host "`nTesting Intel API MCP..." -ForegroundColor Yellow
$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type" = "application/json"
}
$response = Invoke-RestMethod -Uri "$API_URL/admin/mcp-test/a9e2d7eb-d4f1-488a-930b-31f8a3bf9b60" -Method Post -Headers $headers -Body "{}"
Write-Host "Success!" -ForegroundColor Green
$response | ConvertTo-Json -Depth 10
