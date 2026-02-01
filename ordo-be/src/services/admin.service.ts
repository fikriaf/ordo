import supabase from '../config/database';
import logger from '../config/logger';
import { User, Transaction, AuditLog } from '../types';

interface DashboardMetrics {
  activeUsers: number;
  totalTransactions: number;
  successRate: number;
  averageResponseTime: number;
  errorRate: number;
  pendingTransactions: number;
  totalUsers: number;
}

interface UserFilters {
  search?: string;
  page?: number;
  limit?: number;
}

interface AdminTransactionFilters {
  userId?: string;
  status?: string;
  type?: string;
  startDate?: string;
  endDate?: string;
  page?: number;
  limit?: number;
}

interface PaginatedResult<T> {
  items: T[];
  total: number;
  page: number;
  limit: number;
  hasNext: boolean;
}

class AdminService {
  async getDashboardMetrics(): Promise<DashboardMetrics> {
    try {
      // Active users (users with activity in last 24 hours)
      const { count: activeUsers } = await supabase
        .from('users')
        .select('*', { count: 'exact', head: true })
        .gte('updated_at', new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString());

      // Total users
      const { count: totalUsers } = await supabase
        .from('users')
        .select('*', { count: 'exact', head: true });

      // Total transactions
      const { count: totalTransactions } = await supabase
        .from('transactions')
        .select('*', { count: 'exact', head: true });

      // Success rate (confirmed / total)
      const { count: confirmedTransactions } = await supabase
        .from('transactions')
        .select('*', { count: 'exact', head: true })
        .eq('status', 'confirmed');

      const successRate =
        totalTransactions && totalTransactions > 0
          ? (confirmedTransactions || 0) / totalTransactions
          : 0;

      // Pending transactions
      const { count: pendingTransactions } = await supabase
        .from('transactions')
        .select('*', { count: 'exact', head: true })
        .eq('status', 'pending');

      // Error rate (failed / total)
      const { count: failedTransactions } = await supabase
        .from('transactions')
        .select('*', { count: 'exact', head: true })
        .eq('status', 'failed');

      const errorRate =
        totalTransactions && totalTransactions > 0
          ? (failedTransactions || 0) / totalTransactions
          : 0;

      // Average response time (mock for now - would need request logging)
      const averageResponseTime = 250; // ms

      return {
        activeUsers: activeUsers || 0,
        totalUsers: totalUsers || 0,
        totalTransactions: totalTransactions || 0,
        successRate: Math.round(successRate * 100) / 100,
        averageResponseTime,
        errorRate: Math.round(errorRate * 100) / 100,
        pendingTransactions: pendingTransactions || 0,
      };
    } catch (error) {
      logger.error('Error getting dashboard metrics:', error);
      throw new Error('Failed to get dashboard metrics');
    }
  }

  async getUsers(filters: UserFilters): Promise<PaginatedResult<User>> {
    try {
      const page = filters.page || 1;
      const limit = filters.limit || 20;
      const offset = (page - 1) * limit;

      let query = supabase.from('users').select('*', { count: 'exact' });

      // Search filter
      if (filters.search) {
        query = query.or(
          `email.ilike.%${filters.search}%,username.ilike.%${filters.search}%`
        );
      }

      // Pagination
      query = query.range(offset, offset + limit - 1).order('created_at', { ascending: false });

      const { data, count, error } = await query;

      if (error) {
        logger.error('Error getting users:', error);
        throw new Error('Failed to get users');
      }

      return {
        items: data || [],
        total: count || 0,
        page,
        limit,
        hasNext: count ? offset + limit < count : false,
      };
    } catch (error) {
      logger.error('Error getting users:', error);
      throw new Error('Failed to get users');
    }
  }

  async getUserById(userId: string): Promise<User | null> {
    try {
      const { data, error } = await supabase
        .from('users')
        .select('*')
        .eq('id', userId)
        .single();

      if (error) {
        if (error.code === 'PGRST116') {
          return null;
        }
        logger.error('Error getting user:', error);
        throw new Error('Failed to get user');
      }

      return data;
    } catch (error) {
      logger.error('Error getting user by ID:', error);
      throw new Error('Failed to get user');
    }
  }

  async deleteUser(userId: string, adminId: string): Promise<void> {
    try {
      // Log audit event
      await this.logAuditEvent({
        admin_id: adminId,
        action: 'DELETE_USER',
        resource_type: 'user',
        resource_id: userId,
        metadata: {},
      });

      // Delete user (cascade will handle wallets and transactions)
      const { error } = await supabase.from('users').delete().eq('id', userId);

      if (error) {
        logger.error('Error deleting user:', error);
        throw new Error('Failed to delete user');
      }

      logger.info(`User deleted by admin`, { userId, adminId });
    } catch (error) {
      logger.error('Error deleting user:', error);
      throw new Error('Failed to delete user');
    }
  }

