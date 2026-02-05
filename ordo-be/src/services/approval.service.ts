import { v4 as uuidv4 } from 'uuid';
import supabase from '../config/database';
import logger from '../config/logger';
import { ApprovalRequest } from '../types';
import realtimeService from './realtime.service';

export class ApprovalService {
  async createApprovalRequest(
    userId: string,
    requestType: ApprovalRequest['request_type'],
    pendingTransaction: Record<string, any>,
    options?: {
      estimatedRiskScore?: number;
      estimatedUsdValue?: number;
      agentReasoning?: string;
      limitingFactors?: Record<string, any>;
      alternativeOptions?: Record<string, any>;
      expiresInMinutes?: number;
    }
  ): Promise<ApprovalRequest> {
    try {
      const id = uuidv4();
      const expiresAt = new Date();
      expiresAt.setMinutes(expiresAt.getMinutes() + (options?.expiresInMinutes || 15));

      const { data, error } = await supabase
        .from('approval_queue')
        .insert({
          id,
          user_id: userId,
          request_type: requestType,
          pending_transaction: pendingTransaction,
          estimated_risk_score: options?.estimatedRiskScore,
          estimated_usd_value: options?.estimatedUsdValue,
          agent_reasoning: options?.agentReasoning,
          limiting_factors: options?.limitingFactors,
          alternative_options: options?.alternativeOptions,
          expires_at: expiresAt.toISOString(),
        })
        .select()
        .single();

      if (error) {
        logger.error('Failed to create approval request:', error);
        throw new Error('Failed to create approval request');
      }

      logger.info(`Approval request created: ${id} for user ${userId}`);
      
      // Emit real-time notification
      realtimeService.emitApprovalNotification(userId, data);
      
      return data;
    } catch (error) {
      logger.error('Create approval request error:', error);
      throw error;
    }
  }

  async getPendingApprovals(userId: string): Promise<ApprovalRequest[]> {
    try {
      // First, expire old requests
      await this.expireOldRequests();

      const { data, error } = await supabase
        .from('approval_queue')
        .select('*')
        .eq('user_id', userId)
        .eq('status', 'pending')
        .gt('expires_at', new Date().toISOString())
        .order('created_at', { ascending: false });

      if (error) {
        logger.error('Failed to get pending approvals:', error);
        throw new Error('Failed to get pending approvals');
      }

      return data || [];
    } catch (error) {
      logger.error('Get pending approvals error:', error);
      throw error;
    }
  }

  async getApprovalRequest(requestId: string): Promise<ApprovalRequest | null> {
    try {
      const { data, error } = await supabase
        .from('approval_queue')
        .select('*')
        .eq('id', requestId)
        .single();

      if (error) {
        if (error.code === 'PGRST116') {
          return null;
        }
        logger.error('Failed to get approval request:', error);
        throw new Error('Failed to get approval request');
      }

      return data;
    } catch (error) {
      logger.error('Get approval request error:', error);
      throw error;
    }
  }

  async approveRequest(requestId: string, userId: string): Promise<ApprovalRequest> {
    try {
      // Verify ownership
      const request = await this.getApprovalRequest(requestId);
      if (!request) {
        throw new Error('Approval request not found');
      }
      if (request.user_id !== userId) {
        throw new Error('Unauthorized');
      }
      if (request.status !== 'pending') {
        throw new Error('Request already processed');
      }

      const { data, error } = await supabase
        .from('approval_queue')
        .update({
          status: 'approved',
          approved_at: new Date().toISOString(),
        })
        .eq('id', requestId)
        .select()
        .single();

      if (error) {
        logger.error('Failed to approve request:', error);
        throw new Error('Failed to approve request');
      }

      logger.info(`Approval request approved: ${requestId}`);
      return data;
    } catch (error) {
      logger.error('Approve request error:', error);
      throw error;
    }
  }

  async rejectRequest(
    requestId: string,
    userId: string,
    reason?: string
  ): Promise<ApprovalRequest> {
    try {
      // Verify ownership
      const request = await this.getApprovalRequest(requestId);
      if (!request) {
        throw new Error('Approval request not found');
      }
      if (request.user_id !== userId) {
        throw new Error('Unauthorized');
      }
      if (request.status !== 'pending') {
        throw new Error('Request already processed');
      }

      const { data, error } = await supabase
        .from('approval_queue')
        .update({
          status: 'rejected',
          rejected_at: new Date().toISOString(),
          rejection_reason: reason,
        })
        .eq('id', requestId)
        .select()
        .single();

      if (error) {
        logger.error('Failed to reject request:', error);
        throw new Error('Failed to reject request');
      }

      logger.info(`Approval request rejected: ${requestId}`);
      return data;
    } catch (error) {
      logger.error('Reject request error:', error);
      throw error;
    }
  }

  async getApprovalHistory(
    userId: string,
    filters?: {
      status?: ApprovalRequest['status'];
      requestType?: ApprovalRequest['request_type'];
      startDate?: string;
      endDate?: string;
    },
    pagination?: {
      page?: number;
      limit?: number;
    }
  ): Promise<{ approvals: ApprovalRequest[]; total: number }> {
    try {
      let query = supabase
        .from('approval_queue')
        .select('*', { count: 'exact' })
        .eq('user_id', userId);

      // Apply filters
      if (filters?.status) {
        query = query.eq('status', filters.status);
      }
      if (filters?.requestType) {
        query = query.eq('request_type', filters.requestType);
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

      const { data, error, count } = await query;

      if (error) {
        logger.error('Failed to get approval history:', error);
        throw new Error('Failed to get approval history');
      }

      return {
        approvals: data || [],
        total: count || 0,
      };
    } catch (error) {
      logger.error('Get approval history error:', error);
      throw error;
    }
  }

  private async expireOldRequests(): Promise<void> {
    try {
      await supabase
        .from('approval_queue')
        .update({ status: 'expired' })
        .eq('status', 'pending')
        .lt('expires_at', new Date().toISOString());
    } catch (error) {
      logger.error('Expire old requests error:', error);
      // Don't throw, this is a background task
    }
  }
}

export default new ApprovalService();
