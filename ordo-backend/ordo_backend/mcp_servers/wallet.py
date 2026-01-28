"""
Wallet MCP Server

FastMCP server for Solana wallet operations via Helius.
Provides tools for portfolio viewing, transaction history, and transaction building.

Tools:
- get_wallet_portfolio: Get wallet portfolio (tokens + NFTs)
- get_token_balances: Get token balances
- get_transaction_history: Get transaction history
- get_priority_fee_estimate: Get priority fee estimates
- build_transfer_transaction: Build transfer transaction

Resources:
- wallet://portfolio: Wallet portfolio as a resource
- wallet://transactions: Transaction history as a resource
"""

from fastmcp import FastMCP
from typing import List, Dict, Any, Optional
from datetime import datetime
import httpx
import os

# Create MCP server
mcp = FastMCP("Ordo Wallet Server")

# Get Helius API key from environment
HELIUS_API_KEY = os.getenv("HELIUS_API_KEY", "")


@mcp.tool()
async def get_wallet_portfolio(
    address: str,
    helius_api_key: str,
    user_id: str
) -> Dict[str, Any]:
    """
    Get wallet portfolio using Helius DAS API.
    
    Args:
        address: Wallet address
        helius_api_key: Helius API key
        user_id: User ID for audit logging
    
    Returns:
        Portfolio with tokens, NFTs, and total value
    """
    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            # Get assets using Helius DAS API
            response = await client.post(
                f"https://mainnet.helius-rpc.com/?api-key={helius_api_key}",
                json={
                    "jsonrpc": "2.0",
                    "id": "ordo-portfolio",
                    "method": "getAssetsByOwner",
                    "params": {
                        "ownerAddress": address,
                        "page": 1,
                        "limit": 1000,
                        "displayOptions": {
                            "showFungibleTokens": True,
                            "showNativeBalance": True
                        }
                    }
                },
                headers={"Content-Type": "application/json"}
            )
            response.raise_for_status()
            data = response.json()
        
        # Parse assets into tokens and NFTs
        result = data.get("result", {})
        assets = result.get("items", [])
        native_balance = result.get("nativeBalance", {})
        
        tokens = []
        nfts = []
        total_value_usd = 0.0
        
        # Add native SOL balance
        if native_balance:
            sol_lamports = native_balance.get("lamports", 0)
            sol_balance = sol_lamports / 1_000_000_000  # Convert lamports to SOL
            
            # Get SOL price (simplified - in production, use price API)
            sol_price_usd = 100.0  # Placeholder
            sol_value_usd = sol_balance * sol_price_usd
            total_value_usd += sol_value_usd
            
            tokens.append({
                "mint": "So11111111111111111111111111111111111111112",
                "symbol": "SOL",
                "name": "Solana",
                "balance": sol_balance,
                "decimals": 9,
                "valueUsd": sol_value_usd,
                "priceChange24h": 0.0
            })
        
        # Parse other assets
        for asset in assets:
            interface = asset.get("interface", "")
            
            if interface == "FungibleToken":
                # Parse fungible token
                token_info = asset.get("token_info", {})
                content = asset.get("content", {})
                metadata = content.get("metadata", {})
                
                balance_raw = float(token_info.get("balance", 0))
                decimals = token_info.get("decimals", 0)
                balance = balance_raw / (10 ** decimals) if decimals > 0 else balance_raw
                
                price_info = token_info.get("price_info", {})
                price_usd = price_info.get("price_per_token", 0.0)
                value_usd = balance * price_usd
                total_value_usd += value_usd
                
                tokens.append({
                    "mint": asset.get("id", ""),
                    "symbol": metadata.get("symbol", "UNKNOWN"),
                    "name": metadata.get("name", "Unknown Token"),
                    "balance": balance,
                    "decimals": decimals,
                    "valueUsd": value_usd,
                    "priceChange24h": 0.0  # Would need additional API call
                })
            
            elif interface in ["NFT", "ProgrammableNFT", "CompressedNFT"]:
                # Parse NFT
                content = asset.get("content", {})
                metadata = content.get("metadata", {})
                links = content.get("links", {})
                grouping = asset.get("grouping", [])
                
                collection_address = ""
                if grouping:
                    collection_address = grouping[0].get("group_value", "")
                
                nfts.append({
                    "mint": asset.get("id", ""),
                    "name": metadata.get("name", "Unknown NFT"),
                    "collection": collection_address,
                    "imageUrl": links.get("image", ""),
                    "floorPriceSol": None  # Would need marketplace API
                })
        
        return {
            "address": address,
            "totalValueUsd": total_value_usd,
            "tokens": tokens,
            "nfts": nfts,
            "lastUpdated": datetime.now().isoformat()
        }
    
    except httpx.HTTPStatusError as e:
        return {
            "error": f"Helius API error: {e.response.status_code}",
            "address": address,
            "totalValueUsd": 0.0,
            "tokens": [],
            "nfts": []
        }
    except Exception as e:
        return {
            "error": f"Failed to fetch portfolio: {str(e)}",
            "address": address,
            "totalValueUsd": 0.0,
            "tokens": [],
            "nfts": []
        }


