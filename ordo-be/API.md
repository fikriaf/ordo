# Ordo Backend API Documentation

## Overview

Ordo Backend adalah REST API untuk aplikasi AI assistant yang dapat melakukan 60+ operasi blockchain Solana melalui natural language.

**Base URL**: `http://localhost:3000/api/v1`

**Version**: 1.0.0

## Authentication

Semua endpoint (kecuali `/auth/register` dan `/auth/login`) memerlukan JWT token di header:

```
Authorization: Bearer <token>
```

## Rate Limiting

- **Global**: 100 requests/minute per IP
- **Auth endpoints**: 10 requests/minute per IP
- **Admin endpoints**: 50 requests/minute per IP

## Response Format

### Success Response
```json
{
  "success": true,
  "data": { ... }
}
```

### Error Response
```json
{
  "success": false,
  "error": "Error message"
}
```

---

## Authentication Endpoints

### Register User
**POST** `/auth/register`

Register user baru.

**Request Body:**
```json
{
  "email": "user@example.com",
  "password": "Password123!",
  "name": "John Doe"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "user": {
      "id": "uuid",
      "email": "user@example.com",
      "name": "John Doe",
      "role": "user"
    },
    "token": "jwt_token"
  }
}
```

### Login
**POST** `/auth/login`

Login dan dapatkan JWT token.

**Request Body:**
```json
{
  "email": "user@example.com",
  "password": "Password123!"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "user": {
      "id": "uuid",
      "email": "user@example.com",
      "name": "John Doe",
      "role": "user"
    },
    "token": "jwt_token"
  }
}
```

### Refresh Token
**POST** `/auth/refresh`

Refresh JWT token yang akan expired.

**Headers:**
```
Authorization: Bearer <old_token>
```

**Response:**
```json
{
  "success": true,
  "data": {
    "token": "new_jwt_token"
  }
}
```

---

## Wallet Endpoints

### Create Wallet
**POST** `/wallet/create`

Buat wallet Solana baru.

**Headers:**
```
Authorization: Bearer <token>
```

**Response:**
```json
{
  "success": true,
  "data": {
    "id": "wallet_uuid",
    "public_key": "CuSWTUgxq8PJpDhnkXHF123TDrSTSUyFKVGHv4rj9176",
    "is_primary": true,
    "created_at": "2026-02-01T00:00:00Z"
  }
}
```

### Import Wallet
**POST** `/wallet/import`

Import wallet dari private key.

**Headers:**
```
Authorization: Bearer <token>
```

**Request Body:**
```json
{
  "privateKey": "base58_encoded_private_key"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "id": "wallet_uuid",
    "public_key": "...",
    "is_primary": false,
    "created_at": "2026-02-01T00:00:00Z"
  }
}
```

### Get Wallet Balance
**GET** `/wallet/:id/balance`

Query balance SOL dan SPL tokens.

**Headers:**
```
Authorization: Bearer <token>
```

**Response:**
```json
{
  "success": true,
  "data": {
    "sol": 1.5,
    "tokens": [
      {
        "mint": "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v",
        "amount": 100.5,
        "decimals": 6
      }
    ]
  }
}
```

### List User Wallets
**GET** `/wallets`

List semua wallet user.

**Headers:**
```
Authorization: Bearer <token>
```

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": "wallet_uuid",
      "public_key": "...",
      "is_primary": true,
      "created_at": "2026-02-01T00:00:00Z"
    }
  ]
}
```

---

## Chat Endpoints

### Send Message (Non-Streaming)
**POST** `/chat`

Kirim message ke AI agent.

**Headers:**
```
Authorization: Bearer <token>
```

**Request Body:**
```json
{
  "message": "What is the price of SOL?",
  "conversationId": "optional_conversation_uuid"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "response": "The current price of SOL is $150.25",
    "conversationId": "conversation_uuid",
    "toolCalls": [
      {
        "name": "get_sol_price",
        "result": { "price": 150.25 }
      }
    ]
  }
}
```

### Send Message (Streaming)
**POST** `/chat/stream`

Kirim message dengan streaming response (SSE).

**Headers:**
```
Authorization: Bearer <token>
Content-Type: application/json
```

**Request Body:**
```json
{
  "message": "Tell me about Solana",
  "conversationId": "optional_conversation_uuid"
}
```

**Response:** Server-Sent Events stream
```
data: {"token": "Solana"}
data: {"token": " is"}
data: {"token": " a"}
...
data: [DONE]
```

### Get Conversations
**GET** `/conversations`

List semua conversations user.

**Headers:**
```
Authorization: Bearer <token>
```

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": "conversation_uuid",
      "user_id": "user_uuid",
      "status": "active",
      "created_at": "2026-02-01T00:00:00Z",
      "updated_at": "2026-02-01T00:00:00Z"
    }
  ]
}
```

