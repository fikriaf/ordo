"""
Integration Tests for LLM Fallback Mechanism

Tests the complete fallback flow from Mistral AI to OpenRouter.
"""

import pytest
from unittest.mock import AsyncMock, MagicMock, patch
from langchain_core.messages import HumanMessage, SystemMessage

from ordo_backend.services.llm_provider import LLMProvider


class TestLLMFallbackIntegration:
    """Integration tests for LLM fallback mechanism."""
    
    @pytest.mark.asyncio
    async def test_mistral_success_no_fallback(self):
        """Test that OpenRouter is not called when Mistral succeeds."""
        with patch("ordo_backend.services.llm_provider.settings") as mock_settings:
            mock_settings.MISTRAL_API_KEY = "test-mistral-key"
            mock_settings.MISTRAL_MODEL = "mistral-large-latest"
            mock_settings.OPENROUTER_API_KEY = "test-openrouter-key"
            mock_settings.OPENROUTER_MODEL = "deepseek/deepseek-r1-0528:free"
            mock_settings.OPENROUTER_SITE_URL = "https://test.com"
            mock_settings.OPENROUTER_APP_NAME = "TestApp"
            mock_settings.LANGSMITH_API_KEY = ""
            mock_settings.LANGSMITH_TRACING = False
            mock_settings.LANGSMITH_PROJECT = "test"
            
            with patch("ordo_backend.services.llm_provider.ChatMistralAI") as mock_mistral:
                # Mistral succeeds
                mock_llm = AsyncMock()
                mock_llm.ainvoke = AsyncMock(
                    return_value=MagicMock(content="Mistral response")
                )
                mock_mistral.return_value = mock_llm
                
                provider = LLMProvider()
                
                # Mock OpenRouter (should not be called)
                with patch("httpx.AsyncClient") as mock_client:
                    mock_post = AsyncMock()
                    mock_client.return_value.__aenter__.return_value.post = mock_post
                    
                    messages = [HumanMessage(content="Test query")]
                    response = await provider.ainvoke(messages)
                    
                    # Verify Mistral was called
                    assert response.content == "Mistral response"
                    assert provider.primary_count == 1
                    assert provider.fallback_count == 0
                    
                    # Verify OpenRouter was NOT called
                    mock_post.assert_not_called()
    
    @pytest.mark.asyncio
    async def test_mistral_failure_triggers_fallback(self):
        """Test that Mistral failure triggers OpenRouter fallback."""
        with patch("ordo_backend.services.llm_provider.settings") as mock_settings:
            mock_settings.MISTRAL_API_KEY = "test-mistral-key"
            mock_settings.MISTRAL_MODEL = "mistral-large-latest"
            mock_settings.OPENROUTER_API_KEY = "test-openrouter-key"
            mock_settings.OPENROUTER_MODEL = "deepseek/deepseek-r1-0528:free"
            mock_settings.OPENROUTER_SITE_URL = "https://test.com"
            mock_settings.OPENROUTER_APP_NAME = "TestApp"
            mock_settings.LANGSMITH_API_KEY = ""
            mock_settings.LANGSMITH_TRACING = False
            mock_settings.LANGSMITH_PROJECT = "test"
            
            with patch("ordo_backend.services.llm_provider.ChatMistralAI") as mock_mistral:
                # Mistral fails
                mock_llm = AsyncMock()
                mock_llm.ainvoke = AsyncMock(
                    side_effect=Exception("Mistral API rate limit exceeded")
                )
                mock_mistral.return_value = mock_llm
                
                provider = LLMProvider()
                
                # Mock OpenRouter success
                mock_response = MagicMock()
                mock_response.json.return_value = {
                    "choices": [{"message": {"content": "OpenRouter fallback response"}}]
                }
                mock_response.raise_for_status = MagicMock()
                
                with patch("httpx.AsyncClient") as mock_client:
                    mock_client.return_value.__aenter__.return_value.post = AsyncMock(
                        return_value=mock_response
                    )
                    
                    messages = [HumanMessage(content="Test query")]
                    response = await provider.ainvoke(messages)
                    
                    # Verify fallback was used
                    assert response.content == "OpenRouter fallback response"
                    assert provider.primary_count == 0
                    assert provider.fallback_count == 1
                    
                    # Verify both were attempted
                    mock_llm.ainvoke.assert_called_once()
                    mock_client.return_value.__aenter__.return_value.post.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_multiple_requests_with_mixed_results(self):
        """Test multiple requests with some succeeding on primary and some on fallback."""
        with patch("ordo_backend.services.llm_provider.settings") as mock_settings:
            mock_settings.MISTRAL_API_KEY = "test-mistral-key"
            mock_settings.MISTRAL_MODEL = "mistral-large-latest"
            mock_settings.OPENROUTER_API_KEY = "test-openrouter-key"
            mock_settings.OPENROUTER_MODEL = "deepseek/deepseek-r1-0528:free"
            mock_settings.OPENROUTER_SITE_URL = "https://test.com"
            mock_settings.OPENROUTER_APP_NAME = "TestApp"
            mock_settings.LANGSMITH_API_KEY = ""
            mock_settings.LANGSMITH_TRACING = False
            mock_settings.LANGSMITH_PROJECT = "test"
            
            with patch("ordo_backend.services.llm_provider.ChatMistralAI") as mock_mistral:
                # Mistral succeeds on first call, fails on second
                mock_llm = AsyncMock()
                call_count = [0]
                
                async def mistral_side_effect(*args, **kwargs):
                    call_count[0] += 1
                    if call_count[0] == 1:
                        return MagicMock(content="Mistral response 1")
                    else:
                        raise Exception("Mistral error")
                
                mock_llm.ainvoke = AsyncMock(side_effect=mistral_side_effect)
                mock_mistral.return_value = mock_llm
                
                provider = LLMProvider()
                
                # Mock OpenRouter
                mock_response = MagicMock()
                mock_response.json.return_value = {
                    "choices": [{"message": {"content": "OpenRouter response"}}]
                }
                mock_response.raise_for_status = MagicMock()
                
                with patch("httpx.AsyncClient") as mock_client:
                    mock_client.return_value.__aenter__.return_value.post = AsyncMock(
                        return_value=mock_response
                    )
                    
                    # First request - Mistral succeeds
                    messages1 = [HumanMessage(content="Query 1")]
                    response1 = await provider.ainvoke(messages1)
                    assert response1.content == "Mistral response 1"
                    
                    # Second request - Mistral fails, fallback to OpenRouter
                    messages2 = [HumanMessage(content="Query 2")]
                    response2 = await provider.ainvoke(messages2)
                    assert response2.content == "OpenRouter response"
                    
                    # Verify stats
                    stats = provider.get_stats()
                    assert stats["primary_count"] == 1
                    assert stats["fallback_count"] == 1
                    assert stats["total_count"] == 2
    
    @pytest.mark.asyncio
    async def test_openrouter_headers_configuration(self):
        """Test that OpenRouter is called with correct headers."""
        with patch("ordo_backend.services.llm_provider.settings") as mock_settings:
            mock_settings.MISTRAL_API_KEY = "test-mistral-key"
            mock_settings.MISTRAL_MODEL = "mistral-large-latest"
            mock_settings.OPENROUTER_API_KEY = "test-openrouter-key"
            mock_settings.OPENROUTER_MODEL = "deepseek/deepseek-r1-0528:free"
            mock_settings.OPENROUTER_SITE_URL = "https://ordo.app"
            mock_settings.OPENROUTER_APP_NAME = "Ordo"
            mock_settings.LANGSMITH_API_KEY = ""
            mock_settings.LANGSMITH_TRACING = False
            mock_settings.LANGSMITH_PROJECT = "test"
            
            with patch("ordo_backend.services.llm_provider.ChatMistralAI") as mock_mistral:
                # Mistral fails
                mock_llm = AsyncMock()
                mock_llm.ainvoke = AsyncMock(side_effect=Exception("Mistral error"))
                mock_mistral.return_value = mock_llm
                
                provider = LLMProvider()
                
                # Mock OpenRouter
                mock_response = MagicMock()
                mock_response.json.return_value = {
                    "choices": [{"message": {"content": "Response"}}]
                }
                mock_response.raise_for_status = MagicMock()
                
                with patch("httpx.AsyncClient") as mock_client:
                    mock_post = AsyncMock(return_value=mock_response)
                    mock_client.return_value.__aenter__.return_value.post = mock_post
                    
                    messages = [
                        SystemMessage(content="System prompt"),
                        HumanMessage(content="User query")
                    ]
                    await provider.ainvoke(messages)
                    
                    # Verify OpenRouter was called with correct headers
                    call_args = mock_post.call_args
                    assert call_args[0][0] == "https://openrouter.ai/api/v1/chat/completions"
                    
                    headers = call_args[1]["headers"]
                    assert headers["Authorization"] == "Bearer test-openrouter-key"
                    assert headers["HTTP-Referer"] == "https://ordo.app"
                    assert headers["X-Title"] == "Ordo"
                    assert headers["Content-Type"] == "application/json"
                    
                    # Verify payload
                    payload = call_args[1]["json"]
                    assert payload["model"] == "deepseek/deepseek-r1-0528:free"
                    assert len(payload["messages"]) == 2
                    assert payload["messages"][0]["role"] == "system"
                    assert payload["messages"][1]["role"] == "user"
    
    @pytest.mark.asyncio
    async def test_stats_tracking_across_fallbacks(self):
        """Test that statistics are correctly tracked across multiple fallbacks."""
        with patch("ordo_backend.services.llm_provider.settings") as mock_settings:
            mock_settings.MISTRAL_API_KEY = "test-mistral-key"
            mock_settings.MISTRAL_MODEL = "mistral-large-latest"
            mock_settings.OPENROUTER_API_KEY = "test-openrouter-key"
            mock_settings.OPENROUTER_MODEL = "deepseek/deepseek-r1-0528:free"
            mock_settings.OPENROUTER_SITE_URL = "https://test.com"
            mock_settings.OPENROUTER_APP_NAME = "TestApp"
            mock_settings.LANGSMITH_API_KEY = ""
            mock_settings.LANGSMITH_TRACING = False
            mock_settings.LANGSMITH_PROJECT = "test"
            
            with patch("ordo_backend.services.llm_provider.ChatMistralAI") as mock_mistral:
                # Mistral alternates between success and failure
                mock_llm = AsyncMock()
                call_count = [0]
                
                async def mistral_side_effect(*args, **kwargs):
                    call_count[0] += 1
                    if call_count[0] % 2 == 1:  # Odd calls succeed
                        return MagicMock(content=f"Mistral {call_count[0]}")
                    else:  # Even calls fail
                        raise Exception("Mistral error")
                
                mock_llm.ainvoke = AsyncMock(side_effect=mistral_side_effect)
                mock_mistral.return_value = mock_llm
                
                provider = LLMProvider()
                
                # Mock OpenRouter
                mock_response = MagicMock()
                mock_response.json.return_value = {
                    "choices": [{"message": {"content": "OpenRouter"}}]
                }
                mock_response.raise_for_status = MagicMock()
                
                with patch("httpx.AsyncClient") as mock_client:
                    mock_client.return_value.__aenter__.return_value.post = AsyncMock(
                        return_value=mock_response
                    )
                    
                    # Make 5 requests
                    for i in range(5):
                        messages = [HumanMessage(content=f"Query {i+1}")]
                        await provider.ainvoke(messages)
                    
                    # Verify stats: 3 primary (calls 1,3,5), 2 fallback (calls 2,4)
                    stats = provider.get_stats()
                    assert stats["primary_count"] == 3
                    assert stats["fallback_count"] == 2
                    assert stats["total_count"] == 5
                    
                    # Reset and verify
                    provider.reset_stats()
                    stats = provider.get_stats()
                    assert stats["primary_count"] == 0
                    assert stats["fallback_count"] == 0
                    assert stats["total_count"] == 0
    
    @pytest.mark.asyncio
    async def test_function_calling_not_available_on_fallback(self):
        """Test that function calling falls back to regular invocation when Mistral unavailable."""
        with patch("ordo_backend.services.llm_provider.settings") as mock_settings:
            mock_settings.MISTRAL_API_KEY = ""  # No Mistral
            mock_settings.OPENROUTER_API_KEY = "test-openrouter-key"
            mock_settings.OPENROUTER_MODEL = "deepseek/deepseek-r1-0528:free"
            mock_settings.OPENROUTER_SITE_URL = "https://test.com"
            mock_settings.OPENROUTER_APP_NAME = "TestApp"
            mock_settings.LANGSMITH_API_KEY = ""
            mock_settings.LANGSMITH_TRACING = False
            mock_settings.LANGSMITH_PROJECT = "test"
            
            provider = LLMProvider()
            
            # Mock OpenRouter
            mock_response = MagicMock()
            mock_response.json.return_value = {
                "choices": [{"message": {"content": "Regular response without function calling"}}]
            }
            mock_response.raise_for_status = MagicMock()
            
            with patch("httpx.AsyncClient") as mock_client:
                mock_client.return_value.__aenter__.return_value.post = AsyncMock(
                    return_value=mock_response
                )
                
                messages = [HumanMessage(content="Search emails")]
                functions = [{"name": "search_email", "parameters": {}}]
                
                # Should fall back to regular invocation
                response = await provider.ainvoke_with_functions(messages, functions)
                
                assert response.content == "Regular response without function calling"
                assert provider.fallback_count == 1
