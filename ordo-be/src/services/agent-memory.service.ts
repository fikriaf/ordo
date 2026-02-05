/**
 * Agent Memory Service
 * Stores and retrieves AI agent memories with vector embeddings for semantic search
 */

import supabase from '../config/database';
import logger from '../config/logger';
import axios from 'axios';
import env from '../config/env';

interface Memory {
  id: string;
  user_id: string;
  conversation_id?: string;
  content: string;
  memory_type: 'conversation' | 'decision' | 'preference' | 'fact' | 'instruction';
  importance_score: number;
  access_count: number;
  last_accessed_at?: string;
  metadata: Record<string, any>;
  tags: string[];
  created_at: string;
  expires_at?: string;
}

interface StoreMemoryParams {
  userId: string;
  conversationId?: string;
  content: string;
  memoryType: 'conversation' | 'decision' | 'preference' | 'fact' | 'instruction';
  importanceScore?: number;
  metadata?: Record<string, any>;
  tags?: string[];
  expiresAt?: Date;
}

interface SearchResult {
  memory: Memory;
  similarity: number;
}

class AgentMemoryService {
  private readonly EMBEDDING_MODEL = 'text-embedding-3-small';
  private readonly EMBEDDING_DIMENSIONS = 1536;

  /**
   * Generate embedding vector for text using OpenAI
   */
  private async generateEmbedding(text: string): Promise<number[]> {
    try {
      const response = await axios.post(
        'https://api.openai.com/v1/embeddings',
        {
          model: this.EMBEDDING_MODEL,
          input: text,
          dimensions: this.EMBEDDING_DIMENSIONS,
        },
        {
          headers: {
            'Authorization': `Bearer ${env.OPENAI_API_KEY}`,
            'Content-Type': 'application/json',
          },
        }
      );

      const embedding = response.data.data[0].embedding;
      logger.debug('Generated embedding', { textLength: text.length, dimensions: embedding.length });

      return embedding;
    } catch (error: any) {
      logger.error('Failed to generate embedding:', error);
      throw new Error('Failed to generate embedding: ' + error.message);
    }
  }

  /**
   * Store a new memory with embedding
   */
  async storeMemory(params: StoreMemoryParams): Promise<Memory> {
    try {
      logger.info('Storing memory', {
        userId: params.userId,
        type: params.memoryType,
        contentLength: params.content.length,
      });

      // Generate embedding
      const embedding = await this.generateEmbedding(params.content);

      // Store in database
      const { data, error } = await supabase
        .from('agent_memories')
        .insert({
          user_id: params.userId,
          conversation_id: params.conversationId,
          content: params.content,
          memory_type: params.memoryType,
          embedding: JSON.stringify(embedding), // Store as JSON string
          importance_score: params.importanceScore || 0.5,
          metadata: params.metadata || {},
          tags: params.tags || [],
          expires_at: params.expiresAt?.toISOString(),
        })
        .select()
        .single();

      if (error) {
        throw error;
      }

      logger.info('Memory stored successfully', { memoryId: data.id });

      return data as Memory;
    } catch (error: any) {
      logger.error('Failed to store memory:', error);
      throw error;
    }
  }

  /**
   * Semantic search for relevant memories using cosine similarity
   */
  async searchMemories(
    userId: string,
    query: string,
    limit: number = 5,
    minSimilarity: number = 0.7
  ): Promise<SearchResult[]> {
    try {
      logger.info('Searching memories', { userId, query, limit });

      // Generate query embedding
      const queryEmbedding = await this.generateEmbedding(query);

      // Perform vector similarity search
      // Note: This uses RPC function for vector similarity
      // You need to create this function in Supabase
      const { data, error } = await supabase.rpc('search_memories', {
        query_embedding: queryEmbedding,
        query_user_id: userId,
        match_threshold: minSimilarity,
        match_count: limit,
      });

      if (error) {
        logger.warn('Vector search failed, falling back to text search:', error);
        // Fallback to simple text search
        return await this.fallbackTextSearch(userId, query, limit);
      }

      logger.info('Found memories', { count: data?.length || 0 });

      return (data || []).map((item: any) => ({
        memory: item as Memory,
        similarity: item.similarity || 0,
      }));
    } catch (error: any) {
      logger.error('Failed to search memories:', error);
      // Fallback to text search
      return await this.fallbackTextSearch(userId, query, limit);
    }
  }

  /**
   * Fallback text search when vector search is unavailable
   */
  private async fallbackTextSearch(
    userId: string,
    query: string,
    limit: number
  ): Promise<SearchResult[]> {
    try {
      logger.info('Using fallback text search');

      const { data, error } = await supabase
        .from('agent_memories')
        .select('*')
        .eq('user_id', userId)
        .or(`content.ilike.%${query}%,tags.cs.{${query}}`)
        .order('importance_score', { ascending: false })
        .order('created_at', { ascending: false })
        .limit(limit);

      if (error) {
        throw error;
      }

      return (data || []).map((memory: any) => ({
        memory: memory as Memory,
        similarity: 0.5, // Default similarity for text search
      }));
    } catch (error: any) {
      logger.error('Fallback text search failed:', error);
      return [];
    }
  }

