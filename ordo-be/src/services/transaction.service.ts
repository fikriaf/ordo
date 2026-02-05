import { v4 as uuidv4 } from 'uuid';
import { Connection } from '@solana/web3.js';
import supabase from '../config/database';
import env from '../config/env';
import logger from '../config/logger';
import { Transaction } from '../types';
import realtimeService from './realtime.service';

export class TransactionService {
  private connection: Connection;

  constructor() {
    this.connection = new Connection(env.SOLANA_RPC_URL, 'confirmed');
  }

  async recordTransaction(
    userId: string,
    walletId: string,
    type: string,
    signature: string,
    metadata?: Record<string, any>
  ): Promise<Transaction> {
    try {
      const transactionId = uuidv4();
      
      const { data: transaction, error } = await supabase
        .from('transactions')
        .insert({
          id: transactionId,
          user_id: userId,
          wallet_id: walletId,
          type,
          signature,
          status: 'pending',
          metadata: metadata || {},
        })
        .select()
        .single();

      if (error) {
        logger.error('Failed to record transaction:', error);
        throw new Error('Failed to record transaction');
      }

      logger.info(`Transaction recorded: ${signature}`);
      
      // Emit real-time update
      realtimeService.emitTransactionUpdate(userId, transaction);
      
      // Start polling for confirmation in background
      this.pollTransactionStatus(transactionId, signature, userId).catch(err => {
        logger.error('Transaction polling error:', err);
      });

      return transaction;
    } catch (error) {
      logger.error('Record transaction error:', error);
      throw error;
    }
  }

  private async pollTransactionStatus(transactionId: string, signature: string, userId: string): Promise<void> {
    const maxAttempts = 30; // 30 attempts * 2 seconds = 1 minute
    let attempts = 0;

    while (attempts < maxAttempts) {
      try {
        const status = await this.connection.getSignatureStatus(signature);

        if (status.value?.confirmationStatus === 'confirmed' || 
            status.value?.confirmationStatus === 'finalized') {
          await this.updateTransactionStatus(transactionId, 'confirmed', userId);
          logger.info(`Transaction confirmed: ${signature}`);
          return;
        }

        if (status.value?.err) {
          await this.updateTransactionStatus(transactionId, 'failed', userId);
          logger.error(`Transaction failed: ${signature}`, status.value.err);
          return;
        }

        attempts++;
        await new Promise(resolve => setTimeout(resolve, 2000)); // Wait 2 seconds
      } catch (error) {
        logger.error('Error polling transaction status:', error);
        attempts++;
        await new Promise(resolve => setTimeout(resolve, 2000));
      }
    }

    // Timeout - mark as failed
    await this.updateTransactionStatus(transactionId, 'failed', userId);
    logger.warn(`Transaction timeout: ${signature}`);
  }

  async updateTransactionStatus(
    transactionId: string,
    status: 'pending' | 'confirmed' | 'failed',
    userId?: string
  ): Promise<void> {
    try {
      const { data: transaction, error } = await supabase
        .from('transactions')
        .update({ status, updated_at: new Date().toISOString() })
        .eq('id', transactionId)
        .select()
        .single();

      if (error) {
        logger.error('Failed to update transaction status:', error);
        throw new Error('Failed to update transaction status');
      }

      // Emit real-time update if userId is provided
      if (userId && transaction) {
        realtimeService.emitTransactionUpdate(userId, transaction);
      }
    } catch (error) {
      logger.error('Update transaction status error:', error);
      throw error;
    }
  }

  async getTransaction(transactionId: string): Promise<Transaction | null> {
    try {
      const { data: transaction, error } = await supabase
        .from('transactions')
        .select('*')
        .eq('id', transactionId)
        .single();

      if (error) {
        logger.error('Failed to get transaction:', error);
        return null;
      }

      return transaction;
    } catch (error) {
      logger.error('Get transaction error:', error);
      return null;
    }
  }

  async getUserTransactions(
    userId: string,
    filters?: {
      type?: string;
      status?: string;
      startDate?: string;
      endDate?: string;
    },
    pagination?: {
      page?: number;
      limit?: number;
    }
  ): Promise<{ transactions: Transaction[]; total: number }> {
    try {
      let query = supabase
        .from('transactions')
        .select('*', { count: 'exact' })
        .eq('user_id', userId);

      // Apply filters
      if (filters?.type) {
        query = query.eq('type', filters.type);
      }
      if (filters?.status) {
        query = query.eq('status', filters.status);
      }
      if (filters?.startDate) {
        query = query.gte('created_at', filters.startDate);
      }
      if (filters?.endDate) {
        query = query.lte('created_at', filters.endDate);
      }

      // Apply pagination
      const page = pagination?.page || 1;
      const limit = pagination?.limit || 20;
      const offset = (page - 1) * limit;

      query = query
        .order('created_at', { ascending: false })
        .range(offset, offset + limit - 1);

      const { data: transactions, error, count } = await query;

      if (error) {
        logger.error('Failed to get user transactions:', error);
        throw new Error('Failed to get user transactions');
      }

      return {
        transactions: transactions || [],
        total: count || 0,
      };
    } catch (error) {
      logger.error('Get user transactions error:', error);
      throw error;
    }
  }
}

export default new TransactionService();
