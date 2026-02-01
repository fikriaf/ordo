import { Connection } from '@solana/web3.js';
import supabase from '../config/database';
import env from '../config/env';
import logger from '../config/logger';

interface HealthStatus {
  status: 'healthy' | 'unhealthy' | 'degraded';
  timestamp: string;
  uptime: number;
  version: string;
}

interface DetailedHealthStatus extends HealthStatus {
  dependencies: {
    database: DependencyHealth;
    solanaRpc: DependencyHealth;
    openRouter: DependencyHealth;
  };
}

interface DependencyHealth {
  status: 'healthy' | 'unhealthy';
  responseTime?: number;
  error?: string;
  lastChecked: string;
}

class HealthService {
  private startTime: number = Date.now();

  async getBasicHealth(): Promise<HealthStatus> {
    try {
      const uptime = Math.floor((Date.now() - this.startTime) / 1000);

      return {
        status: 'healthy',
        timestamp: new Date().toISOString(),
        uptime,
        version: '1.0.0',
      };
    } catch (error) {
      logger.error('Error getting basic health:', error);
      return {
        status: 'unhealthy',
        timestamp: new Date().toISOString(),
        uptime: 0,
        version: '1.0.0',
      };
    }
  }

  async getDetailedHealth(): Promise<DetailedHealthStatus> {
    try {
      const uptime = Math.floor((Date.now() - this.startTime) / 1000);

      // Check all dependencies in parallel
      const [database, solanaRpc, openRouter] = await Promise.all([
        this.checkDatabase(),
        this.checkSolanaRpc(),
        this.checkOpenRouter(),
      ]);

      // Determine overall status
      const allHealthy = database.status === 'healthy' && 
                        solanaRpc.status === 'healthy' && 
                        openRouter.status === 'healthy';
      
      const anyUnhealthy = database.status === 'unhealthy' || 
                          solanaRpc.status === 'unhealthy' || 
                          openRouter.status === 'unhealthy';

      const overallStatus = allHealthy ? 'healthy' : anyUnhealthy ? 'unhealthy' : 'degraded';

      return {
        status: overallStatus,
        timestamp: new Date().toISOString(),
        uptime,
        version: '1.0.0',
        dependencies: {
          database,
          solanaRpc,
          openRouter,
        },
      };
    } catch (error) {
      logger.error('Error getting detailed health:', error);
      return {
        status: 'unhealthy',
        timestamp: new Date().toISOString(),
        uptime: 0,
        version: '1.0.0',
        dependencies: {
          database: {
            status: 'unhealthy',
            error: 'Failed to check database',
            lastChecked: new Date().toISOString(),
          },
          solanaRpc: {
            status: 'unhealthy',
            error: 'Failed to check Solana RPC',
            lastChecked: new Date().toISOString(),
          },
          openRouter: {
            status: 'unhealthy',
            error: 'Failed to check OpenRouter',
            lastChecked: new Date().toISOString(),
          },
        },
      };
    }
  }

  private async checkDatabase(): Promise<DependencyHealth> {
    const startTime = Date.now();
    try {
      // Simple query to check database connectivity
      const { error } = await supabase.from('users').select('id').limit(1);

      const responseTime = Date.now() - startTime;

      if (error) {
        logger.warn('Database health check failed:', error);
        return {
          status: 'unhealthy',
          responseTime,
          error: error.message,
          lastChecked: new Date().toISOString(),
        };
      }

      return {
        status: 'healthy',
        responseTime,
        lastChecked: new Date().toISOString(),
      };
    } catch (error) {
      const responseTime = Date.now() - startTime;
      logger.error('Database health check error:', error);
      return {
        status: 'unhealthy',
        responseTime,
        error: (error as Error).message,
        lastChecked: new Date().toISOString(),
      };
    }
  }

  private async checkSolanaRpc(): Promise<DependencyHealth> {
    const startTime = Date.now();
    try {
      const connection = new Connection(env.SOLANA_RPC_URL, 'confirmed');
      
      // Check if we can get the latest blockhash
      await Promise.race([
        connection.getLatestBlockhash(),
        new Promise((_, reject) => 
          setTimeout(() => reject(new Error('Timeout')), 5000)
        ),
      ]);

      const responseTime = Date.now() - startTime;

      return {
        status: 'healthy',
        responseTime,
        lastChecked: new Date().toISOString(),
      };
    } catch (error) {
      const responseTime = Date.now() - startTime;
      logger.warn('Solana RPC health check failed:', error);
      return {
        status: 'unhealthy',
        responseTime,
        error: (error as Error).message,
        lastChecked: new Date().toISOString(),
      };
    }
  }

  private async checkOpenRouter(): Promise<DependencyHealth> {
    const startTime = Date.now();
    try {
      // Simple check to OpenRouter API
      const response = await Promise.race([
        fetch(`${env.OPENROUTER_BASE_URL}/models`, {
          method: 'GET',
          headers: {
            Authorization: `Bearer ${env.OPENROUTER_API_KEY}`,
          },
        }),
        new Promise<Response>((_, reject) =>
          setTimeout(() => reject(new Error('Timeout')), 5000)
        ),
      ]);

      const responseTime = Date.now() - startTime;

      if (!response.ok) {
        return {
          status: 'unhealthy',
          responseTime,
          error: `HTTP ${response.status}`,
          lastChecked: new Date().toISOString(),
        };
      }

      return {
        status: 'healthy',
        responseTime,
        lastChecked: new Date().toISOString(),
      };
    } catch (error) {
      const responseTime = Date.now() - startTime;
      logger.warn('OpenRouter health check failed:', error);
      return {
        status: 'unhealthy',
        responseTime,
        error: (error as Error).message,
        lastChecked: new Date().toISOString(),
      };
    }
  }
}

export default new HealthService();
