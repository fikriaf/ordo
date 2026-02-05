/**
 * Webhook Service
 * Manages webhooks and delivers events to external URLs
 */

import supabase from '../config/database';
import logger from '../config/logger';
import axios from 'axios';
import crypto from 'crypto';

interface Webhook {
  id: string;
  user_id: string;
  url: string;
  secret: string;
  description?: string;
  events: string[];
  is_active: boolean;
  retry_count: number;
  timeout_seconds: number;
  metadata: Record<string, any>;
  total_deliveries: number;
  successful_deliveries: number;
  failed_deliveries: number;
  last_delivery_at?: string;
  last_success_at?: string;
  last_failure_at?: string;
  created_at: string;
  updated_at: string;
}

interface WebhookDelivery {
  id: string;
  webhook_id: string;
  event_type: string;
  event_data: Record<string, any>;
  status: 'pending' | 'success' | 'failed' | 'retrying';
  attempt_count: number;
  max_attempts: number;
  response_status?: number;
  response_body?: string;
  duration_ms?: number;
  error_message?: string;
  created_at: string;
  delivered_at?: string;
}

interface CreateWebhookParams {
  userId: string;
  url: string;
  events: string[];
  description?: string;
  retryCount?: number;
  timeoutSeconds?: number;
  metadata?: Record<string, any>;
}

interface DeliverEventParams {
  eventType: string;
  eventData: Record<string, any>;
  userId?: string;
}

class WebhookService {
  private readonly AVAILABLE_EVENTS = [
    'transaction.created',
    'transaction.confirmed',
    'transaction.failed',
    'approval.created',
    'approval.approved',
    'approval.rejected',
    'balance.changed',
    'nft.received',
    'nft.transferred',
    'price.alert',
    'portfolio.updated',
  ];

  private retryJobInterval: NodeJS.Timeout | null = null;

  constructor() {
    // Start background retry job (runs every 2 minutes)
    this.startRetryJob();
  }

  /**
   * Start background retry job
   */
  private startRetryJob(): void {
    if (this.retryJobInterval) {
      return; // Already running
    }

    logger.info('Starting webhook retry job');

    // Run immediately
    this.processFailedDeliveries().catch(error => {
      logger.error('Retry job error:', error);
    });

    // Then run every 2 minutes
    this.retryJobInterval = setInterval(() => {
      this.processFailedDeliveries().catch(error => {
        logger.error('Retry job error:', error);
      });
    }, 2 * 60 * 1000);
  }

  /**
   * Stop background retry job
   */
  stopRetryJob(): void {
    if (this.retryJobInterval) {
      clearInterval(this.retryJobInterval);
      this.retryJobInterval = null;
      logger.info('Webhook retry job stopped');
    }
  }

  /**
   * Process failed deliveries for retry
   */
  private async processFailedDeliveries(): Promise<void> {
    try {
      logger.debug('Processing failed webhook deliveries');

      // Get failed deliveries that haven't exceeded max attempts
      const { data: failedDeliveries, error } = await supabase
        .from('webhook_deliveries')
        .select('*, webhooks(*)')
        .in('status', ['failed', 'retrying'])
        .lt('attempt_count', 3) // Use hardcoded max_attempts instead of supabase.raw
        .order('created_at', { ascending: true })
        .limit(50);

      if (error) {
        throw error;
      }

      if (!failedDeliveries || failedDeliveries.length === 0) {
        logger.debug('No failed deliveries to retry');
        return;
      }

      logger.info('Found failed deliveries to retry', { count: failedDeliveries.length });

      // Process each failed delivery
      for (const delivery of failedDeliveries) {
        await this.retryDelivery(delivery);
      }
    } catch (error: any) {
      logger.error('Failed to process failed deliveries:', error);
    }
  }

