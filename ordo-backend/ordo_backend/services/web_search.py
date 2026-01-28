"""
Web Search Service

Brave Search API integration for web search with source citation.
Provides fallback when RAG system has no relevant documentation.

Validates: Requirements 15.1, 15.2
"""

from typing import List, Dict, Any, Optional
from datetime import datetime
import httpx
from ordo_backend.config import settings
from ordo_backend.utils.logger import get_logger

logger = get_logger(__name__)


class SearchResult:
    """
    Web search result model.
    
    Attributes:
        title: Result title
        url: Result URL
        snippet: Result snippet/description
        published_date: Optional publication date
        source_domain: Source domain name
    """
    
    def __init__(
        self,
        title: str,
        url: str,
        snippet: str,
        published_date: Optional[datetime] = None,
        source_domain: Optional[str] = None
    ):
        self.title = title
        self.url = url
        self.snippet = snippet
        self.published_date = published_date
        self.source_domain = source_domain or self._extract_domain(url)
    
    def _extract_domain(self, url: str) -> str:
        """Extract domain from URL."""
        try:
            from urllib.parse import urlparse
            parsed = urlparse(url)
            return parsed.netloc
        except Exception:
            return "unknown"
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert search result to dictionary."""
        return {
            "title": self.title,
            "url": self.url,
            "snippet": self.snippet,
            "published_date": self.published_date.isoformat() if self.published_date else None,
            "source_domain": self.source_domain
        }


class WebSearchService:
    """
    Web search service using Brave Search API.
    
    Features:
    - Web search with Brave Search API
    - Content fetching from URLs
    - Source citation for all results
    - Rate limiting and error handling
    """
    
    def __init__(self):
        """Initialize web search service."""
        self.api_key = settings.BRAVE_SEARCH_API_KEY if hasattr(settings, 'BRAVE_SEARCH_API_KEY') else None
        self.base_url = "https://api.search.brave.com/res/v1/web/search"
        logger.info("Web search service initialized")
    
    async def search(
        self,
        query: str,
        num_results: int = 5,
        search_lang: str = "en",
        country: str = "US"
    ) -> List[SearchResult]:
        """
        Perform web search using Brave Search API.
        
        Args:
            query: Search query
            num_results: Number of results to return
            search_lang: Search language code
            country: Country code for localized results
        
        Returns:
            List of search results
        
        Validates: Requirements 15.1
        """
        if not self.api_key:
            logger.warning("Brave Search API key not configured")
            return []
        
        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.get(
                    self.base_url,
                    headers={
                        "Accept": "application/json",
                        "Accept-Encoding": "gzip",
                        "X-Subscription-Token": self.api_key
                    },
                    params={
                        "q": query,
                        "count": num_results,
                        "search_lang": search_lang,
                        "country": country,
                        "safesearch": "moderate",
                        "text_decorations": False,
                        "spellcheck": True
                    }
                )
                response.raise_for_status()
                data = response.json()
            
            # Parse results
            results = []
            web_results = data.get("web", {}).get("results", [])
            
            for item in web_results[:num_results]:
                result = SearchResult(
                    title=item.get("title", ""),
                    url=item.get("url", ""),
                    snippet=item.get("description", ""),
                    published_date=self._parse_date(item.get("age")),
                    source_domain=item.get("profile", {}).get("name")
                )
                results.append(result)
            
            logger.info(f"Web search returned {len(results)} results for: {query[:50]}...")
            return results
        
        except httpx.HTTPStatusError as e:
            logger.error(f"Brave Search API error: {e.response.status_code} - {e.response.text}")
            return []
        except Exception as e:
            logger.error(f"Web search failed: {e}")
            return []
    
    async def fetch_url_content(
        self,
        url: str,
        max_length: int = 10000
    ) -> Optional[str]:
        """
        Fetch and extract text content from URL.
        
        Args:
            url: URL to fetch
            max_length: Maximum content length to return
        
        Returns:
            Extracted text content or None if failed
        
        Validates: Requirements 15.1
        """
        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.get(
                    url,
                    headers={
                        "User-Agent": "Ordo/1.0 (https://ordo.app)"
                    },
                    follow_redirects=True
                )
                response.raise_for_status()
            
            # TODO: Extract text from HTML
            # TODO: Use BeautifulSoup or similar library
            # TODO: Remove scripts, styles, and navigation
            # TODO: Extract main content
            
            content = response.text[:max_length]
            logger.info(f"Fetched content from {url} ({len(content)} chars)")
            return content
        
        except Exception as e:
            logger.error(f"Failed to fetch URL {url}: {e}")
            return None
    
    async def search_with_content(
        self,
        query: str,
        num_results: int = 5,
        fetch_content: bool = False
    ) -> List[Dict[str, Any]]:
        """
        Search and optionally fetch content from results.
        
        Args:
            query: Search query
            num_results: Number of results to return
            fetch_content: Whether to fetch content from URLs
        
        Returns:
            List of results with optional content
        """
        results = await self.search(query, num_results)
        
        if not fetch_content:
            return [r.to_dict() for r in results]
        
        # Fetch content for each result
        enriched_results = []
        for result in results:
            result_dict = result.to_dict()
            content = await self.fetch_url_content(result.url)
            if content:
                result_dict["content"] = content
            enriched_results.append(result_dict)
        
        return enriched_results
    
    def _parse_date(self, age_str: Optional[str]) -> Optional[datetime]:
        """
        Parse age string to datetime.
        
        Args:
            age_str: Age string from Brave API (e.g., "2 days ago")
        
        Returns:
            Parsed datetime or None
        """
        if not age_str:
            return None
        
        # TODO: Implement age string parsing
        # TODO: Handle "X days ago", "X hours ago", etc.
        
        return None


# Global web search service instance
_web_search_service: Optional[WebSearchService] = None


def get_web_search_service() -> WebSearchService:
    """
    Get or create global web search service instance.
    
    Returns:
        WebSearchService instance
    """
    global _web_search_service
    
    if _web_search_service is None:
        _web_search_service = WebSearchService()
        logger.info("Global web search service created")
    
    return _web_search_service


async def web_search(
    query: str,
    num_results: int = 5
) -> List[SearchResult]:
    """
    Convenience function for web search.
    
    Args:
        query: Search query
        num_results: Number of results to return
    
    Returns:
        List of search results
    """
    service = get_web_search_service()
    return await service.search(query, num_results)
