"""
Tests for LangGraph orchestrator.

Tests cover:
- Agent state initialization
- Workflow node execution
- Permission checking logic
- Error handling
- Response generation
"""

import pytest
from typing import Dict, Any
from ordo_backend.services.orchestrator import (
    OrdoAgent,
    AgentState,
    ORDO_SYSTEM_PROMPT
)
from ordo_backend.services.policy_engine import PolicyEngine


@pytest.fixture
def policy_engine():
    """Create a PolicyEngine instance for testing."""
    return PolicyEngine()


@pytest.fixture
def agent(policy_engine):
    """Create an OrdoAgent instance for testing."""
    return OrdoAgent(policy_engine=policy_engine)


@pytest.fixture
def base_context():
    """Create a base context for testing."""
    return {
        "user_id": "test_user_123",
        "permissions": {
            "READ_GMAIL": True,
            "READ_WALLET": True,
            "READ_SOCIAL_X": False,
            "READ_SOCIAL_TELEGRAM": False,
            "SIGN_TRANSACTIONS": False
        },
        "tokens": {
            "GMAIL": "mock_gmail_token",
            "WALLET": "mock_wallet_address"
        }
    }


@pytest.fixture
def initial_state(base_context):
    """Create an initial agent state for testing."""
    return AgentState(
        query="What is my wallet balance?",
        messages=[],
        intent=None,
        required_tools=[],
        required_permissions=[],
        tool_results={},
        filtered_results={},
        response=None,
        sources=[],
        errors=[],
        user_id=base_context["user_id"],
        permissions=base_context["permissions"],
        tokens=base_context["tokens"]
    )


class TestAgentState:
    """Test AgentState TypedDict structure."""
    
    def test_agent_state_creation(self, initial_state):
        """Test that AgentState can be created with all required fields."""
        assert initial_state["query"] == "What is my wallet balance?"
        assert initial_state["user_id"] == "test_user_123"
        assert initial_state["permissions"]["READ_GMAIL"] is True
        assert initial_state["errors"] == []
        assert initial_state["sources"] == []
    
    def test_agent_state_has_all_fields(self, initial_state):
        """Test that AgentState has all required fields."""
        required_fields = [
            "query", "messages", "intent", "required_tools",
            "required_permissions", "tool_results", "filtered_results",
            "response", "sources", "errors", "user_id", "permissions", "tokens"
        ]
        for field in required_fields:
            assert field in initial_state


class TestOrdoAgent:
    """Test OrdoAgent initialization and configuration."""
    
    def test_agent_initialization(self, agent):
        """Test that agent initializes with correct defaults."""
        assert agent.llm_provider is None  # Not initialized until initialize() is called
        assert agent.policy_engine is not None
        assert agent.graph is None
        assert agent.compiled_graph is None
    
    @pytest.mark.asyncio
    async def test_agent_initialize_without_api_key(self, agent, monkeypatch):
        """Test agent initialization without Mistral API key."""
        # Remove API keys
        monkeypatch.setattr("ordo_backend.services.orchestrator.settings.MISTRAL_API_KEY", "")
        monkeypatch.setattr("ordo_backend.services.orchestrator.settings.OPENROUTER_API_KEY", "")
        monkeypatch.setattr("ordo_backend.services.orchestrator.settings.LANGSMITH_TRACING", False)
        
        await agent.initialize()
        
        # LLM provider should be initialized but without LLMs
        assert agent.llm_provider is not None
        # Graph should still be built
        assert agent.graph is not None
        assert agent.compiled_graph is not None
    
    def test_system_prompt_exists(self):
        """Test that system prompt is defined."""
        assert ORDO_SYSTEM_PROMPT is not None
        assert "privacy-first" in ORDO_SYSTEM_PROMPT.lower()
        assert "never" in ORDO_SYSTEM_PROMPT.lower()
        assert "otp" in ORDO_SYSTEM_PROMPT.lower()


