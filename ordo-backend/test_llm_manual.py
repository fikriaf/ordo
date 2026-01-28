"""
Manual test script for LLM provider with current configuration.

Tests:
1. OpenRouter fallback (since Mistral key not set)
2. LangSmith tracing
3. Basic invocation
4. Statistics tracking
"""

import asyncio
import sys
from pathlib import Path

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent))

from langchain_core.messages import HumanMessage, SystemMessage
from ordo_backend.services.llm_provider import get_llm_provider


async def test_llm_provider():
    """Test LLM provider with current configuration."""
    print("=" * 60)
    print("Testing LLM Provider")
    print("=" * 60)
    
    # Get provider instance
    print("\n1. Initializing LLM provider...")
    provider = get_llm_provider(enable_tracing=True)
    
    print(f"   - Primary LLM (Mistral): {'Available' if provider.primary_llm else 'Not configured'}")
    print(f"   - Fallback LLM (OpenRouter): {'Available' if provider.fallback_llm else 'Not configured'}")
    print(f"   - LangSmith tracing: {'Enabled' if provider.enable_tracing else 'Disabled'}")
    
    # Test basic invocation
    print("\n2. Testing basic invocation...")
    messages = [
        SystemMessage(content="You are a helpful AI assistant. Be concise."),
        HumanMessage(content="Say hello and introduce yourself in one sentence.")
    ]
    
    try:
        response = await provider.ainvoke(messages)
        print(f"   ✅ Success!")
        print(f"   Response: {response.content[:100]}...")
    except Exception as e:
        print(f"   ❌ Failed: {e}")
        return False
    
    # Test with a query
    print("\n3. Testing with a real query...")
    messages = [
        SystemMessage(content="You are a Solana blockchain expert. Be concise."),
        HumanMessage(content="What is a Solana transaction? Answer in 2 sentences.")
    ]
    
    try:
        response = await provider.ainvoke(messages)
        print(f"   ✅ Success!")
        print(f"   Response: {response.content}")
    except Exception as e:
        print(f"   ❌ Failed: {e}")
        return False
    
    # Check statistics
    print("\n4. Checking usage statistics...")
    stats = provider.get_stats()
    print(f"   - Primary LLM calls: {stats['primary_count']}")
    print(f"   - Fallback LLM calls: {stats['fallback_count']}")
    print(f"   - Total calls: {stats['total_count']}")
    
    if stats['fallback_count'] > 0:
        print(f"   ℹ️  Using OpenRouter fallback (Mistral key not configured)")
    
    print("\n" + "=" * 60)
    print("✅ All tests passed!")
    print("=" * 60)
    
    return True


if __name__ == "__main__":
    success = asyncio.run(test_llm_provider())
    sys.exit(0 if success else 1)
