import { Keypair, Connection, PublicKey, LAMPORTS_PER_SOL } from '@solana/web3.js';
import bs58 from 'bs58';
import { v4 as uuidv4 } from 'uuid';
import supabase from '../config/database';
import env from '../config/env';
import logger from '../config/logger';
import { encryptPrivateKey, decryptPrivateKey } from '../utils/encryption';
import { Wallet } from '../types';
import { retryWithBackoff } from '../utils/retry';
import realtimeService from './realtime.service';

export class WalletService {
  private connection: Connection;

  constructor() {
    this.connection = new Connection(env.SOLANA_RPC_URL, 'confirmed');
  }

  async createWallet(userId: string): Promise<Wallet> {
    try {
      // Generate new keypair
      const keypair = Keypair.generate();
      const publicKey = keypair.publicKey.toBase58();
      const privateKey = bs58.encode(keypair.secretKey);

      // Encrypt private key
      const encrypted = encryptPrivateKey(privateKey);

      // Check if user has any wallets
      const { data: existingWallets } = await supabase
        .from('wallets')
        .select('id')
        .eq('user_id', userId);

      const isPrimary = !existingWallets || existingWallets.length === 0;

      // Store wallet in database
      const walletId = uuidv4();
      const { data: wallet, error } = await supabase
        .from('wallets')
        .insert({
          id: walletId,
          user_id: userId,
          public_key: publicKey,
          encrypted_private_key: encrypted.ciphertext,
          encryption_iv: encrypted.iv,
          encryption_tag: encrypted.authTag,
          is_primary: isPrimary,
        })
        .select()
        .single();

      if (error) {
        logger.error('Failed to create wallet:', error);
        throw new Error('Failed to create wallet');
      }

      logger.info(`Wallet created for user ${userId}: ${publicKey}`);
      return wallet;
    } catch (error) {
      logger.error('Wallet creation error:', error);
      throw error;
    }
  }

  async importWallet(userId: string, privateKey: string): Promise<Wallet> {
    try {
      // Validate and parse private key
      let keypair: Keypair;
      try {
        const secretKey = bs58.decode(privateKey);
        keypair = Keypair.fromSecretKey(secretKey);
      } catch {
        throw new Error('Invalid private key format');
      }

      const publicKey = keypair.publicKey.toBase58();

      // Check if wallet already exists
      const { data: existingWallet } = await supabase
        .from('wallets')
        .select('id')
        .eq('public_key', publicKey)
        .single();

      if (existingWallet) {
        throw new Error('Wallet already imported');
      }

      // Encrypt private key
      const encrypted = encryptPrivateKey(privateKey);

      // Check if user has any wallets
      const { data: existingWallets } = await supabase
        .from('wallets')
        .select('id')
        .eq('user_id', userId);

      const isPrimary = !existingWallets || existingWallets.length === 0;

      // Store wallet in database
      const walletId = uuidv4();
      const { data: wallet, error } = await supabase
        .from('wallets')
        .insert({
          id: walletId,
          user_id: userId,
          public_key: publicKey,
          encrypted_private_key: encrypted.ciphertext,
          encryption_iv: encrypted.iv,
          encryption_tag: encrypted.authTag,
          is_primary: isPrimary,
        })
        .select()
        .single();

      if (error) {
        logger.error('Failed to import wallet:', error);
        throw new Error('Failed to import wallet');
      }

      logger.info(`Wallet imported for user ${userId}: ${publicKey}`);
      return wallet;
    } catch (error) {
      logger.error('Wallet import error:', error);
      throw error;
    }
  }

