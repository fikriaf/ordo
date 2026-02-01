import { Router, Response } from 'express';
import { z } from 'zod';
import { authenticate } from '../middleware/auth.middleware';
import { AuthenticatedRequest } from '../types';
import aiAgentService from '../services/ai-agent.service';
import conversationService from '../services/conversation.service';
import logger from '../config/logger';

const router = Router();

// All chat routes require authentication
router.use(authenticate);

// Validation schemas
const chatSchema = z.object({
  message: z.string().min(1, 'Message is required'),
  walletId: z.string().optional(),
  conversationId: z.string().optional(),
});

// POST /api/v1/chat - Send message (non-streaming)
router.post('/', async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    if (!req.user) {
      res.status(401).json({
        success: false,
        error: 'Authentication required',
      });
      return;
    }

    const validatedData = chatSchema.parse(req.body);

    // Get or create conversation
    const conversation = await conversationService.getOrCreateConversation(req.user.id);

    // Get conversation history (last 10 messages)
    const history = await conversationService.getConversationHistory(conversation.id, 10);

    // Save user message
    await conversationService.saveMessage(conversation.id, 'user', validatedData.message);

    // Prepare context
    const context = {
      userId: req.user.id,
      walletId: validatedData.walletId,
    };

    // Get AI response
    const result = await aiAgentService.chat(
      validatedData.message,
      context,
      history.map((m) => ({
        role: m.role as 'user' | 'assistant' | 'system',
        content: m.content,
      }))
    );

    // Save assistant response
    await conversationService.saveMessage(
      conversation.id,
      'assistant',
      result.response,
      result.toolCalls ? { toolCalls: result.toolCalls } : undefined
    );

    res.status(200).json({
      success: true,
      data: {
        conversationId: conversation.id,
        message: result.response,
        toolCalls: result.toolCalls,
      },
    });
  } catch (error: any) {
    if (error instanceof z.ZodError) {
      res.status(400).json({
        success: false,
        error: 'Validation error',
        details: error.errors,
      });
      return;
    }

    logger.error('Chat error:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Chat failed',
    });
  }
});

// POST /api/v1/chat/stream - Send message (SSE streaming)
router.post('/stream', async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    if (!req.user) {
      res.status(401).json({
        success: false,
        error: 'Authentication required',
      });
      return;
    }

    const validatedData = chatSchema.parse(req.body);

    // Get or create conversation
    const conversation = await conversationService.getOrCreateConversation(req.user.id);

    // Get conversation history
    const history = await conversationService.getConversationHistory(conversation.id, 10);

    // Save user message
    await conversationService.saveMessage(conversation.id, 'user', validatedData.message);

    // Prepare context
    const context = {
      userId: req.user.id,
      walletId: validatedData.walletId,
    };

    // Set up SSE
    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');

    let fullResponse = '';

    // Stream AI response
    for await (const chunk of aiAgentService.chatStream(
      validatedData.message,
      context,
      history.map((m) => ({
        role: m.role as 'user' | 'assistant' | 'system',
        content: m.content,
      }))
    )) {
      fullResponse += chunk;
      res.write(`data: ${JSON.stringify({ chunk })}\n\n`);
    }

    // Save complete assistant response
    await conversationService.saveMessage(conversation.id, 'assistant', fullResponse);

    // Send completion event
    res.write(`data: ${JSON.stringify({ done: true, conversationId: conversation.id })}\n\n`);
    res.end();
  } catch (error: any) {
    if (error instanceof z.ZodError) {
      res.write(`data: ${JSON.stringify({ error: 'Validation error', details: error.errors })}\n\n`);
      res.end();
      return;
    }

    logger.error('Chat stream error:', error);
    res.write(`data: ${JSON.stringify({ error: error.message || 'Chat stream failed' })}\n\n`);
    res.end();
  }
});

// GET /api/v1/conversations - Get user conversations
router.get('/conversations', async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    if (!req.user) {
      res.status(401).json({
        success: false,
        error: 'Authentication required',
      });
      return;
    }

    const conversations = await conversationService.getUserConversations(req.user.id);

    res.status(200).json({
      success: true,
      data: conversations,
    });
  } catch (error: any) {
    logger.error('Get conversations error:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to get conversations',
    });
  }
});

// GET /api/v1/conversations/:id/messages - Get conversation messages
router.get('/conversations/:id/messages', async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    if (!req.user) {
      res.status(401).json({
        success: false,
        error: 'Authentication required',
      });
      return;
    }

    const { id } = req.params;
    const messages = await conversationService.getConversationMessages(id);

    res.status(200).json({
      success: true,
      data: messages,
    });
  } catch (error: any) {
    logger.error('Get messages error:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to get messages',
    });
  }
});

export default router;
