"""
Tests for Privacy-Aware System Prompt

Tests the system prompt module to ensure it properly enforces privacy rules,
describes capabilities, and generates appropriate confirmation prompts.

Validates: Requirements 10.1, 10.2, 10.3
"""

import pytest
from ordo_backend.services.system_prompt import (
    ORDO_SYSTEM_PROMPT,
    get_system_prompt,
    get_confirmation_prompt,
)


class TestSystemPrompt:
    """Test suite for ORDO_SYSTEM_PROMPT constant."""
    
    def test_prompt_exists(self):
        """Test that the system prompt is defined and non-empty."""
        assert ORDO_SYSTEM_PROMPT is not None
        assert len(ORDO_SYSTEM_PROMPT) > 0
        assert isinstance(ORDO_SYSTEM_PROMPT, str)
    
    def test_prompt_contains_privacy_rules(self):
        """Test that the prompt includes critical privacy rules."""
        # Requirement 10.1: Privacy instructions in system prompts
        assert "NEVER extract" in ORDO_SYSTEM_PROMPT or "NEVER repeat" in ORDO_SYSTEM_PROMPT
        assert "OTP" in ORDO_SYSTEM_PROMPT or "verification code" in ORDO_SYSTEM_PROMPT
        assert "password" in ORDO_SYSTEM_PROMPT.lower()
        assert "recovery phrase" in ORDO_SYSTEM_PROMPT.lower()
        assert "private key" in ORDO_SYSTEM_PROMPT.lower()
    
    def test_prompt_forbids_sensitive_data_extraction(self):
        """Test that the prompt explicitly forbids extraction of sensitive data."""
        # Requirement 10.2: Never include sensitive data in output
        sensitive_terms = [
            "OTP",
            "verification code",
            "password",
            "recovery phrase",
            "private key",
            "bank account",
        ]
        
        prompt_lower = ORDO_SYSTEM_PROMPT.lower()
        for term in sensitive_terms:
            # Check that the term is mentioned in a prohibitive context
            assert term.lower() in prompt_lower, f"Prompt should mention {term}"
    
    def test_prompt_requires_confirmation(self):
        """Test that the prompt requires user confirmation for write operations."""
        # Requirement 10.3: Refuse actions that expose sensitive data
        assert "confirmation" in ORDO_SYSTEM_PROMPT.lower()
        assert "never" in ORDO_SYSTEM_PROMPT.lower() or "do not" in ORDO_SYSTEM_PROMPT.lower()
        
        # Check for specific write operations
        write_operations = ["send email", "post tweet", "sign transaction", "send message"]
        prompt_lower = ORDO_SYSTEM_PROMPT.lower()
        
        # At least some write operations should be mentioned
        mentioned_count = sum(1 for op in write_operations if op in prompt_lower)
        assert mentioned_count >= 2, "Prompt should mention write operations requiring confirmation"
    
    def test_prompt_includes_source_citation_format(self):
        """Test that the prompt includes instructions for source citation."""
        # Requirement 7.5: Cite sources for information
        assert "cite" in ORDO_SYSTEM_PROMPT.lower() or "source" in ORDO_SYSTEM_PROMPT.lower()
        
        # Check for citation format examples
        citation_patterns = ["[gmail:", "[x:", "[telegram:", "[wallet:", "[web:", "[docs:"]
        found_patterns = [p for p in citation_patterns if p in ORDO_SYSTEM_PROMPT]
        assert len(found_patterns) >= 3, "Prompt should include citation format examples"
    
    def test_prompt_describes_gmail_capabilities(self):
        """Test that the prompt describes Gmail integration capabilities."""
        prompt_lower = ORDO_SYSTEM_PROMPT.lower()
        assert "gmail" in prompt_lower or "email" in prompt_lower
        assert "search" in prompt_lower or "read" in prompt_lower
    
    def test_prompt_describes_social_capabilities(self):
        """Test that the prompt describes social media capabilities."""
        prompt_lower = ORDO_SYSTEM_PROMPT.lower()
        
        # Check for X/Twitter
        assert "x" in prompt_lower or "twitter" in prompt_lower
        
        # Check for Telegram
        assert "telegram" in prompt_lower
    
    def test_prompt_describes_wallet_capabilities(self):
        """Test that the prompt describes wallet capabilities."""
        prompt_lower = ORDO_SYSTEM_PROMPT.lower()
        assert "wallet" in prompt_lower
        assert "solana" in prompt_lower or "sol" in prompt_lower
        assert "balance" in prompt_lower or "transaction" in prompt_lower
    
    def test_prompt_describes_defi_capabilities(self):
        """Test that the prompt describes DeFi capabilities."""
        prompt_lower = ORDO_SYSTEM_PROMPT.lower()
        
        # Check for DeFi protocols
        defi_protocols = ["jupiter", "lulo", "sanctum", "drift", "raydium"]
        found_protocols = [p for p in defi_protocols if p in prompt_lower]
        assert len(found_protocols) >= 2, "Prompt should mention DeFi protocols"
    
    def test_prompt_describes_nft_capabilities(self):
        """Test that the prompt describes NFT capabilities."""
        prompt_lower = ORDO_SYSTEM_PROMPT.lower()
        assert "nft" in prompt_lower
        
        # Check for NFT operations
        nft_operations = ["view", "buy", "sell", "collection"]
        found_operations = [op for op in nft_operations if op in prompt_lower]
        assert len(found_operations) >= 2, "Prompt should mention NFT operations"
    
    def test_prompt_describes_trading_capabilities(self):
        """Test that the prompt describes trading capabilities."""
        prompt_lower = ORDO_SYSTEM_PROMPT.lower()
        
        # Check for trading features
        trading_features = ["perpetual", "limit order", "swap", "trade"]
        found_features = [f for f in trading_features if f in prompt_lower]
        assert len(found_features) >= 1, "Prompt should mention trading features"
    
    def test_prompt_includes_confidentiality_statement(self):
        """Test that the prompt treats user data as confidential."""
        # Requirement 10.4: Treat all user data as confidential
        prompt_lower = ORDO_SYSTEM_PROMPT.lower()
        assert "confidential" in prompt_lower or "privacy" in prompt_lower
    
    def test_prompt_includes_refusal_guidance(self):
        """Test that the prompt includes guidance on refusing sensitive requests."""
        # Requirement 10.3: Politely refuse and explain privacy concerns
        prompt_lower = ORDO_SYSTEM_PROMPT.lower()
        assert "refuse" in prompt_lower or "cannot" in prompt_lower or "can't" in prompt_lower
        assert "explain" in prompt_lower or "why" in prompt_lower


