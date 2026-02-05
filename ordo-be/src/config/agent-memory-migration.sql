-- Agent Memory with Vector Embeddings Migration
-- Date: 2026-02-04
-- Description: Tables for AI agent memory with pgvector for semantic search

-- Enable pgvector extension (REQUIRED for vector embeddings)
CREATE EXTENSION IF NOT EXISTS vector;

-- Agent Memories Table
CREATE TABLE IF NOT EXISTS agent_memories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    memory_type TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add all columns if they don't exist (for existing tables)
DO $$ 
BEGIN
    -- Add conversation_id
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'agent_memories' AND column_name = 'conversation_id'
    ) THEN
        ALTER TABLE agent_memories ADD COLUMN conversation_id UUID;
    END IF;
    
    -- Add embedding
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'agent_memories' AND column_name = 'embedding'
    ) THEN
        ALTER TABLE agent_memories ADD COLUMN embedding vector(1536);
    END IF;
    
    -- Add importance_score
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'agent_memories' AND column_name = 'importance_score'
    ) THEN
        ALTER TABLE agent_memories ADD COLUMN importance_score DECIMAL(3, 2) DEFAULT 0.5;
    END IF;
    
    -- Add access_count
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'agent_memories' AND column_name = 'access_count'
    ) THEN
        ALTER TABLE agent_memories ADD COLUMN access_count INTEGER DEFAULT 0;
    END IF;
    
    -- Add last_accessed_at
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'agent_memories' AND column_name = 'last_accessed_at'
    ) THEN
        ALTER TABLE agent_memories ADD COLUMN last_accessed_at TIMESTAMPTZ;
    END IF;
    
    -- Add metadata
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'agent_memories' AND column_name = 'metadata'
    ) THEN
        ALTER TABLE agent_memories ADD COLUMN metadata JSONB DEFAULT '{}';
    END IF;
    
    -- Add tags
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'agent_memories' AND column_name = 'tags'
    ) THEN
        ALTER TABLE agent_memories ADD COLUMN tags TEXT[] DEFAULT '{}';
    END IF;
    
    -- Add expires_at
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'agent_memories' AND column_name = 'expires_at'
    ) THEN
        ALTER TABLE agent_memories ADD COLUMN expires_at TIMESTAMPTZ;
    END IF;
END $$;

-- Add constraints if they don't exist
DO $$
BEGIN
    -- Add memory_type check constraint
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.constraint_column_usage 
        WHERE table_name = 'agent_memories' AND constraint_name = 'agent_memories_memory_type_check'
    ) THEN
        ALTER TABLE agent_memories ADD CONSTRAINT agent_memories_memory_type_check 
        CHECK (memory_type IN ('conversation', 'decision', 'preference', 'fact', 'instruction'));
    END IF;
    
    -- Add importance_score check constraint
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.constraint_column_usage 
        WHERE table_name = 'agent_memories' AND constraint_name = 'agent_memories_importance_score_check'
    ) THEN
        ALTER TABLE agent_memories ADD CONSTRAINT agent_memories_importance_score_check 
        CHECK (importance_score >= 0 AND importance_score <= 1);
    END IF;
EXCEPTION
    WHEN duplicate_object THEN
        NULL; -- Constraint already exists, ignore
END $$;

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_agent_memories_user_id ON agent_memories(user_id);
CREATE INDEX IF NOT EXISTS idx_agent_memories_conversation_id ON agent_memories(conversation_id);
CREATE INDEX IF NOT EXISTS idx_agent_memories_type ON agent_memories(memory_type);
CREATE INDEX IF NOT EXISTS idx_agent_memories_importance ON agent_memories(importance_score DESC);
CREATE INDEX IF NOT EXISTS idx_agent_memories_created_at ON agent_memories(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_agent_memories_expires_at ON agent_memories(expires_at) WHERE expires_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_agent_memories_tags ON agent_memories USING GIN(tags);

-- Vector similarity search index (IVFFlat for faster approximate search)
-- Note: This requires pgvector extension to be enabled
-- CREATE INDEX IF NOT EXISTS idx_agent_memories_embedding ON agent_memories 
-- USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);

