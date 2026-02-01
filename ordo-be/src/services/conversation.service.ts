import { v4 as uuidv4 } from 'uuid';
import supabase from '../config/database';
import logger from '../config/logger';
import { Conversation, Message } from '../types';

export class ConversationService {
  async getOrCreateConversation(userId: string): Promise<Conversation> {
    try {
      // Get active conversation
      const { data: activeConversation, error: fetchError } = await supabase
        .from('conversations')
        .select('*')
        .eq('user_id', userId)
        .eq('is_active', true)
        .order('updated_at', { ascending: false })
        .limit(1)
        .single();

      if (activeConversation && !fetchError) {
        return activeConversation;
      }

      // Create new conversation
      const conversationId = uuidv4();
      const { data: newConversation, error: createError } = await supabase
        .from('conversations')
        .insert({
          id: conversationId,
          user_id: userId,
          is_active: true,
        })
        .select()
        .single();

      if (createError) {
        logger.error('Failed to create conversation:', createError);
        throw new Error('Failed to create conversation');
      }

      logger.info(`Conversation created: ${conversationId}`);
      return newConversation;
    } catch (error) {
      logger.error('Get or create conversation error:', error);
      throw error;
    }
  }

  async saveMessage(
    conversationId: string,
    role: 'user' | 'assistant' | 'system',
    content: string,
    metadata?: Record<string, any>
  ): Promise<Message> {
    try {
      const messageId = uuidv4();
      const { data: message, error } = await supabase
        .from('messages')
        .insert({
          id: messageId,
          conversation_id: conversationId,
          role,
          content,
          metadata: metadata || {},
        })
        .select()
        .single();

      if (error) {
        logger.error('Failed to save message:', error);
        throw new Error('Failed to save message');
      }

      // Update conversation updated_at
      await supabase
        .from('conversations')
        .update({ updated_at: new Date().toISOString() })
        .eq('id', conversationId);

      return message;
    } catch (error) {
      logger.error('Save message error:', error);
      throw error;
    }
  }

  async getConversationHistory(
    conversationId: string,
    limit: number = 10
  ): Promise<Message[]> {
    try {
      const { data: messages, error } = await supabase
        .from('messages')
        .select('*')
        .eq('conversation_id', conversationId)
        .order('created_at', { ascending: false })
        .limit(limit);

      if (error) {
        logger.error('Failed to get conversation history:', error);
        throw new Error('Failed to get conversation history');
      }

      // Return in chronological order (oldest first)
      return (messages || []).reverse();
    } catch (error) {
      logger.error('Get conversation history error:', error);
      throw error;
    }
  }

  async getUserConversations(userId: string): Promise<Conversation[]> {
    try {
      const { data: conversations, error } = await supabase
        .from('conversations')
        .select('*')
        .eq('user_id', userId)
        .order('updated_at', { ascending: false });

      if (error) {
        logger.error('Failed to get user conversations:', error);
        throw new Error('Failed to get user conversations');
      }

      return conversations || [];
    } catch (error) {
      logger.error('Get user conversations error:', error);
      throw error;
    }
  }

  async getConversationMessages(conversationId: string): Promise<Message[]> {
    try {
      const { data: messages, error } = await supabase
        .from('messages')
        .select('*')
        .eq('conversation_id', conversationId)
        .order('created_at', { ascending: true });

      if (error) {
        logger.error('Failed to get conversation messages:', error);
        throw new Error('Failed to get conversation messages');
      }

      return messages || [];
    } catch (error) {
      logger.error('Get conversation messages error:', error);
      throw error;
    }
  }

  async archiveInactiveConversations(): Promise<void> {
    try {
      const twentyFourHoursAgo = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();

      const { error } = await supabase
        .from('conversations')
        .update({ is_active: false })
        .eq('is_active', true)
        .lt('updated_at', twentyFourHoursAgo);

      if (error) {
        logger.error('Failed to archive inactive conversations:', error);
      } else {
        logger.info('Archived inactive conversations');
      }
    } catch (error) {
      logger.error('Archive inactive conversations error:', error);
    }
  }
}

export default new ConversationService();