  async getTransactions(
    filters: AdminTransactionFilters
  ): Promise<PaginatedResult<Transaction>> {
    try {
      const page = filters.page || 1;
      const limit = filters.limit || 50;
      const offset = (page - 1) * limit;

      let query = supabase.from('transactions').select('*', { count: 'exact' });

      // Filters
      if (filters.userId) {
        query = query.eq('user_id', filters.userId);
      }
      if (filters.status) {
        query = query.eq('status', filters.status);
      }
      if (filters.type) {
        query = query.eq('type', filters.type);
      }
      if (filters.startDate) {
        query = query.gte('created_at', filters.startDate);
      }
      if (filters.endDate) {
        query = query.lte('created_at', filters.endDate);
      }

      // Pagination
      query = query.range(offset, offset + limit - 1).order('created_at', { ascending: false });

      const { data, count, error } = await query;

      if (error) {
        logger.error('Error getting transactions:', error);
        throw new Error('Failed to get transactions');
      }

      return {
        items: data || [],
        total: count || 0,
        page,
        limit,
        hasNext: count ? offset + limit < count : false,
      };
    } catch (error) {
      logger.error('Error getting transactions:', error);
      throw new Error('Failed to get transactions');
    }
  }

  async getTransactionStats(): Promise<{
    total: number;
    confirmed: number;
    pending: number;
    failed: number;
    last24h: number;
  }> {
    try {
      const { count: total } = await supabase
        .from('transactions')
        .select('*', { count: 'exact', head: true });

      const { count: confirmed } = await supabase
        .from('transactions')
        .select('*', { count: 'exact', head: true })
        .eq('status', 'confirmed');

      const { count: pending } = await supabase
        .from('transactions')
        .select('*', { count: 'exact', head: true })
        .eq('status', 'pending');

      const { count: failed } = await supabase
        .from('transactions')
        .select('*', { count: 'exact', head: true })
        .eq('status', 'failed');

      const { count: last24h } = await supabase
        .from('transactions')
        .select('*', { count: 'exact', head: true })
        .gte('created_at', new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString());

      return {
        total: total || 0,
        confirmed: confirmed || 0,
        pending: pending || 0,
        failed: failed || 0,
        last24h: last24h || 0,
      };
    } catch (error) {
      logger.error('Error getting transaction stats:', error);
      throw new Error('Failed to get transaction stats');
    }
  }

  async logAuditEvent(event: Omit<AuditLog, 'id' | 'created_at'>): Promise<void> {
    try {
      const { error } = await supabase.from('audit_logs').insert({
        admin_id: event.admin_id,
        action: event.action,
        resource_type: event.resource_type,
        resource_id: event.resource_id,
        metadata: event.metadata,
      });

      if (error) {
        logger.error('Error logging audit event:', error);
        // Don't throw - audit logging failure shouldn't break operations
      }
    } catch (error) {
      logger.error('Error logging audit event:', error);
    }
  }

  async getAuditLogs(filters: {
    adminId?: string;
    action?: string;
    startDate?: string;
    endDate?: string;
    page?: number;
    limit?: number;
  }): Promise<PaginatedResult<AuditLog>> {
    try {
      const page = filters.page || 1;
      const limit = filters.limit || 50;
      const offset = (page - 1) * limit;

      let query = supabase.from('audit_logs').select('*', { count: 'exact' });

      if (filters.adminId) {
        query = query.eq('admin_id', filters.adminId);
      }
      if (filters.action) {
        query = query.eq('action', filters.action);
      }
      if (filters.startDate) {
        query = query.gte('created_at', filters.startDate);
      }
      if (filters.endDate) {
        query = query.lte('created_at', filters.endDate);
      }

      query = query.range(offset, offset + limit - 1).order('created_at', { ascending: false });

      const { data, count, error } = await query;

      if (error) {
        logger.error('Error getting audit logs:', error);
        throw new Error('Failed to get audit logs');
      }

      return {
        items: data || [],
        total: count || 0,
        page,
        limit,
        hasNext: count ? offset + limit < count : false,
      };
    } catch (error) {
      logger.error('Error getting audit logs:', error);
      throw new Error('Failed to get audit logs');
    }
  }
}

export default new AdminService();
