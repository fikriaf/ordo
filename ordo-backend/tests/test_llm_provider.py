"""
Tests for LLM Provider Service

Tests Mistral AI integration, OpenRouter fallback, and LangSmith tracing.
"""

import pytest
from unittest.mock import AsyncMock, MagicMock, patch
from langchain_core.messages import HumanMessage, SystemMessage, AIMessage

from ordo_backend.services.llm_provider import (
    LLMProvider,
    OpenRouterChatModel,
    get_llm_provider
)


class TestOpenRouterChatModel:
    """Test OpenRouter chat model implementation."""
    
    @pytest.mark.asyncio
    async def test_openrouter_initialization(self):
        """Test OpenRouter model initialization."""
        model = OpenRouterChatModel(
            model="deepseek/deepseek-r1-0528:free",
            api_key="test-key",
            site_url="https://test.com",
            app_name="TestApp",
            temperature=0.5,
            max_tokens=1000
        )
        
        assert model.model == "deepseek/deepseek-r1-0528:free"
        assert model.api_key == "test-key"
        assert model.site_url == "https://test.com"
        assert model.app_name == "TestApp"
        assert model.temperature == 0.5
        assert model.max_tokens == 1000
        assert model._llm_type == "openrouter"
    
    @pytest.mark.asyncio
    async def test_openrouter_generate_not_implemented(self):
        """Test that synchronous generation raises NotImplementedError."""
        model = OpenRouterChatModel(api_key="test-key")
        
        with pytest.raises(NotImplementedError):
            model._generate([HumanMessage(content="test")])
    
    @pytest.mark.asyncio
    async def test_openrouter_agenerate_success(self):
        """Test successful async generation with OpenRouter."""
        model = OpenRouterChatModel(
            model="deepseek/deepseek-r1-0528:free",
            api_key="test-key",
            site_url="https://test.com",
            app_name="TestApp"
        )
        
        # Mock httpx response
        mock_response = MagicMock()
        mock_response.json.return_value = {
            "choices": [{
                "message": {
                    "content": "This is a test response from OpenRouter"
                }
            }]
        }
        mock_response.raise_for_status = MagicMock()
        
        with patch("httpx.AsyncClient") as mock_client:
            mock_client.return_value.__aenter__.return_value.post = AsyncMock(
                return_value=mock_response
            )
            
            messages = [
                SystemMessage(content="You are a helpful assistant"),
                HumanMessage(content="Hello!")
            ]
            
            result = await model._agenerate(messages)
            
            assert len(result.generations) == 1
            assert result.generations[0].message.content == "This is a test response from OpenRouter"
            
            # Verify API call
            mock_client.return_value.__aenter__.return_value.post.assert_called_once()
            call_args = mock_client.return_value.__aenter__.return_value.post.call_args
            
            assert call_args[0][0] == "https://openrouter.ai/api/v1/chat/completions"
            assert call_args[1]["headers"]["Authorization"] == "Bearer test-key"
            assert call_args[1]["headers"]["HTTP-Referer"] == "https://test.com"
            assert call_args[1]["headers"]["X-Title"] == "TestApp"
            assert call_args[1]["json"]["model"] == "deepseek/deepseek-r1-0528:free"
    
    @pytest.mark.asyncio
    async def test_openrouter_message_conversion(self):
        """Test conversion of LangChain messages to OpenRouter format."""
        model = OpenRouterChatModel(api_key="test-key")
        
        mock_response = MagicMock()
        mock_response.json.return_value = {
            "choices": [{"message": {"content": "response"}}]
        }
        mock_response.raise_for_status = MagicMock()
        
        with patch("httpx.AsyncClient") as mock_client:
            mock_client.return_value.__aenter__.return_value.post = AsyncMock(
                return_value=mock_response
            )
            
            messages = [
                SystemMessage(content="System prompt"),
                HumanMessage(content="User message"),
                AIMessage(content="AI response")
            ]
            
            await model._agenerate(messages)
            
            call_args = mock_client.return_value.__aenter__.return_value.post.call_args
            openrouter_messages = call_args[1]["json"]["messages"]
            
            assert len(openrouter_messages) == 3
            assert openrouter_messages[0]["role"] == "system"
            assert openrouter_messages[0]["content"] == "System prompt"
            assert openrouter_messages[1]["role"] == "user"
            assert openrouter_messages[1]["content"] == "User message"
            assert openrouter_messages[2]["role"] == "assistant"
            assert openrouter_messages[2]["content"] == "AI response"