### Get Conversation Messages
**GET** `/conversations/:id/messages`

Get messages dari conversation tertentu.

**Headers:**
```
Authorization: Bearer <token>
```

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": "message_uuid",
      "conversation_id": "conversation_uuid",
      "role": "user",
      "content": "What is the price of SOL?",
      "created_at": "2026-02-01T00:00:00Z"
    },
    {
      "id": "message_uuid",
      "conversation_id": "conversation_uuid",
      "role": "assistant",
      "content": "The current price of SOL is $150.25",
      "created_at": "2026-02-01T00:00:00Z"
    }
  ]
}
```

---

## Action Endpoints

### List Available Actions
**GET** `/actions`

List semua actions yang tersedia dari enabled plugins.

**Headers:**
```
Authorization: Bearer <token>
```

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "name": "get_balance",
      "description": "Get wallet balance",
      "plugin": "solana-token",
      "parameters": []
    },
    {
      "name": "get_sol_price",
      "description": "Get current SOL price",
      "plugin": "price-feed",
      "parameters": []
    }
  ]
}
```

### Execute Action
**POST** `/actions/:actionName`

Execute action secara langsung.

**Headers:**
```
Authorization: Bearer <token>
```

**Request Body:**
```json
{
  "params": {}
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "result": { ... }
  }
}
```

---

## Transaction Endpoints

### Get Transaction History
**GET** `/transactions`

Get transaction history dengan pagination dan filtering.

**Headers:**
```
Authorization: Bearer <token>
```

**Query Parameters:**
- `page` (optional): Page number (default: 1)
- `limit` (optional): Items per page (default: 10)
- `type` (optional): Filter by transaction type
- `status` (optional): Filter by status (pending/confirmed/failed)
- `startDate` (optional): Filter by start date (ISO 8601)
- `endDate` (optional): Filter by end date (ISO 8601)

**Response:**
```json
{
  "success": true,
  "data": {
    "transactions": [
      {
        "id": "tx_uuid",
        "signature": "solana_signature",
        "type": "transfer",
        "status": "confirmed",
        "amount": 1.5,
        "created_at": "2026-02-01T00:00:00Z"
      }
    ],
    "pagination": {
      "page": 1,
      "limit": 10,
      "total": 50,
      "totalPages": 5
    }
  }
}
```

### Get Transaction Details
**GET** `/transactions/:id`

Get detail transaction tertentu.

**Headers:**
```
Authorization: Bearer <token>
```

**Response:**
```json
{
  "success": true,
  "data": {
    "id": "tx_uuid",
    "signature": "solana_signature",
    "type": "transfer",
    "status": "confirmed",
    "amount": 1.5,
    "metadata": { ... },
    "created_at": "2026-02-01T00:00:00Z",
    "updated_at": "2026-02-01T00:00:00Z"
  }
}
```

---

## Admin Endpoints

**Note:** Semua admin endpoints memerlukan role `admin`.

### Dashboard Metrics
**GET** `/admin/dashboard`

Get dashboard metrics.

**Headers:**
```
Authorization: Bearer <admin_token>
```

**Response:**
```json
{
  "success": true,
  "data": {
    "activeUsers": 14,
    "totalUsers": 14,
    "totalTransactions": 0,
    "successRate": 0,
    "averageResponseTime": 250,
    "errorRate": 0,
    "pendingTransactions": 0
  }
}
```

### User Management

#### List Users
**GET** `/admin/users`

**Query Parameters:**
- `page` (optional): Page number
- `limit` (optional): Items per page

#### Get User Details
**GET** `/admin/users/:id`

#### Delete User
**DELETE** `/admin/users/:id`

### AI Model Management

