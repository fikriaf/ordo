"""
AI Orchestration Service

LangGraph-based agent orchestrator for query processing and tool routing.

This module implements the core LangGraph StateGraph workflow for Ordo's AI orchestration.
It processes user queries through a multi-stage pipeline:
1. parse_query: Analyze user query and extract intent
2. check_permissions: Verify required permissions are available
3. select_tools: Determine which tools to execute
4. execute_tools: Run tools with error handling
5. filter_results: Apply policy engine to scan for sensitive data
6. aggregate_results: Combine multi-surface data with source attribution
7. generate_response: Create natural language response with citations

Validates: Requirements 7.1, 7.2, 7.3
"""

from typing import Dict, Any, List, Optional, TypedDict
from langchain_core.messages import HumanMessage, AIMessage, SystemMessage, BaseMessage
from langgraph.graph import StateGraph, END
from ordo_backend.config import settings
from ordo_backend.services.policy_engine import PolicyEngine
from ordo_backend.services.llm_provider import get_llm_provider, LLMProvider
from ordo_backend.services.system_prompt import ORDO_SYSTEM_PROMPT, get_system_prompt
from ordo_backend.utils.logger import get_logger

logger = get_logger(__name__)


class AgentState(TypedDict):
    """LangGraph agent state with all required fields."""
    query: str
    messages: List[BaseMessage]
    intent: Optional[str]
    required_tools: List[str]
    required_permissions: List[str]
    tool_results: Dict[str, Any]
    filtered_results: Dict[str, Any]
    response: Optional[str]
    sources: List[Dict[str, Any]]
    errors: List[str]
    user_id: str
    permissions: Dict[str, bool]
    tokens: Dict[str, str]