class TestLLMProvider:
    """Test LLM provider with Mistral AI and OpenRouter fallback."""
    
    @pytest.mark.asyncio
    async def test_provider_initialization_with_mistral(self):
        """Test provider initialization with Mistral AI."""
        with patch("ordo_backend.services.llm_provider.settings") as mock_settings:
            mock_settings.MISTRAL_API_KEY = "test-mistral-key"
            mock_settings.MISTRAL_MODEL = "mistral-large-latest"
            mock_settings.OPENROUTER_API_KEY = ""
            mock_settings.LANGSMITH_API_KEY = ""
            mock_settings.LANGSMITH_TRACING = False
            mock_settings.LANGSMITH_PROJECT = "test"
            
            with patch("ordo_backend.services.llm_provider.ChatMistralAI") as mock_mistral:
                provider = LLMProvider(temperature=0.7, max_tokens=2000)
                
                assert provider.primary_llm is not None
                assert provider.fallback_llm is None
                mock_mistral.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_provider_initialization_with_fallback(self):
        """Test provider initialization with OpenRouter fallback."""
        with patch("ordo_backend.services.llm_provider.settings") as mock_settings:
            mock_settings.MISTRAL_API_KEY = ""
            mock_settings.OPENROUTER_API_KEY = "test-openrouter-key"
            mock_settings.OPENROUTER_MODEL = "deepseek/deepseek-r1-0528:free"
            mock_settings.OPENROUTER_SITE_URL = "https://test.com"
            mock_settings.OPENROUTER_APP_NAME = "TestApp"
            mock_settings.LANGSMITH_API_KEY = ""
            mock_settings.LANGSMITH_TRACING = False
            mock_settings.LANGSMITH_PROJECT = "test"
            
            provider = LLMProvider(temperature=0.7, max_tokens=2000)
            
            assert provider.primary_llm is None
            assert provider.fallback_llm is not None
    
    @pytest.mark.asyncio
    async def test_provider_langsmith_tracing_enabled(self):
        """Test LangSmith tracing initialization."""
        with patch("ordo_backend.services.llm_provider.settings") as mock_settings:
            mock_settings.MISTRAL_API_KEY = "test-key"
            mock_settings.MISTRAL_MODEL = "mistral-large-latest"
            mock_settings.OPENROUTER_API_KEY = ""
            mock_settings.LANGSMITH_API_KEY = "test-langsmith-key"
            mock_settings.LANGSMITH_TRACING = True
            mock_settings.LANGSMITH_PROJECT = "test-project"
            
            with patch("ordo_backend.services.llm_provider.ChatMistralAI"):
                with patch("ordo_backend.services.llm_provider.os.environ", {}) as mock_env:
                    provider = LLMProvider(enable_tracing=True)
                    
                    # LangSmith env vars should be set
                    assert mock_env.get("LANGSMITH_API_KEY") == "test-langsmith-key"
                    assert mock_env.get("LANGSMITH_TRACING") == "true"
                    assert mock_env.get("LANGSMITH_PROJECT") == "test-project"
    
    @pytest.mark.asyncio
    async def test_ainvoke_primary_success(self):
        """Test successful invocation with primary LLM (Mistral)."""
        with patch("ordo_backend.services.llm_provider.settings") as mock_settings:
            mock_settings.MISTRAL_API_KEY = "test-key"
            mock_settings.MISTRAL_MODEL = "mistral-large-latest"
            mock_settings.OPENROUTER_API_KEY = ""
            mock_settings.LANGSMITH_API_KEY = ""
            mock_settings.LANGSMITH_TRACING = False
            mock_settings.LANGSMITH_PROJECT = "test"
            
            with patch("ordo_backend.services.llm_provider.ChatMistralAI") as mock_mistral:
                mock_llm = AsyncMock()
                mock_llm.ainvoke = AsyncMock(
                    return_value=AIMessage(content="Response from Mistral")
                )
                mock_mistral.return_value = mock_llm
                
                provider = LLMProvider()
                messages = [HumanMessage(content="Test query")]
                
                response = await provider.ainvoke(messages)
                
                assert response.content == "Response from Mistral"
                assert provider.primary_count == 1
                assert provider.fallback_count == 0
                mock_llm.ainvoke.assert_called_once_with(messages)
    
    @pytest.mark.asyncio
    async def test_ainvoke_fallback_on_primary_failure(self):
        """Test fallback to OpenRouter when Mistral fails."""
        with patch("ordo_backend.services.llm_provider.settings") as mock_settings:
            mock_settings.MISTRAL_API_KEY = "test-key"
            mock_settings.MISTRAL_MODEL = "mistral-large-latest"
            mock_settings.OPENROUTER_API_KEY = "test-openrouter-key"
            mock_settings.OPENROUTER_MODEL = "deepseek/deepseek-r1-0528:free"
            mock_settings.OPENROUTER_SITE_URL = "https://test.com"
            mock_settings.OPENROUTER_APP_NAME = "TestApp"
            mock_settings.LANGSMITH_API_KEY = ""
            mock_settings.LANGSMITH_TRACING = False
            mock_settings.LANGSMITH_PROJECT = "test"
            
            with patch("ordo_backend.services.llm_provider.ChatMistralAI") as mock_mistral:
                # Primary LLM fails
                mock_llm = AsyncMock()
                mock_llm.ainvoke = AsyncMock(side_effect=Exception("Mistral API error"))
                mock_mistral.return_value = mock_llm
                
                provider = LLMProvider()
                
                # Mock OpenRouter response
                mock_response = MagicMock()
                mock_response.json.return_value = {
                    "choices": [{"message": {"content": "Response from OpenRouter"}}]
                }
                mock_response.raise_for_status = MagicMock()
                
                with patch("httpx.AsyncClient") as mock_client:
                    mock_client.return_value.__aenter__.return_value.post = AsyncMock(
                        return_value=mock_response
                    )
                    
                    messages = [HumanMessage(content="Test query")]
                    response = await provider.ainvoke(messages)
                    
                    assert response.content == "Response from OpenRouter"
                    assert provider.primary_count == 0
                    assert provider.fallback_count == 1
    
    @pytest.mark.asyncio
    async def test_ainvoke_both_fail(self):
        """Test error when both primary and fallback fail."""
        with patch("ordo_backend.services.llm_provider.settings") as mock_settings:
            mock_settings.MISTRAL_API_KEY = "test-key"
            mock_settings.MISTRAL_MODEL = "mistral-large-latest"
            mock_settings.OPENROUTER_API_KEY = "test-openrouter-key"
            mock_settings.OPENROUTER_MODEL = "deepseek/deepseek-r1-0528:free"
            mock_settings.OPENROUTER_SITE_URL = "https://test.com"
            mock_settings.OPENROUTER_APP_NAME = "TestApp"
            mock_settings.LANGSMITH_API_KEY = ""
            mock_settings.LANGSMITH_TRACING = False
            mock_settings.LANGSMITH_PROJECT = "test"
            
            with patch("ordo_backend.services.llm_provider.ChatMistralAI") as mock_mistral:
                # Primary LLM fails
                mock_llm = AsyncMock()
                mock_llm.ainvoke = AsyncMock(side_effect=Exception("Mistral error"))
                mock_mistral.return_value = mock_llm
                
                provider = LLMProvider()
                
                # Fallback also fails
                with patch("httpx.AsyncClient") as mock_client:
                    mock_client.return_value.__aenter__.return_value.post = AsyncMock(
                        side_effect=Exception("OpenRouter error")
                    )
                    
                    messages = [HumanMessage(content="Test query")]
                    
                    with pytest.raises(RuntimeError, match="Both primary and fallback LLMs failed"):
                        await provider.ainvoke(messages)
    
    @pytest.mark.asyncio
    async def test_ainvoke_no_llm_available(self):
        """Test error when no LLM is available."""
        with patch("ordo_backend.services.llm_provider.settings") as mock_settings:
            mock_settings.MISTRAL_API_KEY = ""
            mock_settings.OPENROUTER_API_KEY = ""
            mock_settings.LANGSMITH_API_KEY = ""
            mock_settings.LANGSMITH_TRACING = False
            mock_settings.LANGSMITH_PROJECT = "test"
            
            provider = LLMProvider()
            messages = [HumanMessage(content="Test query")]
            
            with pytest.raises(RuntimeError, match="No LLM available"):
                await provider.ainvoke(messages)
    
    @pytest.mark.asyncio
    async def test_ainvoke_with_functions(self):
        """Test function calling with Mistral AI."""
        with patch("ordo_backend.services.llm_provider.settings") as mock_settings:
            mock_settings.MISTRAL_API_KEY = "test-key"
            mock_settings.MISTRAL_MODEL = "mistral-large-latest"
            mock_settings.OPENROUTER_API_KEY = ""
            mock_settings.LANGSMITH_API_KEY = ""
            mock_settings.LANGSMITH_TRACING = False
            mock_settings.LANGSMITH_PROJECT = "test"
            
            with patch("ordo_backend.services.llm_provider.ChatMistralAI") as mock_mistral:
                mock_llm = AsyncMock()
                mock_llm.ainvoke = AsyncMock(
                    return_value=AIMessage(
                        content="",
                        additional_kwargs={
                            "function_call": {
                                "name": "search_email",
                                "arguments": '{"query": "test"}'
                            }
                        }
                    )
                )
                mock_mistral.return_value = mock_llm
                
                provider = LLMProvider()
                messages = [HumanMessage(content="Search my emails")]
                functions = [{"name": "search_email", "parameters": {}}]
                
                response = await provider.ainvoke_with_functions(messages, functions)
                
                assert "function_call" in response.additional_kwargs
                mock_llm.ainvoke.assert_called_once()
                call_kwargs = mock_llm.ainvoke.call_args[1]
                assert "functions" in call_kwargs
    
    @pytest.mark.asyncio
    async def test_ainvoke_with_functions_fallback(self):
        """Test function calling fallback to regular invocation."""
        with patch("ordo_backend.services.llm_provider.settings") as mock_settings:
            mock_settings.MISTRAL_API_KEY = ""
            mock_settings.OPENROUTER_API_KEY = "test-key"
            mock_settings.OPENROUTER_MODEL = "deepseek/deepseek-r1-0528:free"
            mock_settings.OPENROUTER_SITE_URL = "https://test.com"
            mock_settings.OPENROUTER_APP_NAME = "TestApp"
            mock_settings.LANGSMITH_API_KEY = ""
            mock_settings.LANGSMITH_TRACING = False
            mock_settings.LANGSMITH_PROJECT = "test"
            
            provider = LLMProvider()
            
            # Mock OpenRouter response
            mock_response = MagicMock()
            mock_response.json.return_value = {
                "choices": [{"message": {"content": "Regular response"}}]
            }
            mock_response.raise_for_status = MagicMock()
            
            with patch("httpx.AsyncClient") as mock_client:
                mock_client.return_value.__aenter__.return_value.post = AsyncMock(
                    return_value=mock_response
                )
                
                messages = [HumanMessage(content="Test")]
                functions = [{"name": "test_function"}]
                
                response = await provider.ainvoke_with_functions(messages, functions)
                
                assert response.content == "Regular response"
    
    def test_get_stats(self):
        """Test usage statistics."""
        with patch("ordo_backend.services.llm_provider.settings") as mock_settings:
            mock_settings.MISTRAL_API_KEY = ""
            mock_settings.OPENROUTER_API_KEY = ""
            mock_settings.LANGSMITH_API_KEY = ""
            mock_settings.LANGSMITH_TRACING = False
            mock_settings.LANGSMITH_PROJECT = "test"
            
            provider = LLMProvider()
            provider.primary_count = 5
            provider.fallback_count = 3
            
            stats = provider.get_stats()
            
            assert stats["primary_count"] == 5
            assert stats["fallback_count"] == 3
            assert stats["total_count"] == 8
    
    def test_reset_stats(self):
        """Test statistics reset."""
        with patch("ordo_backend.services.llm_provider.settings") as mock_settings:
            mock_settings.MISTRAL_API_KEY = ""
            mock_settings.OPENROUTER_API_KEY = ""
            mock_settings.LANGSMITH_API_KEY = ""
            mock_settings.LANGSMITH_TRACING = False
            mock_settings.LANGSMITH_PROJECT = "test"
            
            provider = LLMProvider()
            provider.primary_count = 5
            provider.fallback_count = 3
            
            provider.reset_stats()
            
            assert provider.primary_count == 0
            assert provider.fallback_count == 0