  /**
   * Get recent memories for a user
   */
  async getRecentMemories(
    userId: string,
    limit: number = 10,
    memoryType?: string
  ): Promise<Memory[]> {
    try {
      logger.info('Getting recent memories', { userId, limit, memoryType });

      let query = supabase
        .from('agent_memories')
        .select('*')
        .eq('user_id', userId)
        .order('created_at', { ascending: false })
        .limit(limit);

      if (memoryType) {
        query = query.eq('memory_type', memoryType);
      }

      const { data, error } = await query;

      if (error) {
        throw error;
      }

      logger.info('Retrieved recent memories', { count: data?.length || 0 });

      return (data || []) as Memory[];
    } catch (error: any) {
      logger.error('Failed to get recent memories:', error);
      throw error;
    }
  }

  /**
   * Get memory by ID and update access tracking
   */
  async getMemory(memoryId: string, userId: string): Promise<Memory | null> {
    try {
      const { data, error } = await supabase
        .from('agent_memories')
        .select('*')
        .eq('id', memoryId)
        .eq('user_id', userId)
        .single();

      if (error) {
        if (error.code === 'PGRST116') {
          return null; // Not found
        }
        throw error;
      }

      // Update access tracking
      await supabase
        .from('agent_memories')
        .update({
          access_count: (data.access_count || 0) + 1,
          last_accessed_at: new Date().toISOString(),
        })
        .eq('id', memoryId);

      return data as Memory;
    } catch (error: any) {
      logger.error('Failed to get memory:', error);
      throw error;
    }
  }

  /**
   * Delete a memory
   */
  async deleteMemory(memoryId: string, userId: string): Promise<boolean> {
    try {
      logger.info('Deleting memory', { memoryId, userId });

      const { error } = await supabase
        .from('agent_memories')
        .delete()
        .eq('id', memoryId)
        .eq('user_id', userId);

      if (error) {
        throw error;
      }

      logger.info('Memory deleted successfully');

      return true;
    } catch (error: any) {
      logger.error('Failed to delete memory:', error);
      throw error;
    }
  }

  /**
   * Update memory importance score
   */
  async updateImportance(
    memoryId: string,
    userId: string,
    importanceScore: number
  ): Promise<void> {
    try {
      if (importanceScore < 0 || importanceScore > 1) {
        throw new Error('Importance score must be between 0 and 1');
      }

      const { error } = await supabase
        .from('agent_memories')
        .update({ importance_score: importanceScore })
        .eq('id', memoryId)
        .eq('user_id', userId);

      if (error) {
        throw error;
      }

      logger.info('Memory importance updated', { memoryId, importanceScore });
    } catch (error: any) {
      logger.error('Failed to update memory importance:', error);
      throw error;
    }
  }

  /**
   * Get memory statistics for a user
   */
  async getMemoryStats(userId: string): Promise<any> {
    try {
      const { data, error } = await supabase
        .from('agent_memory_stats')
        .select('*')
        .eq('user_id', userId)
        .single();

      if (error) {
        if (error.code === 'PGRST116') {
          // No memories yet
          return {
            total_memories: 0,
            conversation_memories: 0,
            decision_memories: 0,
            preference_memories: 0,
            fact_memories: 0,
            instruction_memories: 0,
            avg_importance: 0,
            last_memory_at: null,
          };
        }
        throw error;
      }

      return data;
    } catch (error: any) {
      logger.error('Failed to get memory stats:', error);
      throw error;
    }
  }

  /**
   * Clean up expired memories
   */
  async cleanupExpiredMemories(): Promise<number> {
    try {
      logger.info('Cleaning up expired memories');

      const { data, error } = await supabase.rpc('cleanup_expired_memories');

      if (error) {
        throw error;
      }

      const deletedCount = data || 0;
      logger.info('Expired memories cleaned up', { deletedCount });

      return deletedCount;
    } catch (error: any) {
      logger.error('Failed to cleanup expired memories:', error);
      return 0;
    }
  }

  /**
   * Get memories by tags
   */
  async getMemoriesByTags(
    userId: string,
    tags: string[],
    limit: number = 10
  ): Promise<Memory[]> {
    try {
      const { data, error } = await supabase
        .from('agent_memories')
        .select('*')
        .eq('user_id', userId)
        .contains('tags', tags)
        .order('importance_score', { ascending: false })
        .order('created_at', { ascending: false })
        .limit(limit);

      if (error) {
        throw error;
      }

      return (data || []) as Memory[];
    } catch (error: any) {
      logger.error('Failed to get memories by tags:', error);
      throw error;
    }
  }
}

export default new AgentMemoryService();