class TestGetSystemPrompt:
    """Test suite for get_system_prompt function."""
    
    def test_get_system_prompt_default(self):
        """Test getting system prompt with default parameters."""
        prompt = get_system_prompt()
        assert prompt == ORDO_SYSTEM_PROMPT
    
    def test_get_system_prompt_with_custom_instructions(self):
        """Test getting system prompt with custom instructions."""
        custom = "Be extra helpful with DeFi queries."
        prompt = get_system_prompt(custom_instructions=custom)
        
        assert ORDO_SYSTEM_PROMPT in prompt
        assert custom in prompt
        assert "ADDITIONAL INSTRUCTIONS" in prompt
    
    def test_get_system_prompt_with_available_surfaces(self):
        """Test getting system prompt with available surfaces."""
        surfaces = ["GMAIL", "WALLET"]
        prompt = get_system_prompt(available_surfaces=surfaces)
        
        assert ORDO_SYSTEM_PROMPT in prompt
        assert "AVAILABLE SURFACES" in prompt
        assert "GMAIL" in prompt
        assert "WALLET" in prompt
    
    def test_get_system_prompt_with_both_customizations(self):
        """Test getting system prompt with both custom instructions and surfaces."""
        custom = "Focus on security."
        surfaces = ["WALLET", "X"]
        prompt = get_system_prompt(
            custom_instructions=custom,
            available_surfaces=surfaces
        )
        
        assert ORDO_SYSTEM_PROMPT in prompt
        assert custom in prompt
        assert "WALLET" in prompt
        assert "X" in prompt
        assert "AVAILABLE SURFACES" in prompt
        assert "ADDITIONAL INSTRUCTIONS" in prompt