  /**
   * Retry a failed delivery with exponential backoff
   */
  private async retryDelivery(delivery: any): Promise<void> {
    try {
      const webhook = delivery.webhooks;
      const attemptCount = delivery.attempt_count + 1;

      // Calculate exponential backoff delay
      // 1st retry: 1s, 2nd retry: 2s, 3rd retry: 4s
      const backoffDelay = Math.pow(2, delivery.attempt_count - 1) * 1000;
      const timeSinceLastAttempt = Date.now() - new Date(delivery.created_at).getTime();

      // Check if enough time has passed for retry
      if (timeSinceLastAttempt < backoffDelay) {
        logger.debug('Skipping retry - backoff not elapsed', {
          deliveryId: delivery.id,
          backoffDelay,
          timeSinceLastAttempt,
        });
        return;
      }

      logger.info('Retrying webhook delivery', {
        deliveryId: delivery.id,
        webhookId: webhook.id,
        attemptCount,
        maxAttempts: delivery.max_attempts,
      });

      // Update status to retrying
      await supabase
        .from('webhook_deliveries')
        .update({
          status: 'retrying',
          attempt_count: attemptCount,
        })
        .eq('id', delivery.id);

      // Attempt delivery
      const startTime = Date.now();

      try {
        // Prepare payload
        const payload = {
          event: delivery.event_type,
          data: delivery.event_data,
          timestamp: new Date().toISOString(),
          webhook_id: webhook.id,
          retry_attempt: attemptCount,
        };

        const payloadString = JSON.stringify(payload);
        const signature = this.generateSignature(payloadString, webhook.secret);

        // Send request
        const response = await axios.post(webhook.url, payload, {
          headers: {
            'Content-Type': 'application/json',
            'X-Webhook-Signature': signature,
            'X-Webhook-Event': delivery.event_type,
            'X-Webhook-Retry': attemptCount.toString(),
            'User-Agent': 'Ordo-Webhook/1.0',
          },
          timeout: webhook.timeout_seconds * 1000,
        });

        const duration = Date.now() - startTime;

        // Update delivery as success
        await supabase
          .from('webhook_deliveries')
          .update({
            status: 'success',
            attempt_count: attemptCount,
            response_status: response.status,
            response_body: JSON.stringify(response.data).substring(0, 1000),
            duration_ms: duration,
            delivered_at: new Date().toISOString(),
          })
          .eq('id', delivery.id);

        logger.info('Webhook retry successful', {
          deliveryId: delivery.id,
          attemptCount,
          duration,
        });
      } catch (error: any) {
        const duration = Date.now() - startTime;

        logger.error('Webhook retry failed:', {
          deliveryId: delivery.id,
          attemptCount,
          error: error.message,
        });

        // Determine final status
        const finalStatus = attemptCount >= delivery.max_attempts ? 'failed' : 'retrying';

        // Update delivery
        await supabase
          .from('webhook_deliveries')
          .update({
            status: finalStatus,
            attempt_count: attemptCount,
            response_status: error.response?.status,
            response_body: error.response?.data
              ? JSON.stringify(error.response.data).substring(0, 1000)
              : error.message,
            duration_ms: duration,
            error_message: error.message,
            ...(finalStatus === 'failed' ? { failed_at: new Date().toISOString() } : {}),
          })
          .eq('id', delivery.id);

        if (finalStatus === 'failed') {
          logger.warn('Webhook delivery permanently failed after max retries', {
            deliveryId: delivery.id,
            maxAttempts: delivery.max_attempts,
          });
        }
      }
    } catch (error: any) {
      logger.error('Failed to retry delivery:', { deliveryId: delivery.id, error });
    }
  }

  /**
   * Generate webhook secret
   */
  private generateSecret(): string {
    return crypto.randomBytes(32).toString('hex');
  }

  /**
   * Generate HMAC signature for webhook payload
   */
  private generateSignature(payload: string, secret: string): string {
    return crypto
      .createHmac('sha256', secret)
      .update(payload)
      .digest('hex');
  }

  /**
   * Verify webhook signature
   */
  verifySignature(payload: string, signature: string, secret: string): boolean {
    const expectedSignature = this.generateSignature(payload, secret);
    return crypto.timingSafeEqual(
      Buffer.from(signature),
      Buffer.from(expectedSignature)
    );
  }

  /**
   * Create a new webhook
   */
  async createWebhook(params: CreateWebhookParams): Promise<Webhook> {
    try {
      logger.info('Creating webhook', { userId: params.userId, url: params.url });

      // Validate events
      const invalidEvents = params.events.filter(
        event => !this.AVAILABLE_EVENTS.includes(event)
      );

      if (invalidEvents.length > 0) {
        throw new Error(`Invalid events: ${invalidEvents.join(', ')}`);
      }

      // Generate secret
      const secret = this.generateSecret();

      const { data, error } = await supabase
        .from('webhooks')
        .insert({
          user_id: params.userId,
          url: params.url,
          secret,
          description: params.description,
          events: params.events,
          retry_count: params.retryCount || 3,
          timeout_seconds: params.timeoutSeconds || 30,
          metadata: params.metadata || {},
        })
        .select()
        .single();

      if (error) {
        throw error;
      }

      logger.info('Webhook created', { webhookId: data.id });

      return data as Webhook;
    } catch (error: any) {
      logger.error('Failed to create webhook:', error);
      throw error;
    }
  }

  /**
   * Get webhooks for a user
   */
  async getUserWebhooks(userId: string): Promise<Webhook[]> {
    try {
      const { data, error } = await supabase
        .from('webhooks')
        .select('*')
        .eq('user_id', userId)
        .order('created_at', { ascending: false });

      if (error) {
        throw error;
      }

      return (data || []) as Webhook[];
    } catch (error: any) {
      logger.error('Failed to get user webhooks:', error);
      throw error;
    }
  }