class TestGetLLMProvider:
    """Test global LLM provider getter."""
    
    def test_get_llm_provider_singleton(self):
        """Test that get_llm_provider returns singleton instance."""
        with patch("ordo_backend.services.llm_provider.settings") as mock_settings:
            mock_settings.MISTRAL_API_KEY = ""
            mock_settings.OPENROUTER_API_KEY = ""
            mock_settings.LANGSMITH_API_KEY = ""
            mock_settings.LANGSMITH_TRACING = False
            mock_settings.LANGSMITH_PROJECT = "test"
            
            # Reset global instance
            import ordo_backend.services.llm_provider as llm_module
            llm_module._llm_provider = None
            
            provider1 = get_llm_provider()
            provider2 = get_llm_provider()
            
            assert provider1 is provider2
    
    def test_get_llm_provider_with_custom_params(self):
        """Test get_llm_provider with custom parameters."""
        with patch("ordo_backend.services.llm_provider.settings") as mock_settings:
            mock_settings.MISTRAL_API_KEY = ""
            mock_settings.OPENROUTER_API_KEY = ""
            mock_settings.LANGSMITH_API_KEY = ""
            mock_settings.LANGSMITH_TRACING = False
            mock_settings.LANGSMITH_PROJECT = "test"
            
            # Reset global instance
            import ordo_backend.services.llm_provider as llm_module
            llm_module._llm_provider = None
            
            provider = get_llm_provider(
                temperature=0.5,
                max_tokens=1000,
                enable_tracing=True
            )
            
            assert provider.temperature == 0.5
            assert provider.max_tokens == 1000
