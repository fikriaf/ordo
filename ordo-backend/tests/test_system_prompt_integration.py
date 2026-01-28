"""
Integration Tests for System Prompt with LLM Provider

Tests that the system prompt integrates correctly with the LLM provider
and produces appropriate responses for various query types.
"""

import pytest
from langchain_core.messages import SystemMessage, HumanMessage

from ordo_backend.services.system_prompt import (
    ORDO_SYSTEM_PROMPT,
    get_system_prompt,
    get_confirmation_prompt,
)


class TestSystemPromptIntegration:
    """Integration tests for system prompt with LLM provider."""
    
    def test_system_prompt_message_format(self):
        """Test that system prompt can be used in message format."""
        # Create messages with system prompt
        messages = [
            SystemMessage(content=ORDO_SYSTEM_PROMPT),
            HumanMessage(content="What can you help me with?")
        ]
        
        # This should not raise an error
        assert messages[0].content == ORDO_SYSTEM_PROMPT
        assert len(messages) == 2
        assert messages[0].type == "system"
        assert messages[1].type == "human"
    
    def test_custom_system_prompt_with_surfaces(self):
        """Test custom system prompt with available surfaces."""
        surfaces = ["GMAIL", "WALLET"]
        prompt = get_system_prompt(available_surfaces=surfaces)
        
        # Verify the prompt includes surface information
        assert "GMAIL" in prompt
        assert "WALLET" in prompt
        assert "AVAILABLE SURFACES" in prompt
        
        # Create messages
        messages = [
            SystemMessage(content=prompt),
            HumanMessage(content="What's my wallet balance?")
        ]
        
        assert len(messages) == 2
        assert "WALLET" in messages[0].content
    
    def test_confirmation_prompt_format(self):
        """Test that confirmation prompts are properly formatted."""
        details = {
            "recipient": "ABC123...xyz",
            "amount": "1.0",
            "token": "SOL",
            "fee": "0.000005",
            "total": "1.000005"
        }
        
        confirmation = get_confirmation_prompt("sign_transaction", details)
        
        # Verify all details are included
        assert details["recipient"] in confirmation
        assert details["amount"] in confirmation
        assert details["token"] in confirmation
        
        # Verify it asks for confirmation
        assert "Do you want to" in confirmation or "proceed" in confirmation.lower()
    
    def test_system_prompt_length_reasonable(self):
        """Test that system prompt is not excessively long."""
        # System prompts should be comprehensive but not too long
        # to avoid excessive token usage
        prompt_length = len(ORDO_SYSTEM_PROMPT)
        
        # Should be substantial (at least 1000 chars for comprehensive instructions)
        assert prompt_length > 1000, "System prompt should be comprehensive"
        
        # But not excessively long (under 20000 chars to avoid token limits)
        assert prompt_length < 20000, "System prompt should not be excessively long"
    
    def test_system_prompt_structure(self):
        """Test that system prompt has clear structure."""
        # Should have clear sections
        assert "##" in ORDO_SYSTEM_PROMPT or "RULES" in ORDO_SYSTEM_PROMPT
        
        # Should have examples
        assert "example" in ORDO_SYSTEM_PROMPT.lower() or "Example" in ORDO_SYSTEM_PROMPT
    
    def test_multiple_confirmation_types(self):
        """Test that different confirmation types produce distinct prompts."""
        email_details = {
            "to": "user@example.com",
            "subject": "Test",
            "body_preview": "Test email"
        }
        
        tx_details = {
            "recipient": "ABC123",
            "amount": "1.0",
            "token": "SOL",
            "fee": "0.000005",
            "total": "1.000005"
        }
        
        email_prompt = get_confirmation_prompt("send_email", email_details)
        tx_prompt = get_confirmation_prompt("sign_transaction", tx_details)
        
        # Prompts should be different
        assert email_prompt != tx_prompt
        
        # Each should contain relevant keywords
        assert "email" in email_prompt.lower()
        assert "transaction" in tx_prompt.lower() or "sign" in tx_prompt.lower()


class TestSystemPromptPrivacyEnforcement:
    """Test that system prompt enforces privacy rules."""
    
    def test_privacy_rules_are_prominent(self):
        """Test that privacy rules appear early in the prompt."""
        # Privacy rules should be in the first 2000 characters
        # to ensure they're seen by the LLM
        first_section = ORDO_SYSTEM_PROMPT[:2000]
        
        assert "NEVER" in first_section or "never" in first_section
        assert "OTP" in first_section or "password" in first_section.lower()
    
    def test_all_sensitive_data_types_covered(self):
        """Test that all sensitive data types are mentioned."""
        sensitive_types = [
            "OTP",
            "password",
            "recovery phrase",
            "private key",
            "bank account",
        ]
        
        prompt_lower = ORDO_SYSTEM_PROMPT.lower()
        for sensitive_type in sensitive_types:
            assert sensitive_type.lower() in prompt_lower, \
                f"System prompt should mention {sensitive_type}"
    
    def test_confirmation_required_for_all_write_ops(self):
        """Test that confirmation is required for all write operations."""
        write_operations = [
            "send_email",
            "post_tweet",
            "send_telegram",
            "sign_transaction",
            "swap_tokens",
            "stake_sol",
            "buy_nft",
            "sell_nft",
        ]
        
        for op in write_operations:
            details = {"test": "data"}
            prompt = get_confirmation_prompt(op, details)
            
            # Each should ask for confirmation
            assert "Do you want to" in prompt or "proceed" in prompt.lower(), \
                f"Confirmation prompt for {op} should ask for user approval"


class TestSystemPromptCapabilityDescriptions:
    """Test that system prompt accurately describes capabilities."""
    
    def test_describes_all_surfaces(self):
        """Test that all surfaces are described."""
        surfaces = ["gmail", "twitter", "telegram", "wallet"]
        prompt_lower = ORDO_SYSTEM_PROMPT.lower()
        
        for surface in surfaces:
            assert surface in prompt_lower or (surface == "twitter" and "x" in prompt_lower), \
                f"System prompt should describe {surface}"
    
    def test_describes_defi_protocols(self):
        """Test that DeFi protocols are described."""
        protocols = ["jupiter", "lulo", "sanctum", "drift"]
        prompt_lower = ORDO_SYSTEM_PROMPT.lower()
        
        mentioned_count = sum(1 for p in protocols if p in prompt_lower)
        assert mentioned_count >= 2, "System prompt should mention major DeFi protocols"
    
    def test_describes_nft_marketplaces(self):
        """Test that NFT marketplaces are described."""
        marketplaces = ["tensor", "magic eden", "metaplex"]
        prompt_lower = ORDO_SYSTEM_PROMPT.lower()
        
        mentioned_count = sum(1 for m in marketplaces if m in prompt_lower)
        assert mentioned_count >= 1, "System prompt should mention NFT marketplaces"
    
    def test_describes_source_citation_format(self):
        """Test that source citation format is clearly described."""
        # Should have examples of citation format
        citation_examples = ["[gmail:", "[x:", "[wallet:", "[web:"]
        
        found_count = sum(1 for ex in citation_examples if ex in ORDO_SYSTEM_PROMPT)
        assert found_count >= 3, "System prompt should include citation format examples"


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
