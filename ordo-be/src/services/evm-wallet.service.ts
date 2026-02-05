import { ethers } from 'ethers';
import supabase from '../config/database';
import { encrypt, decrypt } from '../utils/encryption';
import logger from '../config/logger';

export enum EVMChainId {
  ETHEREUM = 'ethereum',
  POLYGON = 'polygon',
  BSC = 'bsc',
  ARBITRUM = 'arbitrum',
  OPTIMISM = 'optimism',
  AVALANCHE = 'avalanche'
}

interface EVMWallet {
  id: string;
  userId: string;
  chainId: EVMChainId;
  address: string;
  encryptedPrivateKey: string;
  encryptionIv: string;
  encryptionAuthTag: string;
  isPrimary: boolean;
  createdAt: Date;
  updatedAt: Date;
}

interface EVMBalance {
  native: string; // in ether (ETH, MATIC, BNB, etc.)
  tokens: EVMTokenBalance[];
}

interface EVMTokenBalance {
  address: string;
  symbol: string;
  name: string;
  amount: string;
  decimals: number;
}

interface GasEstimate {
  gasLimit: string;
  gasPrice: string; // in wei
  estimatedFee: string; // in native token
  estimatedFeeUsd: number;
}

// RPC URLs for each chain
const RPC_URLS: Record<EVMChainId, string> = {
  [EVMChainId.ETHEREUM]: process.env.ETHEREUM_RPC_URL || 'https://eth.llamarpc.com',
  [EVMChainId.POLYGON]: process.env.POLYGON_RPC_URL || 'https://polygon-rpc.com',
  [EVMChainId.BSC]: process.env.BSC_RPC_URL || 'https://bsc-dataseed.binance.org',
  [EVMChainId.ARBITRUM]: process.env.ARBITRUM_RPC_URL || 'https://arb1.arbitrum.io/rpc',
  [EVMChainId.OPTIMISM]: process.env.OPTIMISM_RPC_URL || 'https://mainnet.optimism.io',
  [EVMChainId.AVALANCHE]: process.env.AVALANCHE_RPC_URL || 'https://api.avax.network/ext/bc/C/rpc'
};

// Chain IDs for each network (for future use)
// const CHAIN_IDS: Record<EVMChainId, number> = {
//   [EVMChainId.ETHEREUM]: 1,
//   [EVMChainId.POLYGON]: 137,
//   [EVMChainId.BSC]: 56,
//   [EVMChainId.ARBITRUM]: 42161,
//   [EVMChainId.OPTIMISM]: 10,
//   [EVMChainId.AVALANCHE]: 43114
// };

// Native token symbols (for future use)
// const NATIVE_SYMBOLS: Record<EVMChainId, string> = {
//   [EVMChainId.ETHEREUM]: 'ETH',
//   [EVMChainId.POLYGON]: 'MATIC',
//   [EVMChainId.BSC]: 'BNB',
//   [EVMChainId.ARBITRUM]: 'ETH',
//   [EVMChainId.OPTIMISM]: 'ETH',
//   [EVMChainId.AVALANCHE]: 'AVAX'
// };

// ERC-20 ABI (minimal for balance and transfer)
const ERC20_ABI = [
  'function balanceOf(address owner) view returns (uint256)',
  'function decimals() view returns (uint8)',
  'function symbol() view returns (string)',
  'function name() view returns (string)',
  'function transfer(address to, uint256 amount) returns (bool)'
];

class EVMWalletService {
  /**
   * Get provider for a specific chain
   */
  private getProvider(chainId: EVMChainId): ethers.JsonRpcProvider {
    const rpcUrl = RPC_URLS[chainId];
    return new ethers.JsonRpcProvider(rpcUrl);
  }

  /**
   * Create a new EVM wallet
   */
  async createWallet(userId: string, chainId: EVMChainId): Promise<EVMWallet> {
    try {
      // Generate new random wallet
      const wallet = ethers.Wallet.createRandom();
      const privateKey = wallet.privateKey;
      const address = wallet.address;

      // Encrypt private key
      const { ciphertext, iv, authTag } = encrypt(privateKey);

      // Check if this is the first wallet for this chain
      const { data: existingWallets } = await supabase
        .from('evm_wallets')
        .select('id')
        .eq('user_id', userId)
        .eq('chain_id', chainId);

      const isPrimary = !existingWallets || existingWallets.length === 0;

      // Store in database
      const { data, error } = await supabase
        .from('evm_wallets')
        .insert({
          user_id: userId,
          chain_id: chainId,
          address: address,
          encrypted_private_key: ciphertext,
          encryption_iv: iv,
          encryption_auth_tag: authTag,
          is_primary: isPrimary
        })
        .select()
        .single();

      if (error) {
        logger.error('Failed to create EVM wallet', { error, userId, chainId });
        throw new Error('Failed to create EVM wallet');
      }

      logger.info('EVM wallet created', { userId, chainId, address });

      return {
        id: data.id,
        userId: data.user_id,
        chainId: data.chain_id as EVMChainId,
        address: data.address,
        encryptedPrivateKey: data.encrypted_private_key,
        encryptionIv: data.encryption_iv,
        encryptionAuthTag: data.encryption_auth_tag,
        isPrimary: data.is_primary,
        createdAt: new Date(data.created_at),
        updatedAt: new Date(data.updated_at)
      };
    } catch (error) {
      logger.error('Error creating EVM wallet', { error, userId, chainId });
      throw error;
    }
  }

