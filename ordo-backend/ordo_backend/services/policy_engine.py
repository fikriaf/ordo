"""
Policy Engine Service

Content filtering and policy enforcement for sensitive data protection.
Implements comprehensive pattern matching for OTP codes, verification codes,
recovery phrases, passwords, bank statements, and tax documents.
"""

import re
from typing import List, Tuple, Dict, Any, Optional


class PolicyEngine:
    """
    Content filtering and policy enforcement.
    
    Scans content for sensitive data patterns and blocks access
    to emails, messages, and other content containing:
    - OTP codes and verification codes (4-8 digits)
    - Recovery phrases (12/24 word sequences)
    - Password reset emails
    - Bank statements and tax documents
    - SSN and credit card numbers
    """
    
    # Comprehensive sensitive data patterns
    PATTERNS = {
        # OTP Codes - 4-8 digit numeric sequences with context
        'OTP_CODE_STANDALONE': r'\b\d{4,8}\b(?=\s*(?:is|:|$))',
        'OTP_CODE_WITH_CONTEXT': r'(?:code|otp|pin|token)[\s:]*\d{4,8}\b',
        'OTP_CODE_YOUR': r'(?:your|the)\s+(?:code|otp|pin|token)[\s:]*(?:is|:)?\s*\d{4,8}\b',
        'OTP_CODE_SENT': r'(?:sent|texted|emailed)\s+(?:you|your)?\s*(?:a|an|the)?\s*(?:code|otp|pin)[\s:]*\d{4,8}\b',
        
        # Verification Codes - with various contexts
        'VERIFICATION_CODE': r'(?:verification|verify|confirm|authentication|auth)[\s\w]*(?:code|token|pin)[\s:]*\d{4,8}\b',
        'VERIFICATION_LINK': r'(?:verify|confirm|validate)[\s\w]*(?:email|account|identity|phone)',
        'VERIFICATION_INSTRUCTION': r'(?:enter|use|type)\s+(?:this|the|your)?\s*(?:code|token|pin)[\s:]*\d{4,8}\b',
        
        # Recovery Phrases - 12/24 word sequences
        'RECOVERY_PHRASE_NUMBERED': r'(?:\d+[\.\)]\s*\w+\s*){11,}',  # Numbered word lists (12+ words)
        'RECOVERY_PHRASE_SEED': r'(?:seed|recovery|backup|mnemonic)\s+(?:phrase|words|key)',
        'RECOVERY_PHRASE_WORDS': r'\b(?:word\s+\d+|1\.\s*\w+\s+2\.\s*\w+)',
        'RECOVERY_PHRASE_SEQUENCE': r'(?:\w+\s+){11,23}\w+(?=\s*$|\s*\n)',  # 12-24 word sequences
        
        # Password Reset - various patterns
        'PASSWORD_RESET': r'(?:reset|change|recover|forgot)[\s\w]*password',
        'PASSWORD_RESET_LINK': r'(?:password|account)\s+(?:reset|recovery)\s+(?:link|url|request)',
        'PASSWORD_RESET_INSTRUCTION': r'(?:click|tap|follow)[\s\w]*(?:reset|change)[\s\w]*password',
        'PASSWORD_NEW': r'(?:new|temporary|initial)\s+password[\s:]*\w+',
        
        # Bank Statements and Financial Documents
        'BANK_STATEMENT': r'(?:bank|account)\s+statement',
        'ACCOUNT_BALANCE': r'(?:account|current|available)\s+balance[\s:]*\$?\d+',
        'ROUTING_NUMBER': r'routing\s+(?:number|#)[\s:]*\d{9}',
        'ACCOUNT_NUMBER': r'account\s+(?:number|#)[\s:]*\d{4,}',
        'WIRE_TRANSFER': r'(?:wire|ach|direct)\s+(?:transfer|deposit)',
        'STATEMENT_PERIOD': r'statement\s+(?:period|date|for)[\s:]*\d{1,2}[/-]\d{1,2}',
        
        # Tax Documents
        'TAX_DOCUMENT_W2': r'\bW-?2\b',
        'TAX_DOCUMENT_1099': r'\b1099(?:-[A-Z]+)?\b',
        'TAX_RETURN': r'tax\s+return',
        'TAX_FORM': r'(?:tax|irs)\s+form',
        'TAX_YEAR': r'(?:tax|filing)\s+year[\s:]*\d{4}',
        'SSN': r'\b\d{3}-\d{2}-\d{4}\b',
        'EIN': r'(?:ein|employer\s+id)[\s:]*\d{2}-\d{7}',
        
        # Credit Card Information
        'CREDIT_CARD': r'\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b',
        'CVV': r'\b(?:cvv|cvc|security\s+code)[\s:]*\d{3,4}\b',
        'CARD_EXPIRY': r'(?:exp|expiry|expires)[\s:]*\d{1,2}[/-]\d{2,4}',
    }
    
    def __init__(self):
        """Initialize policy engine with compiled patterns."""
        self.patterns = self._compile_patterns()
        self.pattern_categories = self._categorize_patterns()
    
    def _compile_patterns(self) -> Dict[str, re.Pattern]:
        """Compile regex patterns for efficiency."""
        return {
            name: re.compile(pattern, re.IGNORECASE | re.MULTILINE)
            for name, pattern in self.PATTERNS.items()
        }
    
    def _categorize_patterns(self) -> Dict[str, List[str]]:
        """Categorize patterns by type for better reporting."""
        return {
            'OTP': [k for k in self.PATTERNS.keys() if 'OTP' in k],
            'VERIFICATION': [k for k in self.PATTERNS.keys() if 'VERIFICATION' in k],
            'RECOVERY': [k for k in self.PATTERNS.keys() if 'RECOVERY' in k],
            'PASSWORD': [k for k in self.PATTERNS.keys() if 'PASSWORD' in k],
            'BANK': [k for k in self.PATTERNS.keys() if 'BANK' in k or 'ACCOUNT' in k or 'ROUTING' in k or 'WIRE' in k],
            'TAX': [k for k in self.PATTERNS.keys() if 'TAX' in k or 'SSN' in k or 'EIN' in k],
            'CREDIT_CARD': [k for k in self.PATTERNS.keys() if 'CARD' in k or 'CVV' in k],
        }
    
    def is_sensitive(self, text: str) -> Tuple[bool, List[str]]:
        """
        Check if text contains sensitive data.
        
        Args:
            text: Text to scan
            
        Returns:
            Tuple of (is_sensitive, matched_patterns)
        """
        if not text:
            return False, []
        
        matched_patterns = []
        for pattern_name, pattern in self.patterns.items():
            if pattern.search(text):
                matched_patterns.append(pattern_name)
        
        return len(matched_patterns) > 0, matched_patterns
    
    def scan_content(self, content: str, surface: str) -> Dict[str, Any]:
        """
        Scan content for sensitive data.
        
        Args:
            content: Content to scan
            surface: Surface name (GMAIL, X, TELEGRAM, etc.)
            
        Returns:
            Scan result with sensitive flag and patterns
        """
        is_sensitive, patterns = self.is_sensitive(content)
        
        return {
            "is_sensitive": is_sensitive,
            "patterns": patterns,
            "surface": surface
        }
    
    def filter_emails(self, emails: List[Dict[str, Any]]) -> Dict[str, Any]:
        """
        Filter email list, removing sensitive emails.
        
        Args:
            emails: List of email dictionaries with 'subject' and 'body' fields
            
        Returns:
            Dictionary with filtered emails and blocked count
        """
        filtered_emails = []
        blocked_count = 0
        blocked_patterns = []
        
        for email in emails:
            # Scan subject and body
            subject = email.get("subject", "")
            body = email.get("body", "")
            combined_text = f"{subject} {body}"
            
            is_sensitive, patterns = self.is_sensitive(combined_text)
            
            if is_sensitive:
                blocked_count += 1
                blocked_patterns.extend(patterns)
            else:
                filtered_emails.append(email)
        
        return {
            "emails": filtered_emails,
            "blocked_count": blocked_count,
            "blocked_patterns": list(set(blocked_patterns))
        }
    
    def filter_messages(self, messages: List[Dict[str, Any]]) -> Dict[str, Any]:
        """
        Filter message list, removing sensitive messages.
        
        Args:
            messages: List of message dictionaries with 'text' field
            
        Returns:
            Dictionary with filtered messages and blocked count
        """
        filtered_messages = []
        blocked_count = 0
        blocked_patterns = []
        
        for message in messages:
            # Scan message text
            text = message.get("text", "")
            
            is_sensitive, patterns = self.is_sensitive(text)
            
            if is_sensitive:
                blocked_count += 1
                blocked_patterns.extend(patterns)
            else:
                filtered_messages.append(message)
        
        return {
            "messages": filtered_messages,
            "blocked_count": blocked_count,
            "blocked_patterns": list(set(blocked_patterns))
        }
    
    async def filter_content(
        self,
        content: Any,
        surface: str,
        user_id: str
    ) -> Any:
        """
        Apply policy filtering to content based on type.
        
        Args:
            content: Content to filter (dict, list, or string)
            surface: Surface name (GMAIL, X, TELEGRAM, WALLET, etc.)
            user_id: User ID for audit logging
            
        Returns:
            Filtered content with same structure as input
        """
        # Handle different content types
        if isinstance(content, dict):
            # Check if it's a tool result
            if "success" in content and "data" in content:
                data = content["data"]
                
                # Filter based on data type
                if isinstance(data, list):
                    # Check if it's emails or messages
                    if data and isinstance(data[0], dict):
                        if "subject" in data[0] or "body" in data[0]:
                            # Email list
                            result = self.filter_emails(data)
                            content["data"] = result["emails"]
                            content["filtered_count"] = result["blocked_count"]
                            content["blocked_patterns"] = result["blocked_patterns"]
                            
                            # Log policy violations
                            if result["blocked_count"] > 0:
                                await self._log_policy_violation(
                                    user_id,
                                    surface,
                                    result["blocked_patterns"],
                                    f"Blocked {result['blocked_count']} emails"
                                )
                        elif "text" in data[0]:
                            # Message list
                            result = self.filter_messages(data)
                            content["data"] = result["messages"]
                            content["filtered_count"] = result["blocked_count"]
                            content["blocked_patterns"] = result["blocked_patterns"]
                            
                            # Log policy violations
                            if result["blocked_count"] > 0:
                                await self._log_policy_violation(
                                    user_id,
                                    surface,
                                    result["blocked_patterns"],
                                    f"Blocked {result['blocked_count']} messages"
                                )
                elif isinstance(data, str):
                    # Single text content
                    is_sensitive, patterns = self.is_sensitive(data)
                    if is_sensitive:
                        content["success"] = False
                        content["error"] = "Content blocked due to sensitive data"
                        content["blocked_patterns"] = patterns
                        
                        # Log policy violation
                        await self._log_policy_violation(
                            user_id,
                            surface,
                            patterns,
                            "Blocked sensitive content"
                        )
        
        return content
    
    async def _log_policy_violation(
        self,
        user_id: str,
        surface: str,
        patterns: List[str],
        content_preview: str
    ) -> None:
        """
        Log policy violation to audit log.
        
        Args:
            user_id: User ID
            surface: Surface name
            patterns: List of matched patterns
            content_preview: Preview of blocked content
        """
        # TODO: Implement audit logging to database
        # TODO: Create audit log entry with timestamp, user_id, surface, patterns
        # TODO: Store in PostgreSQL audit_log table
        
        from ordo_backend.utils.logger import get_logger
        logger = get_logger(__name__)
        
        logger.warning(
            f"Policy violation - User: {user_id}, Surface: {surface}, "
            f"Patterns: {patterns}, Preview: {content_preview}"
        )