  /**
   * Get webhook by ID
   */
  async getWebhook(webhookId: string, userId: string): Promise<Webhook | null> {
    try {
      const { data, error } = await supabase
        .from('webhooks')
        .select('*')
        .eq('id', webhookId)
        .eq('user_id', userId)
        .single();

      if (error) {
        if (error.code === 'PGRST116') {
          return null;
        }
        throw error;
      }

      return data as Webhook;
    } catch (error: any) {
      logger.error('Failed to get webhook:', error);
      throw error;
    }
  }

  /**
   * Update webhook
   */
  async updateWebhook(
    webhookId: string,
    userId: string,
    updates: Partial<CreateWebhookParams>
  ): Promise<Webhook> {
    try {
      logger.info('Updating webhook', { webhookId, userId });

      // Validate events if provided
      if (updates.events) {
        const invalidEvents = updates.events.filter(
          event => !this.AVAILABLE_EVENTS.includes(event)
        );

        if (invalidEvents.length > 0) {
          throw new Error(`Invalid events: ${invalidEvents.join(', ')}`);
        }
      }

      const updateData: any = {};
      if (updates.url) updateData.url = updates.url;
      if (updates.description !== undefined) updateData.description = updates.description;
      if (updates.events) updateData.events = updates.events;
      if (updates.retryCount !== undefined) updateData.retry_count = updates.retryCount;
      if (updates.timeoutSeconds !== undefined) updateData.timeout_seconds = updates.timeoutSeconds;
      if (updates.metadata) updateData.metadata = updates.metadata;

      const { data, error } = await supabase
        .from('webhooks')
        .update(updateData)
        .eq('id', webhookId)
        .eq('user_id', userId)
        .select()
        .single();

      if (error) {
        throw error;
      }

      logger.info('Webhook updated', { webhookId });

      return data as Webhook;
    } catch (error: any) {
      logger.error('Failed to update webhook:', error);
      throw error;
    }
  }

  /**
   * Delete webhook
   */
  async deleteWebhook(webhookId: string, userId: string): Promise<boolean> {
    try {
      logger.info('Deleting webhook', { webhookId, userId });

      const { error } = await supabase
        .from('webhooks')
        .delete()
        .eq('id', webhookId)
        .eq('user_id', userId);

      if (error) {
        throw error;
      }

      logger.info('Webhook deleted', { webhookId });

      return true;
    } catch (error: any) {
      logger.error('Failed to delete webhook:', error);
      throw error;
    }
  }

  /**
   * Toggle webhook active status
   */
  async toggleWebhook(webhookId: string, userId: string, isActive: boolean): Promise<void> {
    try {
      const { error } = await supabase
        .from('webhooks')
        .update({ is_active: isActive })
        .eq('id', webhookId)
        .eq('user_id', userId);

      if (error) {
        throw error;
      }

      logger.info('Webhook toggled', { webhookId, isActive });
    } catch (error: any) {
      logger.error('Failed to toggle webhook:', error);
      throw error;
    }
  }

  /**
   * Deliver event to webhooks
   */
  async deliverEvent(params: DeliverEventParams): Promise<void> {
    try {
      logger.info('Delivering event', { eventType: params.eventType });

      // Get active webhooks subscribed to this event
      let query = supabase
        .from('webhooks')
        .select('*')
        .eq('is_active', true)
        .contains('events', [params.eventType]);

      if (params.userId) {
        query = query.eq('user_id', params.userId);
      }

      const { data: webhooks, error } = await query;

      if (error) {
        throw error;
      }

      if (!webhooks || webhooks.length === 0) {
        logger.debug('No webhooks subscribed to event', { eventType: params.eventType });
        return;
      }

      logger.info('Found webhooks for event', { count: webhooks.length });

      // Deliver to each webhook
      const deliveryPromises = webhooks.map(webhook =>
        this.deliverToWebhook(webhook as Webhook, params.eventType, params.eventData)
      );

      await Promise.allSettled(deliveryPromises);
    } catch (error: any) {
      logger.error('Failed to deliver event:', error);
    }
  }

  /**
   * Deliver event to a specific webhook
   */
  private async deliverToWebhook(
    webhook: Webhook,
    eventType: string,
    eventData: Record<string, any>
  ): Promise<void> {
    try {
      // Create delivery record
      const { data: delivery, error: createError } = await supabase
        .from('webhook_deliveries')
        .insert({
          webhook_id: webhook.id,
          event_type: eventType,
          event_data: eventData,
          status: 'pending',
          max_attempts: webhook.retry_count + 1,
        })
        .select()
        .single();

      if (createError) {
        throw createError;
      }

      // Attempt delivery
      await this.attemptDelivery(webhook, delivery.id, eventType, eventData);
    } catch (error: any) {
      logger.error('Failed to deliver to webhook:', { webhookId: webhook.id, error });
    }
  }