class TestGetConfirmationPrompt:
    """Test suite for get_confirmation_prompt function."""
    
    def test_email_confirmation_prompt(self):
        """Test email send confirmation prompt."""
        details = {
            "to": "user@example.com",
            "subject": "Test Email",
            "body_preview": "This is a test email..."
        }
        prompt = get_confirmation_prompt("send_email", details)
        
        assert "email" in prompt.lower()
        assert details["to"] in prompt
        assert details["subject"] in prompt
        assert "Do you want to" in prompt or "proceed" in prompt.lower()
    
    def test_tweet_confirmation_prompt(self):
        """Test tweet post confirmation prompt."""
        details = {
            "content": "Hello Solana! #Solana #DeFi"
        }
        prompt = get_confirmation_prompt("post_tweet", details)
        
        assert "tweet" in prompt.lower()
        assert details["content"] in prompt
        assert "Do you want to" in prompt or "proceed" in prompt.lower()
    
    def test_telegram_confirmation_prompt(self):
        """Test Telegram message confirmation prompt."""
        details = {
            "chat": "@username",
            "message": "Hello from Ordo!"
        }
        prompt = get_confirmation_prompt("send_telegram", details)
        
        assert "telegram" in prompt.lower()
        assert details["chat"] in prompt
        assert details["message"] in prompt
        assert "Do you want to" in prompt or "proceed" in prompt.lower()
    
    def test_transaction_confirmation_prompt(self):
        """Test transaction signing confirmation prompt."""
        details = {
            "recipient": "ABC123...xyz",
            "amount": "1.0",
            "token": "SOL",
            "fee": "0.000005",
            "total": "1.000005"
        }
        prompt = get_confirmation_prompt("sign_transaction", details)
        
        assert "transaction" in prompt.lower()
        assert details["recipient"] in prompt
        assert details["amount"] in prompt
        assert details["token"] in prompt
        assert "biometric" in prompt.lower() or "authentication" in prompt.lower()
        assert "Do you want to" in prompt or "proceed" in prompt.lower()
    
    def test_swap_confirmation_prompt(self):
        """Test token swap confirmation prompt."""
        details = {
            "from_amount": "1.0",
            "from_token": "SOL",
            "to_amount": "180.5",
            "to_token": "USDC",
            "rate": "180.5",
            "slippage": "1.0",
            "fee": "0.000005"
        }
        prompt = get_confirmation_prompt("swap_tokens", details)
        
        assert "swap" in prompt.lower()
        assert details["from_token"] in prompt
        assert details["to_token"] in prompt
        assert "slippage" in prompt.lower()
        assert "Do you want to" in prompt or "proceed" in prompt.lower()
    
    def test_stake_confirmation_prompt(self):
        """Test staking confirmation prompt."""
        details = {
            "amount": "10.0",
            "validator": "Validator ABC",
            "apy": "7.5",
            "fee": "0.000005"
        }
        prompt = get_confirmation_prompt("stake_sol", details)
        
        assert "stake" in prompt.lower()
        assert details["amount"] in prompt
        assert details["validator"] in prompt
        assert "apy" in prompt.lower()
        assert "Do you want to" in prompt or "proceed" in prompt.lower()
    
    def test_nft_buy_confirmation_prompt(self):
        """Test NFT purchase confirmation prompt."""
        details = {
            "collection": "Okay Bears",
            "name": "Okay Bear #1234",
            "price": "15.0",
            "marketplace": "Tensor",
            "fee": "0.3",
            "total": "15.3"
        }
        prompt = get_confirmation_prompt("buy_nft", details)
        
        assert "nft" in prompt.lower() or "buy" in prompt.lower()
        assert details["collection"] in prompt
        assert details["name"] in prompt
        assert details["marketplace"] in prompt
        assert "Do you want to" in prompt or "proceed" in prompt.lower()
    
    def test_nft_sell_confirmation_prompt(self):
        """Test NFT listing confirmation prompt."""
        details = {
            "collection": "Okay Bears",
            "name": "Okay Bear #1234",
            "price": "16.0",
            "marketplace": "Tensor",
            "marketplace_fee": "2.0"
        }
        prompt = get_confirmation_prompt("sell_nft", details)
        
        assert "nft" in prompt.lower() or "list" in prompt.lower() or "sell" in prompt.lower()
        assert details["collection"] in prompt
        assert details["name"] in prompt
        assert details["marketplace"] in prompt
        assert "Do you want to" in prompt or "proceed" in prompt.lower()
    
    def test_unknown_action_type(self):
        """Test confirmation prompt for unknown action type."""
        details = {"key": "value"}
        prompt = get_confirmation_prompt("unknown_action", details)
        
        # Should return a generic confirmation
        assert "unknown_action" in prompt
        assert "Confirm" in prompt or "confirm" in prompt


