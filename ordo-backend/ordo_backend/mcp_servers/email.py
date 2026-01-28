"""
Email MCP Server

FastMCP server for Gmail integration.
Provides tools for searching, reading, and sending emails.

Tools:
- search_email_threads: Search Gmail threads
- get_email_content: Get specific email content
- send_email: Send email (requires confirmation)

Resources:
- email://inbox: User's inbox as a resource

Prompts:
- email_search_prompt: Generate prompt for email search
"""

from fastmcp import FastMCP
from typing import List, Dict, Any, Optional
import os
import base64
from email.mime.text import MIMEText

# Create MCP server
mcp = FastMCP("Ordo Email Server")

# Note: Gmail API requires google-api-python-client
# Install with: pip install google-api-python-client google-auth-httplib2 google-auth-oauthlib


@mcp.tool()
async def search_email_threads(
    query: str,
    token: str,
    user_id: str,
    max_results: int = 10
) -> List[Dict[str, Any]]:
    """
    Search Gmail threads using Gmail API.
    
    Args:
        query: Search query string (Gmail search syntax)
        token: OAuth token for Gmail API
        user_id: User ID for audit logging
        max_results: Maximum number of results to return
    
    Returns:
        List of email threads with subject, sender, date, snippet
    """
    try:
        # Import Gmail API client
        from googleapiclient.discovery import build
        from google.oauth2.credentials import Credentials
        
        # Create credentials from token
        creds = Credentials(token=token)
        
        # Build Gmail service
        service = build('gmail', 'v1', credentials=creds)
        
        # Search for threads
        results = service.users().threads().list(
            userId='me',
            q=query,
            maxResults=max_results
        ).execute()
        
        threads = results.get('threads', [])
        
        # Get thread details
        thread_list = []
        for thread in threads:
            thread_id = thread['id']
            
            # Get thread details
            thread_data = service.users().threads().get(
                userId='me',
                id=thread_id,
                format='metadata',
                metadataHeaders=['Subject', 'From', 'Date']
            ).execute()
            
            messages = thread_data.get('messages', [])
            if not messages:
                continue
            
            # Get first message for thread info
            first_message = messages[0]
            headers = {h['name']: h['value'] for h in first_message.get('payload', {}).get('headers', [])}
            
            thread_list.append({
                "id": thread_id,
                "subject": headers.get('Subject', 'No Subject'),
                "participants": [headers.get('From', 'Unknown')],
                "messageCount": len(messages),
                "lastMessageDate": headers.get('Date', ''),
                "snippet": thread_data.get('snippet', '')
            })
        
        return thread_list
    
    except ImportError:
        return [{
            "error": "Gmail API client not installed. Install with: pip install google-api-python-client",
            "id": "",
            "subject": ""
        }]
    except Exception as e:
        return [{
            "error": f"Failed to search emails: {str(e)}",
            "id": "",
            "subject": ""
        }]


@mcp.tool()
async def get_email_content(
    email_id: str,
    token: str,
    user_id: str
) -> Dict[str, Any]:
    """
    Retrieve specific email content.
    
    Args:
        email_id: Gmail message ID
        token: OAuth token for Gmail API
        user_id: User ID for audit logging
    
    Returns:
        Email with subject, sender, body, date
    """
    try:
        # Import Gmail API client
        from googleapiclient.discovery import build
        from google.oauth2.credentials import Credentials
        
        # Create credentials from token
        creds = Credentials(token=token)
        
        # Build Gmail service
        service = build('gmail', 'v1', credentials=creds)
        
        # Get message
        message = service.users().messages().get(
            userId='me',
            id=email_id,
            format='full'
        ).execute()
        
        # Parse headers
        headers = {h['name']: h['value'] for h in message.get('payload', {}).get('headers', [])}
        
        # Extract body
        body = ""
        payload = message.get('payload', {})
        
        if 'parts' in payload:
            # Multipart message
            for part in payload['parts']:
                if part.get('mimeType') == 'text/plain':
                    body_data = part.get('body', {}).get('data', '')
                    if body_data:
                        body = base64.urlsafe_b64decode(body_data).decode('utf-8')
                        break
        else:
            # Simple message
            body_data = payload.get('body', {}).get('data', '')
            if body_data:
                body = base64.urlsafe_b64decode(body_data).decode('utf-8')
        
        return {
            "id": email_id,
            "threadId": message.get('threadId', ''),
            "from": headers.get('From', ''),
            "to": headers.get('To', '').split(','),
            "subject": headers.get('Subject', 'No Subject'),
            "body": body,
            "date": headers.get('Date', ''),
            "labels": message.get('labelIds', [])
        }
    
    except ImportError:
        return {
            "error": "Gmail API client not installed",
            "id": email_id
        }
    except Exception as e:
        return {
            "error": f"Failed to get email: {str(e)}",
            "id": email_id
        }


@mcp.tool()
async def send_email(
    to: str,
    subject: str,
    body: str,
    token: str,
    user_id: str
) -> Dict[str, Any]:
    """
    Send email via Gmail API (requires user confirmation).
    
    Args:
        to: Recipient email address
        subject: Email subject
        body: Email body
        token: OAuth token for Gmail API
        user_id: User ID for audit logging
    
    Returns:
        Send result with message ID and status
    """
    try:
        # Import Gmail API client
        from googleapiclient.discovery import build
        from google.oauth2.credentials import Credentials
        
        # Create credentials from token
        creds = Credentials(token=token)
        
        # Build Gmail service
        service = build('gmail', 'v1', credentials=creds)
        
        # Create message
        message = MIMEText(body)
        message['to'] = to
        message['subject'] = subject
        
        # Encode message
        raw_message = base64.urlsafe_b64encode(message.as_bytes()).decode('utf-8')
        
        # Send message
        result = service.users().messages().send(
            userId='me',
            body={'raw': raw_message}
        ).execute()
        
        return {
            "success": True,
            "messageId": result.get('id', ''),
            "status": "sent"
        }
    
    except ImportError:
        return {
            "success": False,
            "error": "Gmail API client not installed",
            "status": "failed"
        }
    except Exception as e:
        return {
            "success": False,
            "error": f"Failed to send email: {str(e)}",
            "status": "failed"
        }


@mcp.resource("email://inbox")
async def get_inbox(token: str, user_id: str) -> str:
    """
    Get user's inbox as a resource.
    
    Args:
        token: OAuth token for Gmail API
        user_id: User ID for audit logging
    
    Returns:
        Formatted list of recent emails
    """
    # TODO: Implement inbox retrieval
    # TODO: Format as text
    threads = await search_email_threads("in:inbox", token, user_id, max_results=50)
    
    formatted = "Recent Emails:\n\n"
    for thread in threads:
        formatted += f"- {thread['subject']} from {thread['participants'][0]}\n"
    
    return formatted


@mcp.prompt()
async def email_search_prompt(topic: str) -> List[Dict[str, str]]:
    """
    Generate prompt for email search.
    
    Args:
        topic: Topic to search for
    
    Returns:
        List of messages for the LLM
    """
    return [
        {
            "role": "system",
            "content": "You are helping search emails. Be concise and cite sources."
        },
        {
            "role": "user",
            "content": f"Search my emails for: {topic}"
        }
    ]


# Run MCP server
if __name__ == "__main__":
    mcp.run(transport="stdio")