#### List Models
**GET** `/admin/models`

#### Create Model
**POST** `/admin/models`

**Request Body:**
```json
{
  "name": "GPT-4",
  "provider": "openai",
  "modelId": "gpt-4",
  "config": {
    "maxTokens": 2000,
    "temperature": 0.7
  }
}
```

#### Update Model
**PUT** `/admin/models/:id`

#### Delete Model
**DELETE** `/admin/models/:id`

#### Set Default Model
**PUT** `/admin/models/:id/default`

#### Enable/Disable Model
**PUT** `/admin/models/:id/enable`
**PUT** `/admin/models/:id/disable`

### Plugin Management

#### List Plugins
**GET** `/admin/plugins`

#### Create Plugin
**POST** `/admin/plugins`

#### Update Plugin
**PUT** `/admin/plugins/:id`

#### Delete Plugin
**DELETE** `/admin/plugins/:id`

#### Enable/Disable Plugin
**PUT** `/admin/plugins/:id/enable`
**PUT** `/admin/plugins/:id/disable`

### Configuration Management

#### Get Configuration
**GET** `/admin/config`

#### Update Configuration
**PUT** `/admin/config`

**Request Body:**
```json
{
  "key": "config_key",
  "value": "config_value"
}
```

#### Get Configuration History
**GET** `/admin/config/history`

#### Rollback Configuration
**POST** `/admin/config/rollback/:version`

### Audit Logs

#### Get Audit Logs
**GET** `/admin/audit-logs`

**Query Parameters:**
- `page` (optional): Page number
- `limit` (optional): Items per page
- `action` (optional): Filter by action type
- `adminId` (optional): Filter by admin ID

---

## Health Check Endpoints

### Basic Health Check
**GET** `/health`

Check if server is running.

**Response:**
```json
{
  "status": "ok",
  "timestamp": "2026-02-01T00:00:00Z"
}
```

### Detailed Health Check
**GET** `/health/detailed`

Check all dependencies.

**Response:**
```json
{
  "status": "healthy",
  "timestamp": "2026-02-01T00:00:00Z",
  "uptime": 170,
  "version": "1.0.0",
  "dependencies": {
    "database": {
      "status": "healthy",
      "responseTime": 552,
      "lastChecked": "2026-02-01T00:00:00Z"
    },
    "solanaRpc": {
      "status": "healthy",
      "responseTime": 611,
      "lastChecked": "2026-02-01T00:00:00Z"
    },
    "openRouter": {
      "status": "healthy",
      "responseTime": 137,
      "lastChecked": "2026-02-01T00:00:00Z"
    }
  }
}
```

---

## Error Codes

| Status Code | Description |
|-------------|-------------|
| 200 | Success |
| 201 | Created |
| 400 | Bad Request |
| 401 | Unauthorized |
| 403 | Forbidden |
| 404 | Not Found |
| 409 | Conflict |
| 429 | Too Many Requests |
| 500 | Internal Server Error |
| 503 | Service Unavailable |

---

## Security

### Input Sanitization
- SQL injection patterns diblokir
- XSS payloads diblokir
- Semua malicious attempts di-log

### Data Encryption
- Private keys dienkripsi dengan AES-256-GCM
- Passwords di-hash dengan bcrypt (10 salt rounds)
- JWT tokens dengan 24-hour expiration

### Rate Limiting
- Global: 100 req/min
- Auth: 10 req/min
- Admin: 50 req/min

---

## Examples

### Complete Flow Example

```bash
# 1. Register
curl -X POST http://localhost:3000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"Pass123!","name":"John"}'

# 2. Login
TOKEN=$(curl -X POST http://localhost:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"Pass123!"}' \
  | jq -r '.data.token')

# 3. Create Wallet
curl -X POST http://localhost:3000/api/v1/wallet/create \
  -H "Authorization: Bearer $TOKEN"

# 4. Get Balance
curl -X GET http://localhost:3000/api/v1/wallet/{wallet_id}/balance \
  -H "Authorization: Bearer $TOKEN"

# 5. Chat with AI
curl -X POST http://localhost:3000/api/v1/chat \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"message":"What is the price of SOL?"}'
```

---

## Support

Untuk pertanyaan atau issues, silakan hubungi tim development.
