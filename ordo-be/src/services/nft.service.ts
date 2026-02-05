/**
 * NFT Service
 * NFT operations: mint, transfer, burn, collections
 */

import { Connection, PublicKey, Keypair } from '@solana/web3.js';
import {
  getOrCreateAssociatedTokenAccount,
  transfer,
  burn,
} from '@solana/spl-token';
import { Metaplex, keypairIdentity } from '@metaplex-foundation/js';
import env from '../config/env';
import logger from '../config/logger';
import heliusService from './helius.service';
import supabase from '../config/database';
import { decryptPrivateKey } from '../utils/encryption';

const SOLANA_RPC_URL = env.SOLANA_RPC_URL;

interface MintNFTParams {
  name: string;
  symbol: string;
  uri: string;
  sellerFeeBasisPoints?: number;
  creators?: Array<{ address: string; share: number }>;
}

interface TransferNFTParams {
  mintAddress: string;
  toAddress: string;
}

interface NFTCollection {
  id: string;
  collection_address: string;
  name: string;
  symbol: string;
  description?: string;
  image?: string;
  floor_price_sol?: number;
  volume_24h_sol?: number;
  holder_count?: number;
  total_supply?: number;
  created_at: string;
  updated_at: string;
}

interface UserNFT {
  id: string;
  user_id: string;
  mint_address: string;
  collection_id?: string;
  name: string;
  symbol: string;
  image?: string;
  metadata_uri?: string;
  last_price_sol?: number;
  acquired_at: string;
  created_at: string;
}

export class NFTService {
  private connection: Connection;

  constructor() {
    this.connection = new Connection(SOLANA_RPC_URL, 'confirmed');
  }

  /**
   * Mint NFT
   */
  async mintNFT(
    userId: string,
    walletId: string,
    params: MintNFTParams
  ): Promise<{ signature: string; mintAddress: string }> {
    try {
      logger.info('Minting NFT', { userId, walletId, name: params.name });

      // Get wallet keypair
      const walletData = await supabase
        .from('wallets')
        .select('*')
        .eq('id', walletId)
        .eq('user_id', userId)
        .single();

      if (walletData.error || !walletData.data) {
        throw new Error('Wallet not found or unauthorized');
      }

      const wallet = walletData.data;
      const privateKeyString = decryptPrivateKey({
        ciphertext: wallet.encrypted_private_key,
        iv: wallet.encryption_iv,
        authTag: wallet.encryption_auth_tag,
      });
      const payer = Keypair.fromSecretKey(Buffer.from(privateKeyString, 'base64'));

      // Initialize Metaplex
      const metaplex = Metaplex.make(this.connection)
        .use(keypairIdentity(payer));

      // Create NFT
      const { nft } = await metaplex.nfts().create({
        uri: params.uri,
        name: params.name,
        symbol: params.symbol,
        sellerFeeBasisPoints: params.sellerFeeBasisPoints || 500, // 5%
        creators: params.creators
          ? params.creators.map((c: any) => ({
              address: new PublicKey(c.address),
              share: c.share,
            }))
          : [
              {
                address: payer.publicKey,
                share: 100,
              },
            ],
      });

      logger.info('NFT minted successfully', {
        mintAddress: nft.address.toString(),
        name: params.name,
      });

      // Store in database
      await this.storeUserNFT(userId, {
        mint_address: nft.address.toString(),
        name: params.name,
        symbol: params.symbol,
        image: nft.json?.image,
        metadata_uri: params.uri,
      });

      return {
        signature: nft.address.toString(), // Metaplex doesn't return signature directly
        mintAddress: nft.address.toString(),
      };
    } catch (error: any) {
      logger.error('Failed to mint NFT:', {
        message: error.message,
        userId,
        walletId,
      });
      throw new Error(`Failed to mint NFT: ${error.message}`);
    }
  }

  /**
   * Verify NFT ownership
   */
  async verifyNFTOwnership(walletAddress: string, mintAddress: string): Promise<boolean> {
    try {
      logger.info('Verifying NFT ownership', { walletAddress, mintAddress });

      const walletPublicKey = new PublicKey(walletAddress);
      const mintPublicKey = new PublicKey(mintAddress);

      // Get token account for this NFT
      const tokenAccounts = await this.connection.getTokenAccountsByOwner(
        walletPublicKey,
        { mint: mintPublicKey }
      );

      // Check if wallet has token account with balance > 0
      if (tokenAccounts.value.length === 0) {
        logger.warn('No token account found for NFT', { walletAddress, mintAddress });
        return false;
      }

      // Parse account data to check balance
      const accountInfo = tokenAccounts.value[0].account;
      const balance = Number(accountInfo.data.readBigUInt64LE(64)); // Token amount at offset 64

      if (balance === 0) {
        logger.warn('Token account has zero balance', { walletAddress, mintAddress });
        return false;
      }

      logger.info('NFT ownership verified', { walletAddress, mintAddress, balance });
      return true;
    } catch (error: any) {
      logger.error('Failed to verify NFT ownership:', error);
      return false;
    }
  }

