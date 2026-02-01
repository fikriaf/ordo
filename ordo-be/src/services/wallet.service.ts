import { Keypair, Connection, PublicKey, LAMPORTS_PER_SOL } from '@solana/web3.js';
import bs58 from 'bs58';
import { v4 as uuidv4 } from 'uuid';
import supabase from '../config/database';
import env from '../config/env';
import logger from '../config/logger';
import { encryptPrivateKey, decryptPrivateKey } from '../utils/encryption';
import { Wallet } from '../types';
import { retryWithBackoff } from '../utils/retry';

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
}

export default new WalletService();
