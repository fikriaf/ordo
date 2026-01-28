"""
LLM Provider Service

Provides LLM instances with Mistral AI as primary and OpenRouter as fallback.
Includes LangSmith tracing for observability.
"""

from typing import Optional, Dict, Any, List
from langchain_mistralai import ChatMistralAI
from langchain_core.language_models.chat_models import BaseChatModel
from langchain_core.messages import BaseMessage
from langchain_core.outputs import ChatResult
from langsmith import traceable
import httpx
import os

from ordo_backend.config import settings
from ordo_backend.utils.logger import get_logger

logger = get_logger(__name__)


class OpenRouterChatModel(BaseChatModel):
    """
    Custom LangChain chat model for OpenRouter API.
    
    Implements the BaseChatModel interface to work with LangChain.
    """
    
    model: str = "deepseek/deepseek-r1-0528:free"
    api_key: str
    site_url: str = "https://ordo.app"
    app_name: str = "Ordo"
    temperature: float = 0.7
    max_tokens: int = 2000
    
    def __init__(
        self,
        model: str = "deepseek/deepseek-r1-0528:free",
        api_key: str = "",
        site_url: str = "https://ordo.app",
        app_name: str = "Ordo",
        temperature: float = 0.7,
        max_tokens: int = 2000,
        **kwargs
    ):
        """Initialize OpenRouter chat model."""
        super().__init__(
            model=model,
            api_key=api_key,
            site_url=site_url,
            app_name=app_name,
            temperature=temperature,
            max_tokens=max_tokens,
            **kwargs
        )
    
    @property
    def _llm_type(self) -> str:
        """Return type of LLM."""
        return "openrouter"
    
    def _generate(
        self,
        messages: List[BaseMessage],
        stop: Optional[List[str]] = None,
        **kwargs: Any,
    ) -> ChatResult:
        """Generate response synchronously (not implemented)."""
        raise NotImplementedError("Use ainvoke for async generation")
    
    async def _agenerate(
        self,
        messages: List[BaseMessage],
        stop: Optional[List[str]] = None,
        **kwargs: Any,
    ) -> ChatResult:
        """
        Generate response asynchronously using OpenRouter API.
        
        Args:
            messages: List of messages in the conversation
            stop: Optional stop sequences
            **kwargs: Additional generation parameters
            
        Returns:
            ChatResult with generated response
        """
        # Convert LangChain messages to OpenRouter format
        openrouter_messages = []
        for msg in messages:
            role = "user"
            if msg.type == "system":
                role = "system"
            elif msg.type == "ai":
                role = "assistant"
            
            openrouter_messages.append({
                "role": role,
                "content": msg.content
            })
        
        # Prepare request
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "HTTP-Referer": self.site_url,
            "X-Title": self.app_name,
            "Content-Type": "application/json"
        }
        
        payload = {
            "model": self.model,
            "messages": openrouter_messages,
            "temperature": kwargs.get("temperature", self.temperature),
            "max_tokens": kwargs.get("max_tokens", self.max_tokens)
        }
        
        if stop:
            payload["stop"] = stop
        
        # Make API request
        async with httpx.AsyncClient(timeout=60.0) as client:
            response = await client.post(
                "https://openrouter.ai/api/v1/chat/completions",
                headers=headers,
                json=payload
            )
            response.raise_for_status()
            data = response.json()
        
        # Extract response
        from langchain_core.messages import AIMessage
        from langchain_core.outputs import ChatGeneration
        
        content = data["choices"][0]["message"]["content"]
        message = AIMessage(content=content)
        generation = ChatGeneration(message=message)
        
        return ChatResult(generations=[generation])


