"""
Configuration Management

Loads and validates environment variables using Pydantic settings.
"""

from pydantic_settings import BaseSettings
from pydantic import Field, validator
from typing import List
import os


class Settings(BaseSettings):
    """
    Application settings loaded from environment variables.
    """
    
    # Environment
    ENVIRONMENT: str = Field(default="development", description="Environment name")
    DEBUG: bool = Field(default=False, description="Debug mode")
    API_HOST: str = Field(default="0.0.0.0", description="API host")
    API_PORT: int = Field(default=8000, description="API port")
    
    # Security
    API_SECRET_KEY: str = Field(default="dev-secret-key-change-in-production", description="Secret key for JWT signing")
    API_KEY_FRONTEND: str = Field(default="dev-frontend-key", description="API key for frontend authentication")
    
    # Database
    DATABASE_URL: str = Field(default="postgresql+asyncpg://ordo:ordo_password@localhost:5432/ordo_db", description="PostgreSQL connection URL")
    DATABASE_POOL_SIZE: int = Field(default=20, description="Database connection pool size")
    DATABASE_MAX_OVERFLOW: int = Field(default=10, description="Max overflow connections")
    
    # Redis
    REDIS_URL: str = Field(default="redis://localhost:6379/0", description="Redis connection URL")
    REDIS_PASSWORD: str = Field(default="", description="Redis password")
    
    # Mistral AI
    MISTRAL_API_KEY: str = Field(default="", description="Mistral AI API key")
    MISTRAL_MODEL: str = Field(default="mistral-large-latest", description="Mistral LLM model")
    MISTRAL_EMBED_MODEL: str = Field(default="mistral-embed", description="Mistral embedding model")
    
    # OpenRouter (Fallback)
    OPENROUTER_API_KEY: str = Field(default="", description="OpenRouter API key for fallback")
    OPENROUTER_MODEL: str = Field(default="deepseek/deepseek-r1-0528:free", description="OpenRouter model")
    OPENROUTER_SITE_URL: str = Field(default="https://ordo.app", description="Site URL for OpenRouter")
    OPENROUTER_APP_NAME: str = Field(default="Ordo", description="App name for OpenRouter")
    
    # LangSmith (Tracing)
    LANGSMITH_API_KEY: str = Field(default="", description="LangSmith API key for tracing")
    LANGSMITH_TRACING: bool = Field(default=False, description="Enable LangSmith tracing")
    LANGSMITH_PROJECT: str = Field(default="ordo", description="LangSmith project name")
    
    # Supabase (for RAG)
    SUPABASE_URL: str = Field(default="", description="Supabase project URL")
    SUPABASE_KEY: str = Field(default="", description="Supabase anon key")
    
    # Helius RPC
    HELIUS_API_KEY: str = Field(default="", description="Helius API key")
    HELIUS_RPC_URL: str = Field(
        default="https://mainnet.helius-rpc.com",
        description="Helius RPC endpoint"
    )
    
    # Search API
    BRAVE_SEARCH_API_KEY: str = Field(default="", description="Brave Search API key")
    
    # Rate Limiting
    RATE_LIMIT_PER_MINUTE: int = Field(default=60, description="Rate limit per minute")
    RATE_LIMIT_BURST: int = Field(default=10, description="Rate limit burst")
    
    # CORS
    CORS_ORIGINS: str = Field(
        default="http://localhost:8081",
        description="Allowed CORS origins (comma-separated)"
    )
    CORS_ALLOW_CREDENTIALS: bool = Field(default=True, description="Allow credentials")
    
    @property
    def cors_origins_list(self) -> List[str]:
        """Get CORS origins as a list."""
        if isinstance(self.CORS_ORIGINS, str):
            return [origin.strip() for origin in self.CORS_ORIGINS.split(",") if origin.strip()]
        return self.CORS_ORIGINS
    
    # Logging
    LOG_LEVEL: str = Field(default="INFO", description="Logging level")
    LOG_FORMAT: str = Field(default="json", description="Log format (json or text)")
    
    # MCP Servers
    MCP_EMAIL_URL: str = Field(default="http://localhost:8001/mcp", description="Email MCP server URL")
    MCP_SOCIAL_URL: str = Field(default="http://localhost:8002/mcp", description="Social MCP server URL")
    MCP_WALLET_URL: str = Field(default="http://localhost:8003/mcp", description="Wallet MCP server URL")
    MCP_DEFI_URL: str = Field(default="http://localhost:8004/mcp", description="DeFi MCP server URL")
    MCP_NFT_URL: str = Field(default="http://localhost:8005/mcp", description="NFT MCP server URL")
    MCP_TRADING_URL: str = Field(default="http://localhost:8006/mcp", description="Trading MCP server URL")
    
    # Audit Log
    AUDIT_LOG_RETENTION_DAYS: int = Field(default=90, description="Audit log retention in days")
    
    @validator("CORS_ORIGINS", pre=True, always=True)
    def parse_cors_origins(cls, v):
        """Parse CORS origins from comma-separated string."""
        if v is None or v == "":
            return "http://localhost:8081"
        return v
    
    @validator("LOG_LEVEL")
    def validate_log_level(cls, v):
        """Validate log level."""
        valid_levels = ["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"]
        if v.upper() not in valid_levels:
            raise ValueError(f"LOG_LEVEL must be one of {valid_levels}")
        return v.upper()
    
    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        case_sensitive = True


# Global settings instance
settings = Settings()