-- Alternative: Use HNSW index for better performance (requires pgvector 0.5.0+)
-- CREATE INDEX IF NOT EXISTS idx_agent_memories_embedding ON agent_memories 
-- USING hnsw (embedding vector_cosine_ops);

-- Function to update last_accessed_at
CREATE OR REPLACE FUNCTION update_memory_access()
RETURNS TRIGGER AS $$
BEGIN
    NEW.last_accessed_at = NOW();
    NEW.access_count = NEW.access_count + 1;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to clean up expired memories
CREATE OR REPLACE FUNCTION cleanup_expired_memories()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM agent_memories
    WHERE expires_at IS NOT NULL AND expires_at < NOW();
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Memory Statistics View
CREATE OR REPLACE VIEW agent_memory_stats AS
SELECT 
    user_id,
    COUNT(*) as total_memories,
    COUNT(*) FILTER (WHERE memory_type = 'conversation') as conversation_memories,
    COUNT(*) FILTER (WHERE memory_type = 'decision') as decision_memories,
    COUNT(*) FILTER (WHERE memory_type = 'preference') as preference_memories,
    COUNT(*) FILTER (WHERE memory_type = 'fact') as fact_memories,
    COUNT(*) FILTER (WHERE memory_type = 'instruction') as instruction_memories,
    AVG(importance_score) as avg_importance,
    MAX(created_at) as last_memory_at
FROM agent_memories
GROUP BY user_id;

-- RPC Function for Vector Similarity Search
CREATE OR REPLACE FUNCTION search_memories(
    query_embedding vector(1536),
    query_user_id UUID,
    match_threshold DECIMAL DEFAULT 0.7,
    match_count INTEGER DEFAULT 5
)
RETURNS TABLE (
    id UUID,
    user_id UUID,
    conversation_id UUID,
    content TEXT,
    memory_type TEXT,
    importance_score DECIMAL,
    access_count INTEGER,
    last_accessed_at TIMESTAMPTZ,
    metadata JSONB,
    tags TEXT[],
    created_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ,
    similarity DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        agent_memories.id,
        agent_memories.user_id,
        agent_memories.conversation_id,
        agent_memories.content,
        agent_memories.memory_type,
        agent_memories.importance_score,
        agent_memories.access_count,
        agent_memories.last_accessed_at,
        agent_memories.metadata,
        agent_memories.tags,
        agent_memories.created_at,
        agent_memories.expires_at,
        (1 - (agent_memories.embedding <=> query_embedding))::DECIMAL as similarity
    FROM agent_memories
    WHERE agent_memories.user_id = query_user_id
        AND (agent_memories.expires_at IS NULL OR agent_memories.expires_at > NOW())
        AND (1 - (agent_memories.embedding <=> query_embedding)) >= match_threshold
    ORDER BY 
        agent_memories.importance_score DESC,
        similarity DESC,
        agent_memories.created_at DESC
    LIMIT match_count;
END;
$$ LANGUAGE plpgsql;

-- Comments
COMMENT ON TABLE agent_memories IS 'Stores AI agent memories with vector embeddings for semantic search';
COMMENT ON COLUMN agent_memories.embedding IS 'Vector embedding (1536 dimensions) for semantic similarity search';
COMMENT ON COLUMN agent_memories.importance_score IS 'Importance score (0-1) for memory prioritization';
COMMENT ON COLUMN agent_memories.memory_type IS 'Type of memory: conversation, decision, preference, fact, instruction';
COMMENT ON COLUMN agent_memories.expires_at IS 'Optional expiration timestamp for temporary memories';
COMMENT ON FUNCTION search_memories IS 'Performs vector similarity search on agent memories using cosine distance';
