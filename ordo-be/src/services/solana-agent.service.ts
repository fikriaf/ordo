import logger from '../config/logger';
import walletService from './wallet.service';
import { Plugin, Action, ActionContext } from '../types/plugin';
import pluginManager from './plugin-manager.service';

class SolanaAgentService {
  constructor() {
    this.registerPlugins();
  }

  private registerPlugins() {
    // Register Token Operations Plugin
    const tokenPlugin: Plugin = {
      id: 'solana-token',
      name: 'Solana Token Operations',
      version: '1.0.0',
      description: 'Token operations: transfer, balance, swap',
      isEnabled: true,
      actions: this.getTokenActions(),
    };

    // Register Price Feed Plugin
    const pricePlugin: Plugin = {
      id: 'price-feed',
      name: 'Price Feed',
      version: '1.0.0',
      description: 'Real-time price feeds',
      isEnabled: true,
      actions: this.getPriceActions(),
    };

    pluginManager.registerPlugin(tokenPlugin);
    pluginManager.registerPlugin(pricePlugin);

    logger.info('Solana Agent plugins registered');
  }

  private getTokenActions(): Action[] {
    return [
      {
        name: 'get_balance',
        description: 'Get wallet balance (SOL and tokens)',
        parameters: [],
        handler: async (_params, context) => this.getBalance(context),
      },
    ];
  }

  private getPriceActions(): Action[] {
    return [
      {
        name: 'get_sol_price',
        description: 'Get current SOL price in USD',
        parameters: [],
        handler: async () => this.getSolPrice(),
      },
    ];
  }

  // Action Handlers
  private async getBalance(context: ActionContext): Promise<any> {
    if (!context.walletId) {
      throw new Error('Wallet ID required');
    }

    const balance = await walletService.getWalletBalance(context.walletId);
    
    return {
      success: true,
      sol: balance.sol,
      tokens: balance.tokens,
    };
  }

  private async getSolPrice(): Promise<any> {
    // Mock price for now - in production, integrate with Pyth or Jupiter
    return {
      success: true,
      symbol: 'SOL',
      price: 150.25,
      currency: 'USD',
      timestamp: new Date().toISOString(),
    };
  }
}

export default new SolanaAgentService();