class TestWorkflowNodes:
    """Test individual workflow nodes."""
    
    @pytest.mark.asyncio
    async def test_parse_query_node_without_llm(self, agent, initial_state):
        """Test parse_query_node when LLM is not available."""
        result = await agent.parse_query_node(initial_state)
        
        assert result["intent"] == "unknown"
        assert len(result["errors"]) > 0
        assert "LLM provider not initialized" in result["errors"][0]
    
    @pytest.mark.asyncio
    async def test_check_permissions_node_with_wallet_query(self, agent, initial_state):
        """Test permission checking for wallet query."""
        initial_state["intent"] = "User wants to check their wallet balance"
        
        result = await agent.check_permissions_node(initial_state)
        
        assert "READ_WALLET" in result["required_permissions"]
        assert len(result["errors"]) == 0  # Permission is granted
    
    @pytest.mark.asyncio
    async def test_check_permissions_node_missing_permission(self, agent, initial_state):
        """Test permission checking when permission is missing."""
        initial_state["intent"] = "User wants to check their X mentions"
        
        result = await agent.check_permissions_node(initial_state)
        
        assert "READ_SOCIAL_X" in result["required_permissions"]
        assert len(result["errors"]) > 0
        assert "Missing permissions" in result["errors"][0]
    
    def test_should_continue_after_permissions_with_errors(self, agent, initial_state):
        """Test conditional edge when there are errors."""
        initial_state["errors"] = ["Missing permissions: READ_SOCIAL_X"]
        
        result = agent.should_continue_after_permissions(initial_state)
        
        assert result == "error"
    
    def test_should_continue_after_permissions_without_errors(self, agent, initial_state):
        """Test conditional edge when there are no errors."""
        result = agent.should_continue_after_permissions(initial_state)
        
        assert result == "continue"
    
    @pytest.mark.asyncio
    async def test_select_tools_node_wallet_query(self, agent, initial_state):
        """Test tool selection for wallet query."""
        initial_state["intent"] = "User wants to check their wallet portfolio"
        
        result = await agent.select_tools_node(initial_state)
        
        assert "get_wallet_portfolio" in result["required_tools"]
    
    @pytest.mark.asyncio
    async def test_select_tools_node_email_query(self, agent, initial_state):
        """Test tool selection for email query."""
        initial_state["intent"] = "User wants to search their gmail for hackathon emails"
        
        result = await agent.select_tools_node(initial_state)
        
        assert "search_email_threads" in result["required_tools"]
    
    @pytest.mark.asyncio
    async def test_execute_tools_node(self, agent, initial_state):
        """Test tool execution."""
        initial_state["required_tools"] = ["get_wallet_portfolio"]
        
        result = await agent.execute_tools_node(initial_state)
        
        assert "get_wallet_portfolio" in result["tool_results"]
        assert result["tool_results"]["get_wallet_portfolio"]["success"] is True
    
    @pytest.mark.asyncio
    async def test_filter_results_node(self, agent, initial_state):
        """Test result filtering."""
        initial_state["tool_results"] = {
            "get_wallet_portfolio": {
                "success": True,
                "data": "Mock portfolio data"
            }
        }
        
        result = await agent.filter_results_node(initial_state)
        
        assert "get_wallet_portfolio" in result["filtered_results"]
    
    @pytest.mark.asyncio
    async def test_aggregate_results_node(self, agent, initial_state):
        """Test result aggregation."""
        initial_state["filtered_results"] = {
            "get_wallet_portfolio": {
                "success": True,
                "data": "Mock portfolio data"
            }
        }
        
        result = await agent.aggregate_results_node(initial_state)
        
        assert len(result["sources"]) > 0
        assert result["sources"][0]["surface"] == "WALLET"
    
    @pytest.mark.asyncio
    async def test_generate_response_node_with_errors(self, agent, initial_state):
        """Test response generation when there are errors."""
        initial_state["errors"] = ["Missing permissions: READ_SOCIAL_X"]
        
        result = await agent.generate_response_node(initial_state)
        
        assert result["response"] is not None
        assert "permission" in result["response"].lower()
    
    @pytest.mark.asyncio
    async def test_generate_response_node_without_llm(self, agent, initial_state):
        """Test response generation without LLM."""
        initial_state["filtered_results"] = {
            "get_wallet_portfolio": {
                "success": True,
                "data": "Mock data"
            }
        }
        
        result = await agent.generate_response_node(initial_state)
        
        assert result["response"] is not None
        assert "unable" in result["response"].lower()