@mcp.tool()
async def get_token_balances(
    address: str,
    helius_api_key: str,
    user_id: str
) -> List[Dict[str, Any]]:
    """
    Get token balances using Helius DAS API.
    
    Args:
        address: Wallet address
        helius_api_key: Helius API key
        user_id: User ID for audit logging
    
    Returns:
        List of token balances
    """
    # TODO: Implement Helius DAS API integration
    # TODO: Filter for fungible tokens only
    # TODO: Log access attempt
    
    portfolio = await get_wallet_portfolio(address, helius_api_key, user_id)
    return portfolio["tokens"]


@mcp.tool()
async def get_transaction_history(
    address: str,
    helius_api_key: str,
    user_id: str,
    limit: int = 50
) -> List[Dict[str, Any]]:
    """
    Get transaction history using Helius Enhanced Transactions API.
    
    Args:
        address: Wallet address
        helius_api_key: Helius API key
        user_id: User ID for audit logging
        limit: Maximum number of transactions to return
    
    Returns:
        List of transactions with details
    """
    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            # Use Helius Enhanced Transactions API
            response = await client.get(
                f"https://api.helius.xyz/v0/addresses/{address}/transactions",
                params={
                    "api-key": helius_api_key,
                    "limit": limit
                }
            )
            response.raise_for_status()
            transactions = response.json()
        
        # Parse transactions
        parsed_transactions = []
        for tx in transactions:
            parsed_transactions.append({
                "signature": tx.get("signature", ""),
                "timestamp": datetime.fromtimestamp(tx.get("timestamp", 0)).isoformat(),
                "type": tx.get("type", "UNKNOWN"),
                "source": tx.get("source", "UNKNOWN"),
                "fee": tx.get("fee", 0),
                "nativeTransfers": tx.get("nativeTransfers", []),
                "tokenTransfers": tx.get("tokenTransfers", []),
                "description": tx.get("description", "")
            })
        
        return parsed_transactions
    
    except httpx.HTTPStatusError as e:
        return [{
            "error": f"Helius API error: {e.response.status_code}",
            "signature": "",
            "timestamp": datetime.now().isoformat()
        }]
    except Exception as e:
        return [{
            "error": f"Failed to fetch transactions: {str(e)}",
            "signature": "",
            "timestamp": datetime.now().isoformat()
        }]