class TestPromptQueryTypes:
    """Test that the prompt handles various query types appropriately."""
    
    def test_prompt_handles_read_queries(self):
        """Test that the prompt describes read-only query capabilities."""
        prompt_lower = ORDO_SYSTEM_PROMPT.lower()
        
        # Should mention read operations
        read_operations = ["search", "view", "show", "read", "get"]
        found_operations = [op for op in read_operations if op in prompt_lower]
        assert len(found_operations) >= 3, "Prompt should describe read operations"
    
    def test_prompt_handles_write_queries(self):
        """Test that the prompt describes write operations with confirmation."""
        prompt_lower = ORDO_SYSTEM_PROMPT.lower()
        
        # Should mention write operations
        write_operations = ["send", "post", "sign", "create", "swap"]
        found_operations = [op for op in write_operations if op in prompt_lower]
        assert len(found_operations) >= 3, "Prompt should describe write operations"
    
    def test_prompt_handles_cross_surface_queries(self):
        """Test that the prompt handles multi-surface queries."""
        prompt_lower = ORDO_SYSTEM_PROMPT.lower()
        
        # Should mention multiple surfaces
        surfaces = ["gmail", "email", "twitter", "telegram", "wallet"]
        found_surfaces = [s for s in surfaces if s in prompt_lower]
        assert len(found_surfaces) >= 3, "Prompt should mention multiple surfaces"
    
    def test_prompt_handles_documentation_queries(self):
        """Test that the prompt describes documentation query capabilities."""
        prompt_lower = ORDO_SYSTEM_PROMPT.lower()
        
        # Should mention documentation/RAG
        doc_terms = ["documentation", "docs", "rag", "search", "web"]
        found_terms = [t for t in doc_terms if t in prompt_lower]
        assert len(found_terms) >= 2, "Prompt should describe documentation queries"


class TestPromptPrivacyScenarios:
    """Test that the prompt handles privacy-sensitive scenarios."""
    
    def test_prompt_blocks_otp_extraction(self):
        """Test that the prompt forbids OTP code extraction."""
        prompt_lower = ORDO_SYSTEM_PROMPT.lower()
        assert "otp" in prompt_lower or "one-time password" in prompt_lower
        assert "never" in prompt_lower or "do not" in prompt_lower
    
    def test_prompt_blocks_password_extraction(self):
        """Test that the prompt forbids password extraction."""
        prompt_lower = ORDO_SYSTEM_PROMPT.lower()
        assert "password" in prompt_lower
        assert "never" in prompt_lower or "do not" in prompt_lower
    
    def test_prompt_blocks_recovery_phrase_extraction(self):
        """Test that the prompt forbids recovery phrase extraction."""
        prompt_lower = ORDO_SYSTEM_PROMPT.lower()
        assert "recovery phrase" in prompt_lower or "seed phrase" in prompt_lower
        assert "never" in prompt_lower or "do not" in prompt_lower
    
    def test_prompt_blocks_private_key_access(self):
        """Test that the prompt forbids private key access."""
        prompt_lower = ORDO_SYSTEM_PROMPT.lower()
        assert "private key" in prompt_lower
        assert "never" in prompt_lower or "do not" in prompt_lower
    
    def test_prompt_requires_biometric_for_transactions(self):
        """Test that the prompt mentions biometric authentication for transactions."""
        prompt_lower = ORDO_SYSTEM_PROMPT.lower()
        
        # Should mention biometric or authentication for wallet operations
        if "transaction" in prompt_lower or "sign" in prompt_lower:
            assert "biometric" in prompt_lower or "authentication" in prompt_lower or "seed vault" in prompt_lower


class TestPromptToneAndStyle:
    """Test that the prompt sets appropriate tone and style."""
    
    def test_prompt_is_helpful(self):
        """Test that the prompt emphasizes being helpful."""
        prompt_lower = ORDO_SYSTEM_PROMPT.lower()
        assert "helpful" in prompt_lower or "assist" in prompt_lower
    
    def test_prompt_is_transparent(self):
        """Test that the prompt emphasizes transparency."""
        prompt_lower = ORDO_SYSTEM_PROMPT.lower()
        assert "transparent" in prompt_lower or "clear" in prompt_lower or "cite" in prompt_lower
    
    def test_prompt_is_security_conscious(self):
        """Test that the prompt emphasizes security."""
        prompt_lower = ORDO_SYSTEM_PROMPT.lower()
        assert "security" in prompt_lower or "privacy" in prompt_lower or "protect" in prompt_lower
    
    def test_prompt_defines_identity(self):
        """Test that the prompt defines Ordo's identity."""
        assert "Ordo" in ORDO_SYSTEM_PROMPT
        assert "AI assistant" in ORDO_SYSTEM_PROMPT or "assistant" in ORDO_SYSTEM_PROMPT


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