class TestHelperMethods:
    """Test helper methods."""
    
    def test_get_surface_from_tool_gmail(self, agent):
        """Test surface extraction for Gmail tools."""
        assert agent._get_surface_from_tool("search_email_threads") == "GMAIL"
        assert agent._get_surface_from_tool("get_email_content") == "GMAIL"
    
    def test_get_surface_from_tool_wallet(self, agent):
        """Test surface extraction for wallet tools."""
        assert agent._get_surface_from_tool("get_wallet_portfolio") == "WALLET"
        assert agent._get_surface_from_tool("get_token_balances") == "WALLET"
        assert agent._get_surface_from_tool("get_transaction_history") == "WALLET"
    
    def test_get_surface_from_tool_social(self, agent):
        """Test surface extraction for social tools."""
        assert agent._get_surface_from_tool("get_x_dms") == "X"
        assert agent._get_surface_from_tool("get_telegram_messages") == "TELEGRAM"
    
    def test_format_context_with_results(self, agent):
        """Test context formatting with results."""
        filtered_results = {
            "tool1": {"success": True, "data": "Data 1"},
            "tool2": {"success": True, "data": "Data 2"}
        }
        
        context = agent._format_context(filtered_results)
        
        assert "tool1" in context
        assert "tool2" in context
        assert "Data 1" in context
        assert "Data 2" in context
    
    def test_format_context_empty(self, agent):
        """Test context formatting with no results."""
        context = agent._format_context({})
        
        assert "No data available" in context
    
    def test_generate_error_response_permission(self, agent):
        """Test error response for permission errors."""
        errors = ["Missing permissions: READ_GMAIL"]
        
        response = agent._generate_error_response(errors)
        
        assert "permission" in response.lower()
        assert "READ_GMAIL" in response
    
    def test_generate_error_response_general(self, agent):
        """Test error response for general errors."""
        errors = ["Tool execution failed", "Network error"]
        
        response = agent._generate_error_response(errors)
        
        assert "issues" in response.lower()


class TestEndToEndWorkflow:
    """Test end-to-end workflow execution."""
    
    @pytest.mark.asyncio
    async def test_process_query_with_permissions(self, agent, base_context):
        """Test full query processing with valid permissions."""
        query = "What is my wallet balance?"
        
        result = await agent.process_query(query, base_context)
        
        assert "response" in result
        assert "sources" in result
        assert "errors" in result
        assert result["response"] is not None
    
    @pytest.mark.asyncio
    async def test_process_query_missing_permissions(self, agent, base_context):
        """Test query processing with missing permissions."""
        query = "Show me my X mentions"
        
        result = await agent.process_query(query, base_context)
        
        assert "response" in result
        assert len(result["errors"]) > 0 or "permission" in result["response"].lower()
    
    @pytest.mark.asyncio
    async def test_process_query_multiple_surfaces(self, agent, base_context):
        """Test query requiring multiple surfaces."""
        query = "Check my emails and wallet balance"
        
        result = await agent.process_query(query, base_context)
        
        assert "response" in result
        assert result["response"] is not None


class TestEdgeCases:
    """Test edge cases and error conditions."""
    
    @pytest.mark.asyncio
    async def test_empty_query(self, agent, base_context):
        """Test processing empty query."""
        result = await agent.process_query("", base_context)
        
        assert "response" in result
        assert result["response"] is not None
    
    @pytest.mark.asyncio
    async def test_query_with_no_permissions(self, agent):
        """Test query with no permissions granted."""
        context = {
            "user_id": "test_user",
            "permissions": {},
            "tokens": {}
        }
        
        result = await agent.process_query("Check my emails", context)
        
        assert "response" in result
    
    @pytest.mark.asyncio
    async def test_query_with_invalid_context(self, agent):
        """Test query with missing context fields."""
        context = {"user_id": "test_user"}
        
        result = await agent.process_query("Test query", context)
        
        assert "response" in result
        assert result["response"] is not None