  /**
   * Import an existing EVM wallet
   */
  async importWallet(userId: string, chainId: EVMChainId, privateKey: string): Promise<EVMWallet> {
    try {
      // Validate private key format
      if (!privateKey.startsWith('0x')) {
        privateKey = '0x' + privateKey;
      }

      // Create wallet from private key to validate and get address
      const wallet = new ethers.Wallet(privateKey);
      const address = wallet.address;

      // Check if wallet already exists
      const { data: existing } = await supabase
        .from('evm_wallets')
        .select('id')
        .eq('user_id', userId)
        .eq('address', address)
        .single();

      if (existing) {
        throw new Error('Wallet already imported');
      }

      // Encrypt private key
      const { ciphertext, iv, authTag } = encrypt(privateKey);

      // Check if this is the first wallet for this chain
      const { data: existingWallets } = await supabase
        .from('evm_wallets')
        .select('id')
        .eq('user_id', userId)
        .eq('chain_id', chainId);

      const isPrimary = !existingWallets || existingWallets.length === 0;

      // Store in database
      const { data, error } = await supabase
        .from('evm_wallets')
        .insert({
          user_id: userId,
          chain_id: chainId,
          address: address,
          encrypted_private_key: ciphertext,
          encryption_iv: iv,
          encryption_auth_tag: authTag,
          is_primary: isPrimary
        })
        .select()
        .single();

      if (error) {
        logger.error('Failed to import EVM wallet', { error, userId, chainId });
        throw new Error('Failed to import EVM wallet');
      }

      logger.info('EVM wallet imported', { userId, chainId, address });

      return {
        id: data.id,
        userId: data.user_id,
        chainId: data.chain_id as EVMChainId,
        address: data.address,
        encryptedPrivateKey: data.encrypted_private_key,
        encryptionIv: data.encryption_iv,
        encryptionAuthTag: data.encryption_auth_tag,
        isPrimary: data.is_primary,
        createdAt: new Date(data.created_at),
        updatedAt: new Date(data.updated_at)
      };
    } catch (error) {
      logger.error('Error importing EVM wallet', { error, userId, chainId });
      throw error;
    }
  }

  /**
   * Get wallet by ID
   */
  async getWallet(walletId: string): Promise<EVMWallet | null> {
    try {
      const { data, error } = await supabase
        .from('evm_wallets')
        .select('*')
        .eq('id', walletId)
        .single();

      if (error || !data) {
        return null;
      }

      return {
        id: data.id,
        userId: data.user_id,
        chainId: data.chain_id as EVMChainId,
        address: data.address,
        encryptedPrivateKey: data.encrypted_private_key,
        encryptionIv: data.encryption_iv,
        encryptionAuthTag: data.encryption_auth_tag,
        isPrimary: data.is_primary,
        createdAt: new Date(data.created_at),
        updatedAt: new Date(data.updated_at)
      };
    } catch (error) {
      logger.error('Error getting EVM wallet', { error, walletId });
      throw error;
    }
  }

  /**
   * Get user's wallets for a specific chain
   */
  async getUserWallets(userId: string, chainId?: EVMChainId): Promise<EVMWallet[]> {
    try {
      let query = supabase
        .from('evm_wallets')
        .select('*')
        .eq('user_id', userId);

      if (chainId) {
        query = query.eq('chain_id', chainId);
      }

      const { data, error } = await query.order('is_primary', { ascending: false }).order('created_at', { ascending: false });

      if (error) {
        logger.error('Failed to get user EVM wallets', { error, userId });
        throw new Error('Failed to get user EVM wallets');
      }

      return (data || []).map(w => ({
        id: w.id,
        userId: w.user_id,
        chainId: w.chain_id as EVMChainId,
        address: w.address,
        encryptedPrivateKey: w.encrypted_private_key,
        encryptionIv: w.encryption_iv,
        encryptionAuthTag: w.encryption_auth_tag,
        isPrimary: w.is_primary,
        createdAt: new Date(w.created_at),
        updatedAt: new Date(w.updated_at)
      }));
    } catch (error) {
      logger.error('Error getting user EVM wallets', { error, userId });
      throw error;
    }
  }

