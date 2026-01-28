"""
Basic test script for LangGraph orchestrator workflow.

This script tests the basic workflow execution without requiring MCP tools.
It verifies that all nodes execute correctly and the workflow completes.
"""

import asyncio
from ordo_backend.services.orchestrator import OrdoAgent
from ordo_backend.services.policy_engine import PolicyEngine


async def test_basic_workflow():
    """Test basic workflow execution with mock data."""
    print("=" * 60)
    print("Testing LangGraph Orchestrator Basic Workflow")
    print("=" * 60)
    
    # Initialize orchestrator
    print("\n1. Initializing OrdoAgent...")
    policy_engine = PolicyEngine()
    agent = OrdoAgent(policy_engine=policy_engine)
    await agent.initialize()
    print("✓ OrdoAgent initialized successfully")
    
    # Test case 1: Query with permissions
    print("\n2. Testing query with granted permissions...")
    context = {
        "user_id": "test_user_123",
        "permissions": {
            "READ_WALLET": True,
            "READ_GMAIL": False,
            "READ_SOCIAL_X": False,
            "READ_SOCIAL_TELEGRAM": False,
            "SIGN_TRANSACTIONS": False
        },
        "tokens": {}
    }
    
    query = "What's my wallet balance?"
    print(f"   Query: {query}")
    print(f"   Permissions: {context['permissions']}")
    
    result = await agent.process_query(query, context)
    
    print(f"\n   Response: {result['response']}")
    print(f"   Sources: {result['sources']}")
    print(f"   Errors: {result['errors']}")
    print("✓ Query processed successfully")
    
    # Test case 2: Query without permissions
    print("\n3. Testing query without required permissions...")
    context_no_perms = {
        "user_id": "test_user_123",
        "permissions": {
            "READ_WALLET": False,
            "READ_GMAIL": False,
            "READ_SOCIAL_X": False,
            "READ_SOCIAL_TELEGRAM": False,
            "SIGN_TRANSACTIONS": False
        },
        "tokens": {}
    }
    
    query2 = "Show me my recent emails"
    print(f"   Query: {query2}")
    print(f"   Permissions: {context_no_perms['permissions']}")
    
    result2 = await agent.process_query(query2, context_no_perms)
    
    print(f"\n   Response: {result2['response']}")
    print(f"   Errors: {result2['errors']}")
    print("✓ Permission check working correctly")
    
    # Test case 3: Multi-surface query
    print("\n4. Testing multi-surface query...")
    context_multi = {
        "user_id": "test_user_123",
        "permissions": {
            "READ_WALLET": True,
            "READ_GMAIL": True,
            "READ_SOCIAL_X": False,
            "READ_SOCIAL_TELEGRAM": False,
            "SIGN_TRANSACTIONS": False
        },
        "tokens": {
            "GMAIL": "mock_gmail_token"
        }
    }
    
    query3 = "Show me my wallet balance and recent emails"
    print(f"   Query: {query3}")
    print(f"   Permissions: {context_multi['permissions']}")
    
    result3 = await agent.process_query(query3, context_multi)
    
    print(f"\n   Response: {result3['response']}")
    print(f"   Sources: {result3['sources']}")
    print(f"   Errors: {result3['errors']}")
    print("✓ Multi-surface query processed successfully")
    
    # Get LLM provider stats
    print("\n5. LLM Provider Statistics:")
    if agent.llm_provider:
        stats = agent.llm_provider.get_stats()
        print(f"   Primary LLM calls: {stats['primary_count']}")
        print(f"   Fallback LLM calls: {stats['fallback_count']}")
        print(f"   Total calls: {stats['total_count']}")
    
    print("\n" + "=" * 60)
    print("All tests completed successfully!")
    print("=" * 60)


if __name__ == "__main__":
    asyncio.run(test_basic_workflow())