class LLMProvider:
    """
    LLM Provider with Mistral AI primary and OpenRouter fallback.
    
    Features:
    - Mistral AI (mistral-large-latest) as primary LLM
    - OpenRouter (deepseek/deepseek-r1-0528:free) as fallback
    - LangSmith tracing for observability
    - Automatic fallback on Mistral failures
    - Function calling support for tool selection
    """
    
    def __init__(
        self,
        temperature: float = 0.7,
        max_tokens: int = 2000,
        enable_tracing: bool = False
    ):
        """
        Initialize LLM provider.
        
        Args:
            temperature: Sampling temperature (0.0 to 1.0)
            max_tokens: Maximum tokens in response
            enable_tracing: Enable LangSmith tracing
        """
        self.temperature = temperature
        self.max_tokens = max_tokens
        self.enable_tracing = enable_tracing
        
        # Initialize LangSmith tracing if enabled
        if enable_tracing and settings.LANGSMITH_API_KEY:
            os.environ["LANGSMITH_API_KEY"] = settings.LANGSMITH_API_KEY
            os.environ["LANGSMITH_TRACING"] = "true"
            os.environ["LANGSMITH_PROJECT"] = settings.LANGSMITH_PROJECT
            logger.info(f"LangSmith tracing enabled for project: {settings.LANGSMITH_PROJECT}")
        
        # Initialize primary LLM (Mistral AI)
        self.primary_llm: Optional[ChatMistralAI] = None
        if settings.MISTRAL_API_KEY:
            try:
                self.primary_llm = ChatMistralAI(
                    model=settings.MISTRAL_MODEL,
                    temperature=temperature,
                    max_tokens=max_tokens,
                    api_key=settings.MISTRAL_API_KEY,
                    safe_mode=True  # Enable safety filtering
                )
                logger.info(f"Mistral AI initialized: {settings.MISTRAL_MODEL}")
            except Exception as e:
                logger.error(f"Failed to initialize Mistral AI: {e}")
        else:
            logger.warning("MISTRAL_API_KEY not set, primary LLM unavailable")
        
        # Initialize fallback LLM (OpenRouter)
        self.fallback_llm: Optional[OpenRouterChatModel] = None
        if settings.OPENROUTER_API_KEY:
            try:
                self.fallback_llm = OpenRouterChatModel(
                    model=settings.OPENROUTER_MODEL,
                    api_key=settings.OPENROUTER_API_KEY,
                    site_url=settings.OPENROUTER_SITE_URL,
                    app_name=settings.OPENROUTER_APP_NAME,
                    temperature=temperature,
                    max_tokens=max_tokens
                )
                logger.info(f"OpenRouter fallback initialized: {settings.OPENROUTER_MODEL}")
            except Exception as e:
                logger.error(f"Failed to initialize OpenRouter: {e}")
        else:
            logger.warning("OPENROUTER_API_KEY not set, fallback LLM unavailable")
        
        self.fallback_count = 0
        self.primary_count = 0
    
    @traceable(name="llm_invoke")
    async def ainvoke(
        self,
        messages: List[BaseMessage],
        **kwargs: Any
    ) -> BaseMessage:
        """
        Invoke LLM with automatic fallback.
        
        Tries Mistral AI first, falls back to OpenRouter on failure.
        Decorated with @traceable for LangSmith observability.
        
        Args:
            messages: List of messages in the conversation
            **kwargs: Additional generation parameters
            
        Returns:
            Generated AI message
            
        Raises:
            RuntimeError: If both primary and fallback LLMs fail
        """
        # Try primary LLM (Mistral AI)
        if self.primary_llm:
            try:
                logger.debug("Invoking primary LLM (Mistral AI)")
                response = await self.primary_llm.ainvoke(messages, **kwargs)
                self.primary_count += 1
                logger.info(f"Primary LLM success (total: {self.primary_count})")
                return response
            except Exception as e:
                logger.warning(f"Primary LLM failed: {e}, falling back to OpenRouter")
        
        # Fallback to OpenRouter
        if self.fallback_llm:
            try:
                logger.debug("Invoking fallback LLM (OpenRouter)")
                result = await self.fallback_llm._agenerate(messages, **kwargs)
                self.fallback_count += 1
                logger.info(f"Fallback LLM success (total: {self.fallback_count})")
                return result.generations[0].message
            except Exception as e:
                logger.error(f"Fallback LLM failed: {e}")
                raise RuntimeError(f"Both primary and fallback LLMs failed: {e}")
        
        raise RuntimeError("No LLM available (both primary and fallback are None)")
    
    @traceable(name="llm_invoke_with_functions")
    async def ainvoke_with_functions(
        self,
        messages: List[BaseMessage],
        functions: List[Dict[str, Any]],
        **kwargs: Any
    ) -> BaseMessage:
        """
        Invoke LLM with function calling support.
        
        Only works with Mistral AI (primary LLM) as it supports function calling.
        Falls back to regular invocation if Mistral is unavailable.
        
        Args:
            messages: List of messages in the conversation
            functions: List of function schemas for tool selection
            **kwargs: Additional generation parameters
            
        Returns:
            Generated AI message with potential function calls
        """
        if self.primary_llm:
            try:
                logger.debug("Invoking primary LLM with function calling")
                response = await self.primary_llm.ainvoke(
                    messages,
                    functions=functions,
                    **kwargs
                )
                self.primary_count += 1
                logger.info(f"Function calling success (total: {self.primary_count})")
                return response
            except Exception as e:
                logger.warning(f"Function calling failed: {e}, falling back to regular invocation")
        
        # Fallback to regular invocation without function calling
        logger.warning("Function calling not available, using regular invocation")
        return await self.ainvoke(messages, **kwargs)
    
    def get_stats(self) -> Dict[str, int]:
        """
        Get usage statistics.
        
        Returns:
            Dictionary with primary and fallback usage counts
        """
        return {
            "primary_count": self.primary_count,
            "fallback_count": self.fallback_count,
            "total_count": self.primary_count + self.fallback_count
        }
    
    def reset_stats(self) -> None:
        """Reset usage statistics."""
        self.primary_count = 0
        self.fallback_count = 0
        logger.info("LLM usage statistics reset")


# Global LLM provider instance
_llm_provider: Optional[LLMProvider] = None


def get_llm_provider(
    temperature: float = 0.7,
    max_tokens: int = 2000,
    enable_tracing: bool = None
) -> LLMProvider:
    """
    Get or create global LLM provider instance.
    
    Args:
        temperature: Sampling temperature
        max_tokens: Maximum tokens in response
        enable_tracing: Enable LangSmith tracing (defaults to settings)
        
    Returns:
        LLMProvider instance
    """
    global _llm_provider
    
    if _llm_provider is None:
        if enable_tracing is None:
            enable_tracing = settings.LANGSMITH_TRACING
        
        _llm_provider = LLMProvider(
            temperature=temperature,
            max_tokens=max_tokens,
            enable_tracing=enable_tracing
        )
        logger.info("Global LLM provider created")
    
    return _llm_provider