  /**
   * Get wallet balance (native + ERC-20 tokens)
   */
  async getWalletBalance(walletId: string): Promise<EVMBalance> {
    try {
      const wallet = await this.getWallet(walletId);
      if (!wallet) {
        throw new Error('Wallet not found');
      }

      const provider = this.getProvider(wallet.chainId);

      // Get native balance
      const nativeBalance = await provider.getBalance(wallet.address);
      const nativeBalanceEther = ethers.formatEther(nativeBalance);

      // TODO: Get ERC-20 token balances
      // This would require tracking which tokens to check or using a service like Alchemy/Moralis
      const tokens: EVMTokenBalance[] = [];

      logger.info('EVM wallet balance retrieved', { walletId, address: wallet.address, balance: nativeBalanceEther });

      return {
        native: nativeBalanceEther,
        tokens
      };
    } catch (error) {
      logger.error('Error getting EVM wallet balance', { error, walletId });
      throw error;
    }
  }

  /**
   * Decrypt and get wallet instance
   */
  private async getWalletInstance(walletId: string): Promise<ethers.Wallet> {
    const wallet = await this.getWallet(walletId);
    if (!wallet) {
      throw new Error('Wallet not found');
    }

    // Decrypt private key
    const privateKey = decrypt({
      ciphertext: wallet.encryptedPrivateKey,
      iv: wallet.encryptionIv,
      authTag: wallet.encryptionAuthTag
    });

    // Create wallet instance
    const provider = this.getProvider(wallet.chainId);
    return new ethers.Wallet(privateKey, provider);
  }

  /**
   * Transfer native token (ETH, MATIC, BNB, etc.)
   */
  async transferNative(walletId: string, toAddress: string, amount: string): Promise<string> {
    try {
      const walletInstance = await this.getWalletInstance(walletId);

      // Validate recipient address
      if (!ethers.isAddress(toAddress)) {
        throw new Error('Invalid recipient address');
      }

      // Convert amount to wei
      const amountWei = ethers.parseEther(amount);

      // Send transaction
      const tx = await walletInstance.sendTransaction({
        to: toAddress,
        value: amountWei
      });

      logger.info('Native token transfer initiated', { 
        walletId, 
        to: toAddress, 
        amount, 
        txHash: tx.hash 
      });

      // Wait for confirmation
      await tx.wait();

      logger.info('Native token transfer confirmed', { txHash: tx.hash });

      return tx.hash;
    } catch (error) {
      logger.error('Error transferring native token', { error, walletId, toAddress, amount });
      throw error;
    }
  }

  /**
   * Transfer ERC-20 token
   */
  async transferToken(
    walletId: string, 
    toAddress: string, 
    tokenAddress: string, 
    amount: string
  ): Promise<string> {
    try {
      const walletInstance = await this.getWalletInstance(walletId);

      // Validate addresses
      if (!ethers.isAddress(toAddress)) {
        throw new Error('Invalid recipient address');
      }
      if (!ethers.isAddress(tokenAddress)) {
        throw new Error('Invalid token address');
      }

      // Create contract instance
      const tokenContract = new ethers.Contract(tokenAddress, ERC20_ABI, walletInstance);

      // Get token decimals
      const decimals = await tokenContract.decimals();

      // Convert amount to token units
      const amountUnits = ethers.parseUnits(amount, decimals);

      // Send transaction
      const tx = await tokenContract.transfer(toAddress, amountUnits);

      logger.info('Token transfer initiated', { 
        walletId, 
        tokenAddress,
        to: toAddress, 
        amount, 
        txHash: tx.hash 
      });

      // Wait for confirmation
      await tx.wait();

      logger.info('Token transfer confirmed', { txHash: tx.hash });

      return tx.hash;
    } catch (error) {
      logger.error('Error transferring token', { error, walletId, toAddress, tokenAddress, amount });
      throw error;
    }
  }

  /**
   * Estimate gas for a transaction
   */
  async estimateGas(
    chainId: EVMChainId, 
    type: 'native' | 'token',
    _tokenAddress?: string
  ): Promise<GasEstimate> {
    try {
      const provider = this.getProvider(chainId);

      // Get current gas price
      const feeData = await provider.getFeeData();
      const gasPrice = feeData.gasPrice || ethers.parseUnits('20', 'gwei');

      // Estimate gas limit based on transaction type
      let gasLimit: bigint;
      if (type === 'native') {
        gasLimit = BigInt(21000); // Standard ETH transfer
      } else {
        gasLimit = BigInt(65000); // ERC-20 transfer
      }

      // Calculate estimated fee
      const estimatedFee = gasLimit * gasPrice;
      const estimatedFeeEther = ethers.formatEther(estimatedFee);

      // TODO: Get USD price for more accurate fee estimation
      const estimatedFeeUsd = 0;

      return {
        gasLimit: gasLimit.toString(),
        gasPrice: gasPrice.toString(),
        estimatedFee: estimatedFeeEther,
        estimatedFeeUsd
      };
    } catch (error) {
      logger.error('Error estimating gas', { error, chainId, type });
      throw error;
    }
  }
}

export default new EVMWalletService();
