"""
MCP Servers Package

Model Context Protocol (MCP) servers for Ordo.
Each server exposes domain-specific tools and resources.

Servers:
- email: Gmail integration (search, read, send)
- social: X/Twitter and Telegram integration
- wallet: Solana wallet operations via Helius
- defi: DeFi operations (Jupiter, Lulo, Sanctum, Drift)
- nft: NFT operations (Metaplex, Tensor)
- trading: Advanced trading features (Plugin God Mode)
"""

__all__ = [
    "email",
    "social",
    "wallet",
    "defi",
    "nft",
    "trading"
]