  async getWalletBalance(walletId: string): Promise<{ sol: number; tokens: any[] }> {
    try {
      // Get wallet from database
      const { data: wallet, error } = await supabase
        .from('wallets')
        .select('*')
        .eq('id', walletId)
        .single();

      if (error || !wallet) {
        throw new Error('Wallet not found');
      }

      const publicKey = new PublicKey(wallet.public_key);

      // Get SOL balance with retry and timeout
      logger.info(`Fetching balance for ${wallet.public_key}`);
      const solBalance = await retryWithBackoff(
        async () => Promise.race([
          this.connection.getBalance(publicKey),
          new Promise<number>((_, reject) => 
            setTimeout(() => reject(new Error('RPC timeout')), 10000)
          )
        ]),
        {
          maxRetries: 3,
          initialDelay: 1000,
          onRetry: (error, attempt) => {
            logger.warn('Retrying SOL balance query', {
              wallet: wallet.public_key,
              attempt,
              error: error.message,
            });
          },
        }
      );
      const sol = solBalance / LAMPORTS_PER_SOL;

      // Get token accounts with retry and timeout
      const tokenAccounts = await retryWithBackoff(
        async () => Promise.race([
          this.connection.getParsedTokenAccountsByOwner(publicKey, {
            programId: new PublicKey('TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA'),
          }),
          new Promise<any>((_, reject) => 
            setTimeout(() => reject(new Error('RPC timeout')), 10000)
          )
        ]),
        {
          maxRetries: 3,
          initialDelay: 1000,
          onRetry: (error, attempt) => {
            logger.warn('Retrying token accounts query', {
              wallet: wallet.public_key,
              attempt,
              error: error.message,
            });
          },
        }
      );

      const tokens = tokenAccounts.value.map((account: any) => {
        const info = account.account.data.parsed.info;
        return {
          mint: info.mint,
          amount: info.tokenAmount.uiAmount,
          decimals: info.tokenAmount.decimals,
        };
      });

      logger.info(`Balance fetched: ${sol} SOL, ${tokens.length} tokens`);
      return { sol, tokens };
    } catch (error: any) {
      logger.error('Balance query error:', error);
      if (error.message === 'RPC timeout') {
        throw new Error('RPC request timeout - please try again');
      }
      throw error;
    }
  }

  async getUserWallets(userId: string): Promise<Wallet[]> {
    try {
      const { data: wallets, error } = await supabase
        .from('wallets')
        .select('*')
        .eq('user_id', userId)
        .order('is_primary', { ascending: false })
        .order('created_at', { ascending: false });

      if (error) {
        logger.error('Failed to get user wallets:', error);
        throw new Error('Failed to get user wallets');
      }

      return wallets || [];
    } catch (error) {
      logger.error('Get user wallets error:', error);
      throw error;
    }
  }

  async getKeypair(walletId: string): Promise<Keypair> {
    try {
      const { data: wallet, error } = await supabase
        .from('wallets')
        .select('*')
        .eq('id', walletId)
        .single();

      if (error || !wallet) {
        throw new Error('Wallet not found');
      }

      // Decrypt private key
      const privateKey = decryptPrivateKey({
        ciphertext: wallet.encrypted_private_key,
        iv: wallet.encryption_iv,
        authTag: wallet.encryption_tag,
      });

      // Create keypair
      const secretKey = bs58.decode(privateKey);
      return Keypair.fromSecretKey(secretKey);
    } catch (error) {
      logger.error('Get keypair error:', error);
      throw error;
    }
  }

  /**
   * Get wallet balance and emit real-time update
   */
  async getWalletBalanceWithUpdate(
    userId: string,
    walletId: string
  ): Promise<{ sol: number; tokens: any[] }> {
    try {
      const balance = await this.getWalletBalance(walletId);

      // Emit real-time balance update
      realtimeService.emitBalanceChange(userId, {
        walletId,
        sol: balance.sol,
        tokens: balance.tokens,
        timestamp: new Date().toISOString(),
      });

      return balance;
    } catch (error) {
      logger.error('Get wallet balance with update error:', error);
      throw error;
    }
  }