  /**
   * Transfer NFT
   */
  async transferNFT(
    userId: string,
    walletId: string,
    params: TransferNFTParams
  ): Promise<{ signature: string }> {
    try {
      logger.info('Transferring NFT', { userId, walletId, mintAddress: params.mintAddress });

      // Get wallet keypair
      const walletData = await supabase
        .from('wallets')
        .select('*')
        .eq('id', walletId)
        .eq('user_id', userId)
        .single();

      if (walletData.error || !walletData.data) {
        throw new Error('Wallet not found or unauthorized');
      }

      const wallet = walletData.data;
      
      // VERIFY OWNERSHIP BEFORE TRANSFER
      const ownsNFT = await this.verifyNFTOwnership(wallet.public_key, params.mintAddress);
      
      if (!ownsNFT) {
        throw new Error('Unauthorized: Wallet does not own this NFT');
      }

      const privateKeyString = decryptPrivateKey({
        ciphertext: wallet.encrypted_private_key,
        iv: wallet.encryption_iv,
        authTag: wallet.encryption_auth_tag,
      });
      const fromKeypair = Keypair.fromSecretKey(Buffer.from(privateKeyString, 'base64'));

      const mintPublicKey = new PublicKey(params.mintAddress);
      const toPublicKey = new PublicKey(params.toAddress);

      // Get or create associated token accounts
      const fromTokenAccount = await getOrCreateAssociatedTokenAccount(
        this.connection,
        fromKeypair,
        mintPublicKey,
        fromKeypair.publicKey
      );

      const toTokenAccount = await getOrCreateAssociatedTokenAccount(
        this.connection,
        fromKeypair,
        mintPublicKey,
        toPublicKey
      );

      // Transfer NFT (amount = 1 for NFT)
      const signature = await transfer(
        this.connection,
        fromKeypair,
        fromTokenAccount.address,
        toTokenAccount.address,
        fromKeypair.publicKey,
        1
      );

      logger.info('NFT transferred successfully', {
        signature,
        mintAddress: params.mintAddress,
        to: params.toAddress,
      });

      // Remove from user's NFT list
      await this.removeUserNFT(userId, params.mintAddress);

      return { signature };
    } catch (error: any) {
      logger.error('Failed to transfer NFT:', {
        message: error.message,
        userId,
        walletId,
      });
      throw new Error(`Failed to transfer NFT: ${error.message}`);
    }
  }

  /**
   * Burn NFT
   */
  async burnNFT(
    userId: string,
    walletId: string,
    mintAddress: string
  ): Promise<{ signature: string }> {
    try {
      logger.info('Burning NFT', { userId, walletId, mintAddress });

      // Get wallet keypair
      const walletData = await supabase
        .from('wallets')
        .select('*')
        .eq('id', walletId)
        .eq('user_id', userId)
        .single();

      if (walletData.error || !walletData.data) {
        throw new Error('Wallet not found or unauthorized');
      }

      const wallet = walletData.data;
      
      // VERIFY OWNERSHIP BEFORE BURN
      const ownsNFT = await this.verifyNFTOwnership(wallet.public_key, mintAddress);
      
      if (!ownsNFT) {
        throw new Error('Unauthorized: Wallet does not own this NFT');
      }

      const privateKeyString = decryptPrivateKey({
        ciphertext: wallet.encrypted_private_key,
        iv: wallet.encryption_iv,
        authTag: wallet.encryption_auth_tag,
      });
      const ownerKeypair = Keypair.fromSecretKey(Buffer.from(privateKeyString, 'base64'));

      const mintPublicKey = new PublicKey(mintAddress);

      // Get associated token account
      const tokenAccount = await getOrCreateAssociatedTokenAccount(
        this.connection,
        ownerKeypair,
        mintPublicKey,
        ownerKeypair.publicKey
      );

      // Burn NFT (amount = 1 for NFT)
      const signature = await burn(
        this.connection,
        ownerKeypair,
        tokenAccount.address,
        mintPublicKey,
        ownerKeypair.publicKey,
        1
      );

      logger.info('NFT burned successfully', { signature, mintAddress });

      // Remove from user's NFT list
      await this.removeUserNFT(userId, mintAddress);

      return { signature };
    } catch (error: any) {
      logger.error('Failed to burn NFT:', {
        message: error.message,
        userId,
        walletId,
      });
      throw new Error(`Failed to burn NFT: ${error.message}`);
    }
  }