  /**
   * Attempt webhook delivery
   */
  private async attemptDelivery(
    webhook: Webhook,
    deliveryId: string,
    eventType: string,
    eventData: Record<string, any>
  ): Promise<void> {
    const startTime = Date.now();

    try {
      // Prepare payload
      const payload = {
        event: eventType,
        data: eventData,
        timestamp: new Date().toISOString(),
        webhook_id: webhook.id,
      };

      const payloadString = JSON.stringify(payload);
      const signature = this.generateSignature(payloadString, webhook.secret);

      // Send request
      const response = await axios.post(webhook.url, payload, {
        headers: {
          'Content-Type': 'application/json',
          'X-Webhook-Signature': signature,
          'X-Webhook-Event': eventType,
          'User-Agent': 'Ordo-Webhook/1.0',
        },
        timeout: webhook.timeout_seconds * 1000,
      });

      const duration = Date.now() - startTime;

      // Update delivery as success
      await supabase
        .from('webhook_deliveries')
        .update({
          status: 'success',
          attempt_count: 1,
          response_status: response.status,
          response_body: JSON.stringify(response.data).substring(0, 1000),
          duration_ms: duration,
          delivered_at: new Date().toISOString(),
        })
        .eq('id', deliveryId);

      logger.info('Webhook delivered successfully', {
        webhookId: webhook.id,
        deliveryId,
        duration,
      });
    } catch (error: any) {
      const duration = Date.now() - startTime;

      logger.error('Webhook delivery failed:', {
        webhookId: webhook.id,
        deliveryId,
        error: error.message,
      });

      // Update delivery as failed
      await supabase
        .from('webhook_deliveries')
        .update({
          status: 'failed',
          attempt_count: 1,
          response_status: error.response?.status,
          response_body: error.response?.data
            ? JSON.stringify(error.response.data).substring(0, 1000)
            : error.message,
          duration_ms: duration,
          error_message: error.message,
          failed_at: new Date().toISOString(),
        })
        .eq('id', deliveryId);
    }
  }

  /**
   * Test webhook
   */
  async testWebhook(webhookId: string, userId: string): Promise<WebhookDelivery> {
    try {
      const webhook = await this.getWebhook(webhookId, userId);

      if (!webhook) {
        throw new Error('Webhook not found');
      }

      const testEvent = {
        test: true,
        message: 'This is a test webhook delivery',
        timestamp: new Date().toISOString(),
      };

      // Create delivery record
      const { data: delivery, error } = await supabase
        .from('webhook_deliveries')
        .insert({
          webhook_id: webhook.id,
          event_type: 'webhook.test',
          event_data: testEvent,
          status: 'pending',
          max_attempts: 1,
        })
        .select()
        .single();

      if (error) {
        throw error;
      }

      // Attempt delivery
      await this.attemptDelivery(webhook, delivery.id, 'webhook.test', testEvent);

      // Get updated delivery
      const { data: updatedDelivery } = await supabase
        .from('webhook_deliveries')
        .select('*')
        .eq('id', delivery.id)
        .single();

      return updatedDelivery as WebhookDelivery;
    } catch (error: any) {
      logger.error('Failed to test webhook:', error);
      throw error;
    }
  }

  /**
   * Get webhook deliveries
   */
  async getWebhookDeliveries(
    webhookId: string,
    userId: string,
    limit: number = 50
  ): Promise<WebhookDelivery[]> {
    try {
      // Verify webhook belongs to user
      const webhook = await this.getWebhook(webhookId, userId);
      if (!webhook) {
        throw new Error('Webhook not found');
      }

      const { data, error } = await supabase
        .from('webhook_deliveries')
        .select('*')
        .eq('webhook_id', webhookId)
        .order('created_at', { ascending: false })
        .limit(limit);

      if (error) {
        throw error;
      }

      return (data || []) as WebhookDelivery[];
    } catch (error: any) {
      logger.error('Failed to get webhook deliveries:', error);
      throw error;
    }
  }

  /**
   * Get available event types
   */
  getAvailableEvents(): string[] {
    return [...this.AVAILABLE_EVENTS];
  }

  /**
   * Cleanup old deliveries
   */
  async cleanupOldDeliveries(daysToKeep: number = 30): Promise<number> {
    try {
      const { data, error } = await supabase.rpc('cleanup_old_webhook_deliveries', {
        days_to_keep: daysToKeep,
      });

      if (error) {
        throw error;
      }

      const deletedCount = data || 0;
      logger.info('Old webhook deliveries cleaned up', { deletedCount });

      return deletedCount;
    } catch (error: any) {
      logger.error('Failed to cleanup old deliveries:', error);
      return 0;
    }
  }
}

export default new WebhookService();