  /**
   * Get portfolio summary for user (all wallets)
   */
  async getPortfolioSummary(userId: string): Promise<{
    totalSol: number;
    totalTokens: number;
    wallets: Array<{
      walletId: string;
      publicKey: string;
      sol: number;
      tokens: any[];
    }>;
  }> {
    try {
      const wallets = await this.getUserWallets(userId);
      
      let totalSol = 0;
      let totalTokens = 0;
      const walletsWithBalance = [];

      for (const wallet of wallets) {
        try {
          const balance = await this.getWalletBalance(wallet.id);
          totalSol += balance.sol;
          totalTokens += balance.tokens.length;

          walletsWithBalance.push({
            walletId: wallet.id,
            publicKey: wallet.public_key,
            sol: balance.sol,
            tokens: balance.tokens,
          });
        } catch (error) {
          logger.warn('Failed to get balance for wallet', {
            walletId: wallet.id,
            error,
          });
        }
      }

      const portfolio = {
        totalSol,
        totalTokens,
        wallets: walletsWithBalance,
      };

      // Emit real-time portfolio update
      realtimeService.emitPortfolioUpdate(userId, {
        ...portfolio,
        timestamp: new Date().toISOString(),
      });

      return portfolio;
    } catch (error) {
      logger.error('Get portfolio summary error:', error);
      throw error;
    }
  }

  /**
   * Delete a wallet for the user
   */
  async deleteWallet(userId: string, walletId: string): Promise<void> {
    try {
      // Verify wallet belongs to user
      const { data: wallet, error: walletError } = await supabase
        .from('wallets')
        .select('id, is_primary, public_key')
        .eq('id', walletId)
        .eq('user_id', userId)
        .single();

      if (walletError || !wallet) {
        throw new Error('Wallet not found or does not belong to user');
      }

      const wasPrimary = wallet.is_primary;
      const deletedPublicKey = wallet.public_key;

      // Delete the wallet
      const { error: deleteError } = await supabase
        .from('wallets')
        .delete()
        .eq('id', walletId)
        .eq('user_id', userId);

      if (deleteError) {
        logger.error('Failed to delete wallet:', deleteError);
        throw new Error('Failed to delete wallet');
      }

      // If the deleted wallet was primary, set another wallet as primary
      if (wasPrimary) {
        const { data: remainingWallets } = await supabase
          .from('wallets')
          .select('id')
          .eq('user_id', userId)
          .order('created_at', { ascending: false })
          .limit(1);

        if (remainingWallets && remainingWallets.length > 0) {
          await supabase
            .from('wallets')
            .update({ is_primary: true })
            .eq('id', remainingWallets[0].id);
          
          logger.info(`New primary wallet set after deletion: ${remainingWallets[0].id}`);
        }
      }

      logger.info(`Wallet deleted for user ${userId}: ${deletedPublicKey}`);
    } catch (error) {
      logger.error('Delete wallet error:', error);
      throw error;
    }
  }

  /**
   * Delete multiple wallets for the user (batch delete)
   */
  async deleteWallets(userId: string, walletIds: string[]): Promise<{ deleted: number; failed: string[] }> {
    const failed: string[] = [];
    let deleted = 0;

    for (const walletId of walletIds) {
      try {
        await this.deleteWallet(userId, walletId);
        deleted++;
      } catch (error: any) {
        logger.warn(`Failed to delete wallet ${walletId}:`, error.message);
        failed.push(walletId);
      }
    }

    return { deleted, failed };
  }

  /**
   * Set a wallet as the primary wallet for the user
   */
  async setPrimaryWallet(userId: string, walletId: string): Promise<void> {
    try {
      // Verify wallet belongs to user
      const { data: wallet, error: walletError } = await supabase
        .from('wallets')
        .select('id')
        .eq('id', walletId)
        .eq('user_id', userId)
        .single();

      if (walletError || !wallet) {
        throw new Error('Wallet not found or does not belong to user');
      }

      // First, set all user's wallets to non-primary
      const { error: updateError } = await supabase
        .from('wallets')
        .update({ is_primary: false })
        .eq('user_id', userId);

      if (updateError) {
        logger.error('Failed to reset primary wallets:', updateError);
        throw new Error('Failed to update wallet');
      }

      // Then set the specified wallet as primary
      const { error: setPrimaryError } = await supabase
        .from('wallets')
        .update({ is_primary: true })
        .eq('id', walletId);

      if (setPrimaryError) {
        logger.error('Failed to set primary wallet:', setPrimaryError);
        throw new Error('Failed to set primary wallet');
      }

      logger.info(`Primary wallet set for user ${userId}: ${walletId}`);
    } catch (error) {
      logger.error('Set primary wallet error:', error);
      throw error;
    }
  }
}

export default new WalletService();