@mcp.tool()
async def get_priority_fee_estimate(
    helius_api_key: str,
    user_id: str,
    account_keys: Optional[List[str]] = None
) -> Dict[str, int]:
    """
    Get priority fee estimates using Helius Priority Fee API.
    
    Args:
        helius_api_key: Helius API key
        user_id: User ID for audit logging
        account_keys: Optional list of account keys for specific estimate
    
    Returns:
        Priority fee estimates at different levels
    """
    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            # Use Helius Priority Fee API
            params = {
                "accountKeys": account_keys or [],
                "options": {
                    "includeAllPriorityFeeLevels": True
                }
            }
            
            response = await client.post(
                f"https://mainnet.helius-rpc.com/?api-key={helius_api_key}",
                json={
                    "jsonrpc": "2.0",
                    "id": "ordo-priority-fee",
                    "method": "getPriorityFeeEstimate",
                    "params": [params]
                },
                headers={"Content-Type": "application/json"}
            )
            response.raise_for_status()
            data = response.json()
        
        result = data.get("result", {})
        fee_levels = result.get("priorityFeeLevels", {})
        
        return {
            "min": fee_levels.get("min", 0),
            "low": fee_levels.get("low", 0),
            "medium": fee_levels.get("medium", 0),
            "high": fee_levels.get("high", 0),
            "veryHigh": fee_levels.get("veryHigh", 0),
            "unsafeMax": fee_levels.get("unsafeMax", 0)
        }
    
    except Exception as e:
        # Return default fees on error
        return {
            "min": 0,
            "low": 1000,
            "medium": 5000,
            "high": 10000,
            "veryHigh": 50000,
            "unsafeMax": 100000,
            "error": f"Failed to fetch priority fees: {str(e)}"
        }


@mcp.tool()
async def build_transfer_transaction(
    from_address: str,
    to_address: str,
    amount: int,
    user_id: str,
    token_mint: Optional[str] = None
) -> Dict[str, Any]:
    """
    Build transfer transaction (SOL or SPL token).
    
    Args:
        from_address: Sender address
        to_address: Recipient address
        amount: Amount in lamports (SOL) or token base units
        user_id: User ID for audit logging
        token_mint: Optional token mint address (None for SOL)
    
    Returns:
        Serialized transaction for frontend to sign via MWA
    """
    # TODO: Implement transaction building
    # TODO: Use solders for transaction construction
    # TODO: Handle SOL and SPL token transfers
    # TODO: Add priority fee
    # TODO: Log transaction build
    
    return {
        "transaction": "base64_encoded_transaction",
        "from": from_address,
        "to": to_address,
        "amount": amount,
        "tokenMint": token_mint,
        "type": "SOL_TRANSFER" if token_mint is None else "TOKEN_TRANSFER"
    }


@mcp.resource("wallet://portfolio")
async def get_portfolio_resource(
    address: str,
    helius_api_key: str,
    user_id: str
) -> str:
    """
    Get wallet portfolio as a resource.
    
    Args:
        address: Wallet address
        helius_api_key: Helius API key
        user_id: User ID for audit logging
    
    Returns:
        Formatted portfolio summary
    """
    portfolio = await get_wallet_portfolio(address, helius_api_key, user_id)
    
    formatted = f"Wallet Portfolio ({address[:8]}...):\n\n"
    formatted += f"Total Value: ${portfolio['totalValueUsd']:.2f}\n\n"
    formatted += "Tokens:\n"
    for token in portfolio["tokens"]:
        formatted += f"- {token['symbol']}: {token['balance']} (${token['valueUsd']:.2f})\n"
    
    if portfolio["nfts"]:
        formatted += "\nNFTs:\n"
        for nft in portfolio["nfts"]:
            formatted += f"- {nft['name']}\n"
    
    return formatted


@mcp.resource("wallet://transactions")
async def get_transactions_resource(
    address: str,
    helius_api_key: str,
    user_id: str
) -> str:
    """
    Get transaction history as a resource.
    
    Args:
        address: Wallet address
        helius_api_key: Helius API key
        user_id: User ID for audit logging
    
    Returns:
        Formatted transaction history
    """
    transactions = await get_transaction_history(address, helius_api_key, user_id, limit=20)
    
    formatted = f"Recent Transactions ({address[:8]}...):\n\n"
    for tx in transactions:
        formatted += f"- {tx['type']}: {tx['description']} ({tx['timestamp']})\n"
    
    return formatted


# Run MCP server
if __name__ == "__main__":
    mcp.run(transport="stdio")