class OrdoAgent:
    """
    LangGraph-based agent orchestrator with MCP integration.
    
    Implements a multi-stage workflow:
    1. parse_query: Analyze user query and extract intent
    2. check_permissions: Verify required permissions are available
    3. select_tools: Determine which tools to execute
    4. execute_tools: Run tools with error handling
    5. filter_results: Apply policy engine to scan for sensitive data
    6. aggregate_results: Combine multi-surface data with source attribution
    7. generate_response: Create natural language response with citations
    """
    
    def __init__(self, policy_engine: Optional[PolicyEngine] = None):
        """
        Initialize the orchestrator.
        
        Args:
            policy_engine: PolicyEngine instance for content filtering
        """
        self.llm_provider: Optional[LLMProvider] = None
        self.policy_engine = policy_engine or PolicyEngine()
        self.graph: Optional[StateGraph] = None
        self.compiled_graph = None
        
        logger.info("OrdoAgent initialized")
    
    async def initialize(self):
        """Initialize LLM provider and build LangGraph workflow."""
        # Initialize LLM provider with Mistral AI and OpenRouter fallback
        self.llm_provider = get_llm_provider(
            temperature=0.7,
            max_tokens=2000,
            enable_tracing=settings.LANGSMITH_TRACING
        )
        logger.info("LLM provider initialized with Mistral AI and OpenRouter fallback")
        
        # Build LangGraph workflow
        self.graph = self._build_graph()
        self.compiled_graph = self.graph.compile()
        logger.info("LangGraph workflow compiled successfully")
    
    def _build_graph(self) -> StateGraph:
        """Build LangGraph workflow with all nodes and edges."""
        workflow = StateGraph(AgentState)
        
        # Add nodes
        workflow.add_node("parse_query", self.parse_query_node)
        workflow.add_node("check_permissions", self.check_permissions_node)
        workflow.add_node("select_tools", self.select_tools_node)
        workflow.add_node("execute_tools", self.execute_tools_node)
        workflow.add_node("filter_results", self.filter_results_node)
        workflow.add_node("aggregate_results", self.aggregate_results_node)
        workflow.add_node("generate_response", self.generate_response_node)
        
        # Set entry point
        workflow.set_entry_point("parse_query")
        
        # Add edges
        workflow.add_edge("parse_query", "check_permissions")
        
        # Conditional edge after permission check
        workflow.add_conditional_edges(
            "check_permissions",
            self.should_continue_after_permissions,
            {
                "continue": "select_tools",
                "error": "generate_response"
            }
        )
        
        workflow.add_edge("select_tools", "execute_tools")
        workflow.add_edge("execute_tools", "filter_results")
        workflow.add_edge("filter_results", "aggregate_results")
        workflow.add_edge("aggregate_results", "generate_response")
        workflow.add_edge("generate_response", END)
        
        logger.info("LangGraph workflow structure built")
        return workflow
    
    async def parse_query_node(self, state: AgentState) -> AgentState:
        """
        Analyze user query and extract intent.
        
        Args:
            state: Current agent state
            
        Returns:
            Updated state with intent and messages
        """
        logger.info(f"Parsing query: {state['query'][:100]}...")
        
        if not self.llm_provider:
            state["intent"] = "unknown"
            state["errors"].append("LLM provider not initialized")
            return state
        
        try:
            # Get available surfaces from permissions
            available_surfaces = [
                surface for surface, granted in state["permissions"].items() 
                if granted
            ]
            
            # Use system prompt with available surfaces context
            system_prompt = get_system_prompt(available_surfaces=available_surfaces)
            
            messages = [
                SystemMessage(content=system_prompt),
                HumanMessage(content=f"""Analyze this query and determine the user's intent.
                
Query: {state['query']}

Identify:
1. What surfaces are needed (gmail, x, telegram, wallet, web)?
2. What is the primary goal (read, search, analyze, execute)?
3. Are there any specific entities mentioned (email addresses, token names, etc.)?

Respond with a brief intent summary.""")
            ]
            
            response = await self.llm_provider.ainvoke(messages)
            state["intent"] = response.content
            state["messages"].append(response)
            
            logger.info(f"Intent extracted: {state['intent'][:100]}...")
        except Exception as e:
            logger.error(f"Error parsing query: {e}")
            state["errors"].append(f"Query parsing failed: {str(e)}")
            state["intent"] = "unknown"
        
        return state
    
    async def check_permissions_node(self, state: AgentState) -> AgentState:
        """
        Verify required permissions are available.
        
        Args:
            state: Current agent state
            
        Returns:
            Updated state with required_permissions and potential errors
        """
        logger.info("Checking permissions")
        
        # Extract required surfaces from intent
        # This is a simple heuristic - in production, use LLM function calling
        intent_lower = (state.get("intent") or "").lower()
        query_lower = state.get("query", "").lower()
        required_surfaces = []
        
        # Check for Gmail/Email
        if ("gmail" in intent_lower or "email" in intent_lower or 
            "gmail" in query_lower or "email" in query_lower):
            required_surfaces.append("READ_GMAIL")
        
        # Check for X/Twitter
        if ("x" in intent_lower or "twitter" in intent_lower or "tweet" in intent_lower or
            "x" in query_lower or "twitter" in query_lower or "tweet" in query_lower):
            required_surfaces.append("READ_SOCIAL_X")
        
        # Check for Telegram
        if "telegram" in intent_lower or "telegram" in query_lower:
            required_surfaces.append("READ_SOCIAL_TELEGRAM")
        
        # Check for Wallet
        if ("wallet" in intent_lower or "portfolio" in intent_lower or "balance" in intent_lower or
            "wallet" in query_lower or "portfolio" in query_lower or "balance" in query_lower or
            "token" in query_lower or "nft" in query_lower):
            required_surfaces.append("READ_WALLET")
        
        # Check for Transaction signing
        if ("send" in intent_lower or "transfer" in intent_lower or "sign" in intent_lower or
            "swap" in intent_lower or "stake" in intent_lower or
            "send" in query_lower or "transfer" in query_lower):
            required_surfaces.append("SIGN_TRANSACTIONS")
        
        state["required_permissions"] = required_surfaces
        
        # Check if permissions are granted
        missing_permissions = []
        for surface in required_surfaces:
            if not state["permissions"].get(surface, False):
                missing_permissions.append(surface)
        
        if missing_permissions:
            error_msg = f"Missing permissions: {', '.join(missing_permissions)}"
            state["errors"].append(error_msg)
            logger.warning(error_msg)
        else:
            logger.info(f"All required permissions available: {required_surfaces}")
        
        return state
    
    def should_continue_after_permissions(self, state: AgentState) -> str:
        """
        Decide whether to continue or return error after permission check.
        
        Args:
            state: Current agent state
            
        Returns:
            "continue" or "error"
        """
        if state["errors"]:
            logger.info("Stopping workflow due to errors")
            return "error"
        logger.info("Continuing workflow")
        return "continue"
    
    async def select_tools_node(self, state: AgentState) -> AgentState:
        """
        Determine which tools to execute based on intent.
        
        Args:
            state: Current agent state
            
        Returns:
            Updated state with required_tools
        """
        logger.info("Selecting tools")
        
        # Simple tool selection based on intent
        # In production, use LLM function calling with tool schemas
        intent_lower = (state.get("intent") or "").lower()
        tools = []
        
        if "gmail" in intent_lower or "email" in intent_lower:
            if "search" in intent_lower:
                tools.append("search_email_threads")
            else:
                tools.append("get_email_content")
        
        if "wallet" in intent_lower or "portfolio" in intent_lower:
            tools.append("get_wallet_portfolio")
        
        if "balance" in intent_lower:
            tools.append("get_token_balances")
        
        if "transaction" in intent_lower and "history" in intent_lower:
            tools.append("get_transaction_history")
        
        state["required_tools"] = tools
        logger.info(f"Selected tools: {tools}")
        
        return state
    
    async def execute_tools_node(self, state: AgentState) -> AgentState:
        """
        Execute selected tools with error handling.
        
        Args:
            state: Current agent state
            
        Returns:
            Updated state with tool_results
        """
        logger.info(f"Executing {len(state['required_tools'])} tools")
        
        results = {}
        
        for tool_name in state["required_tools"]:
            try:
                # Placeholder for actual tool execution
                # In production, this would call MCP tools
                logger.info(f"Executing tool: {tool_name}")
                results[tool_name] = {
                    "success": True,
                    "data": f"Mock data from {tool_name}",
                    "message": "Tool execution not yet implemented"
                }
            except Exception as e:
                logger.error(f"Tool {tool_name} failed: {e}")
                state["errors"].append(f"Tool {tool_name} failed: {str(e)}")
                results[tool_name] = {
                    "success": False,
                    "error": str(e)
                }
        
        state["tool_results"] = results
        return state
    
    async def filter_results_node(self, state: AgentState) -> AgentState:
        """
        Apply policy engine to filter sensitive data from results.
        
        Args:
            state: Current agent state
            
        Returns:
            Updated state with filtered_results
        """
        logger.info("Filtering results with policy engine")
        
        filtered = {}
        
        for tool_name, result in state["tool_results"].items():
            try:
                # Determine surface from tool name
                surface = self._get_surface_from_tool(tool_name)
                
                # Apply policy filtering
                filtered_result = await self.policy_engine.filter_content(
                    result,
                    surface,
                    state["user_id"]
                )
                
                filtered[tool_name] = filtered_result
                logger.info(f"Filtered results for {tool_name}")
            except Exception as e:
                logger.error(f"Error filtering {tool_name}: {e}")
                filtered[tool_name] = result  # Use unfiltered on error
        
        state["filtered_results"] = filtered
        return state
    
    async def aggregate_results_node(self, state: AgentState) -> AgentState:
        """
        Combine multi-surface data with source attribution.
        
        Args:
            state: Current agent state
            
        Returns:
            Updated state with sources
        """
        logger.info("Aggregating results")
        
        sources = []
        
        for tool_name, result in state["filtered_results"].items():
            if result.get("success"):
                surface = self._get_surface_from_tool(tool_name)
                sources.append({
                    "surface": surface,
                    "tool": tool_name,
                    "preview": str(result.get("data", ""))[:100]
                })
        
        state["sources"] = sources
        logger.info(f"Aggregated {len(sources)} sources")
        
        return state
    
    async def generate_response_node(self, state: AgentState) -> AgentState:
        """
        Create natural language response with citations.
        
        Args:
            state: Current agent state
            
        Returns:
            Updated state with response
        """
        logger.info("Generating response")
        
        if state["errors"]:
            # Generate error response
            state["response"] = self._generate_error_response(state["errors"])
            logger.info("Generated error response")
        elif not self.llm_provider:
            state["response"] = "I'm unable to process your query at this time. The AI service is not available."
            logger.warning("Cannot generate response: LLM provider not initialized")
        else:
            try:
                # Get available surfaces from permissions
                available_surfaces = [
                    surface for surface, granted in state["permissions"].items() 
                    if granted
                ]
                
                # Use system prompt with available surfaces context
                system_prompt = get_system_prompt(available_surfaces=available_surfaces)
                
                # Generate success response with citations
                context = self._format_context(state["filtered_results"])
                
                messages = [
                    SystemMessage(content=system_prompt),
                    HumanMessage(content=f"""Context from tools:
{context}

Original query: {state['query']}

Generate a helpful response using the context above. Include inline citations using the format [source_type:tool_name].""")
                ]
                
                response = await self.llm_provider.ainvoke(messages)
                state["response"] = response.content
                logger.info("Generated success response")
            except Exception as e:
                logger.error(f"Error generating response: {e}")
                state["response"] = f"I encountered an error while generating a response: {str(e)}"
        
        return state
    
    def _get_surface_from_tool(self, tool_name: str) -> str:
        """
        Extract surface name from tool name.
        
        Args:
            tool_name: Name of the tool
            
        Returns:
            Surface name (GMAIL, X, TELEGRAM, WALLET, WEB)
        """
        tool_lower = tool_name.lower()
        if "email" in tool_lower or "gmail" in tool_lower:
            return "GMAIL"
        elif "x_" in tool_lower or "twitter" in tool_lower:
            return "X"
        elif "telegram" in tool_lower:
            return "TELEGRAM"
        elif "wallet" in tool_lower or "token" in tool_lower or "transaction" in tool_lower:
            return "WALLET"
        else:
            return "WEB"
    
    def _format_context(self, filtered_results: Dict[str, Any]) -> str:
        """
        Format filtered results as context for LLM.
        
        Args:
            filtered_results: Filtered tool results
            
        Returns:
            Formatted context string
        """
        context_parts = []
        for tool_name, result in filtered_results.items():
            if result.get("success"):
                context_parts.append(f"[{tool_name}]: {result.get('data', 'No data')}")
        
        return "\n\n".join(context_parts) if context_parts else "No data available"
    
    def _generate_error_response(self, errors: List[str]) -> str:
        """
        Generate user-friendly error response.
        
        Args:
            errors: List of error messages
            
        Returns:
            Formatted error response
        """
        if any("Missing permissions" in err for err in errors):
            permission_errors = [err for err in errors if "Missing permissions" in err]
            return f"I need additional permissions to help with that. {permission_errors[0]}"
        
        return f"I encountered some issues: {'; '.join(errors)}"
    
    async def process_query(self, query: str, context: Dict[str, Any]) -> Dict[str, Any]:
        """
        Process user query through agent workflow.
        
        Args:
            query: User query string
            context: User context with permissions, tokens, user_id
            
        Returns:
            Response with text, sources, and errors
        """
        logger.info(f"Processing query for user {context.get('user_id')}")
        
        if not self.compiled_graph:
            await self.initialize()
        
        # Create initial state
        initial_state: AgentState = {
            "query": query,
            "messages": [],
            "intent": None,
            "required_tools": [],
            "required_permissions": [],
            "tool_results": {},
            "filtered_results": {},
            "response": None,
            "sources": [],
            "errors": [],
            "user_id": context.get("user_id", "unknown"),
            "permissions": context.get("permissions", {}),
            "tokens": context.get("tokens", {})
        }
        
        try:
            # Run the graph
            final_state = await self.compiled_graph.ainvoke(initial_state)
            
            logger.info("Query processing completed successfully")
            return {
                "response": final_state["response"],
                "sources": final_state["sources"],
                "errors": final_state["errors"]
            }
        except Exception as e:
            logger.error(f"Error processing query: {e}")
            return {
                "response": f"I encountered an error processing your query: {str(e)}",
                "sources": [],
                "errors": [str(e)]
            }