  /**
   * Get user's NFTs
   */
  async getUserNFTs(userId: string, limit: number = 100): Promise<UserNFT[]> {
    try {
      logger.info('Getting user NFTs', { userId, limit });

      const { data, error } = await supabase
        .from('user_nfts')
        .select('*')
        .eq('user_id', userId)
        .order('acquired_at', { ascending: false })
        .limit(limit);

      if (error) {
        throw error;
      }

      return data || [];
    } catch (error: any) {
      logger.error('Failed to get user NFTs:', {
        message: error.message,
        userId,
      });
      throw new Error(`Failed to get user NFTs: ${error.message}`);
    }
  }

  /**
   * Get NFTs by wallet address (using Helius)
   */
  async getNFTsByWallet(walletAddress: string, limit: number = 100): Promise<any[]> {
    try {
      logger.info('Getting NFTs by wallet', { walletAddress, limit });

      const nfts = await heliusService.getNFTsByOwner(walletAddress, limit);

      return nfts;
    } catch (error: any) {
      logger.error('Failed to get NFTs by wallet:', {
        message: error.message,
        walletAddress,
      });
      throw new Error(`Failed to get NFTs by wallet: ${error.message}`);
    }
  }

  /**
   * Get NFT metadata
   */
  async getNFTMetadata(mintAddress: string): Promise<any> {
    try {
      logger.info('Getting NFT metadata', { mintAddress });

      const metadata = await heliusService.getTokenMetadata(mintAddress);

      if (!metadata) {
        throw new Error('NFT metadata not found');
      }

      return metadata;
    } catch (error: any) {
      logger.error('Failed to get NFT metadata:', {
        message: error.message,
        mintAddress,
      });
      throw new Error(`Failed to get NFT metadata: ${error.message}`);
    }
  }

  /**
   * Get collection info
   */
  async getCollectionInfo(collectionAddress: string): Promise<NFTCollection | null> {
    try {
      logger.info('Getting collection info', { collectionAddress });

      const { data, error } = await supabase
        .from('nft_collections')
        .select('*')
        .eq('collection_address', collectionAddress)
        .single();

      if (error && error.code !== 'PGRST116') {
        throw error;
      }

      return data;
    } catch (error: any) {
      logger.error('Failed to get collection info:', {
        message: error.message,
        collectionAddress,
      });
      return null;
    }
  }

  /**
   * Get NFT portfolio value
   */
  async getPortfolioValue(userId: string): Promise<{ totalValue: number; nftCount: number }> {
    try {
      logger.info('Getting NFT portfolio value', { userId });

      const nfts = await this.getUserNFTs(userId);

      const totalValue = nfts.reduce((sum, nft) => {
        return sum + (nft.last_price_sol || 0);
      }, 0);

      return {
        totalValue,
        nftCount: nfts.length,
      };
    } catch (error: any) {
      logger.error('Failed to get portfolio value:', {
        message: error.message,
        userId,
      });
      throw new Error(`Failed to get portfolio value: ${error.message}`);
    }
  }

  /**
   * Store user NFT in database
   */
  private async storeUserNFT(
    userId: string,
    nftData: {
      mint_address: string;
      name: string;
      symbol: string;
      image?: string;
      metadata_uri?: string;
      collection_id?: string;
      last_price_sol?: number;
    }
  ): Promise<void> {
    try {
      const { error } = await supabase.from('user_nfts').insert({
        user_id: userId,
        mint_address: nftData.mint_address,
        collection_id: nftData.collection_id,
        name: nftData.name,
        symbol: nftData.symbol,
        image: nftData.image,
        metadata_uri: nftData.metadata_uri,
        last_price_sol: nftData.last_price_sol,
        acquired_at: new Date().toISOString(),
      });

      if (error) {
        throw error;
      }

      logger.info('User NFT stored in database', {
        userId,
        mintAddress: nftData.mint_address,
      });
    } catch (error: any) {
      logger.error('Failed to store user NFT:', {
        message: error.message,
        userId,
      });
      // Don't throw - this is not critical
    }
  }

  /**
   * Remove user NFT from database
   */
  private async removeUserNFT(userId: string, mintAddress: string): Promise<void> {
    try {
      const { error } = await supabase
        .from('user_nfts')
        .delete()
        .eq('user_id', userId)
        .eq('mint_address', mintAddress);

      if (error) {
        throw error;
      }

      logger.info('User NFT removed from database', { userId, mintAddress });
    } catch (error: any) {
      logger.error('Failed to remove user NFT:', {
        message: error.message,
        userId,
      });
      // Don't throw - this is not critical
    }
  }
}

export default new NFTService();
