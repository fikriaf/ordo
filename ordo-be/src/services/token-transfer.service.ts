/**
 * Token Transfer Service
 * Handles SOL and SPL token transfers with approval checks
 */

import { Connection, PublicKey, Transaction, SystemProgram, LAMPORTS_PER_SOL } from '@solana/web3.js';
import { getAssociatedTokenAddress, createTransferInstruction, TOKEN_PROGRAM_ID } from '@solana/spl-token';
import env from '../config/env';
import logger from '../config/logger';
import walletService from './wallet.service';
import transactionService from './transaction.service';
import userPreferencesService from './user-preferences.service';
import approvalService from './approval.service';

export class TokenTransferService {
  private connection: Connection;

  constructor() {
    this.connection = new Connection(env.SOLANA_RPC_URL, 'confirmed');
  }

  /**
   * Transfer SOL with approval check
   */
  async transferSOLWithApproval(
    userId: string,
    walletId: string,
    toAddress: string,
    amount: number,
    solPriceUsd: number = 150 // Default SOL price, should be fetched from price service
  ): Promise<{ signature?: string; amount?: number; approval_required?: boolean; approval_id?: string; message?: string }> {
    try {
      // Calculate USD value
      const amountUsdc = amount * solPriceUsd;

      // Check if approval is required
      const approvalCheck = await userPreferencesService.checkTransactionApprovalRequired(
        userId,
        amountUsdc
      );

      if (approvalCheck.required) {
        // Create approval request
        const approval = await approvalService.createApprovalRequest(
          userId,
          'large_transfer',
          {
            action: 'transfer_sol',
            walletId,
            toAddress,
            amount,
            amountUsdc,
          },
          {
            estimatedUsdValue: amountUsdc,
            agentReasoning: approvalCheck.reason,
            alternativeOptions: this.generateTransferAlternatives(amount, amountUsdc),
          }
        );

        logger.info('Transfer requires approval', { userId, approvalId: approval.id });

        return {
          approval_required: true,
          approval_id: approval.id,
          message: `Transfer requires your approval: ${approvalCheck.reason}`,
        };
      }

      // Check daily volume limit
      const volumeCheck = await userPreferencesService.checkDailyVolumeLimit(userId, amountUsdc);
      if (!volumeCheck.allowed) {
        // Create approval request for volume limit
        const approval = await approvalService.createApprovalRequest(
          userId,
          'large_transfer',
          {
            action: 'transfer_sol',
            walletId,
            toAddress,
            amount,
            amountUsdc,
          },
          {
            estimatedUsdValue: amountUsdc,
            agentReasoning: volumeCheck.reason,
            limitingFactors: { daily_volume_exceeded: true },
          }
        );

        return {
          approval_required: true,
          approval_id: approval.id,
          message: volumeCheck.reason,
        };
      }

      // Execute transfer
      const result = await this.transferSOL(userId, walletId, toAddress, amount);

      return {
        signature: result.signature,
        amount: result.amount,
        message: 'Transfer successful',
      };
    } catch (error: any) {
      logger.error('Transfer with approval check failed:', error);
      throw error;
    }
  }

  /**
   * Transfer SPL token with approval check
   */
  async transferTokenWithApproval(
    userId: string,
    walletId: string,
    toAddress: string,
    tokenMint: string,
    amount: number,
    decimals: number = 9,
    tokenPriceUsd: number = 1, // Should be fetched from price service
    tokenRiskScore?: number
  ): Promise<{ signature?: string; amount?: number; approval_required?: boolean; approval_id?: string; message?: string }> {
    try {
      // Calculate USD value
      const amountUsdc = amount * tokenPriceUsd;

      // Check if approval is required (including risk score)
      const approvalCheck = await userPreferencesService.checkTransactionApprovalRequired(
        userId,
        amountUsdc,
        tokenRiskScore
      );

      if (approvalCheck.required) {
        // Create approval request
        const requestType = tokenRiskScore && tokenRiskScore > 70 ? 'high_risk_token' : 'large_transfer';
        
        const approval = await approvalService.createApprovalRequest(
          userId,
          requestType,
          {
            action: 'transfer_token',
            walletId,
            toAddress,
            tokenMint,
            amount,
            decimals,
            amountUsdc,
          },
          {
            estimatedUsdValue: amountUsdc,
            estimatedRiskScore: tokenRiskScore,
            agentReasoning: approvalCheck.reason,
            alternativeOptions: this.generateTransferAlternatives(amount, amountUsdc),
          }
        );

        logger.info('Token transfer requires approval', { userId, approvalId: approval.id });

        return {
          approval_required: true,
          approval_id: approval.id,
          message: `Transfer requires your approval: ${approvalCheck.reason}`,
        };
      }

      // Check daily volume limit
      const volumeCheck = await userPreferencesService.checkDailyVolumeLimit(userId, amountUsdc);
      if (!volumeCheck.allowed) {
        const approval = await approvalService.createApprovalRequest(
          userId,
          'large_transfer',
          {
            action: 'transfer_token',
            walletId,
            toAddress,
            tokenMint,
            amount,
            decimals,
            amountUsdc,
          },
          {
            estimatedUsdValue: amountUsdc,
            agentReasoning: volumeCheck.reason,
            limitingFactors: { daily_volume_exceeded: true },
          }
        );

        return {
          approval_required: true,
          approval_id: approval.id,
          message: volumeCheck.reason,
        };
      }

      // Execute transfer
      const result = await this.transferToken(userId, walletId, toAddress, tokenMint, amount, decimals);

      return {
        signature: result.signature,
        amount: result.amount,
        message: 'Transfer successful',
      };
    } catch (error: any) {
      logger.error('Token transfer with approval check failed:', error);
      throw error;
    }
  }

  /**
   * Generate alternative transfer options
   */
  private generateTransferAlternatives(amount: number, amountUsdc: number): any[] {
    const alternatives = [];

    // Suggest splitting into smaller transfers
    if (amount > 1) {
      const splitCount = Math.ceil(amount / 0.5); // Split into 0.5 unit chunks
      alternatives.push({
        option: 'split_transfer',
        description: `Split into ${splitCount} smaller transfers of ~${(amount / splitCount).toFixed(2)} each`,
        risk_reduction: 'Each transfer below approval threshold',
      });
    }

    // Suggest reducing amount
    if (amountUsdc > 100) {
      const reducedAmount = amount * 0.5;
      alternatives.push({
        option: 'reduce_amount',
        description: `Transfer ${reducedAmount.toFixed(2)} instead of ${amount.toFixed(2)}`,
        risk_reduction: 'Lower transaction value',
      });
    }

    // Suggest waiting
    alternatives.push({
      option: 'wait_24h',
      description: 'Wait 24 hours for daily volume limit to reset',
      risk_reduction: 'Spread transactions over time',
    });

    return alternatives;
  }

  /**
   * Transfer SOL to another address
   */
  async transferSOL(
    userId: string,
    walletId: string,
    toAddress: string,
    amount: number
  ): Promise<{ signature: string; amount: number }> {
    try {
      logger.info('Transferring SOL', { userId, walletId, toAddress, amount });

      // Get wallet keypair
      const keypair = await walletService.getKeypair(walletId);
      const fromPubkey = keypair.publicKey;
      const toPubkey = new PublicKey(toAddress);

      // Convert SOL to lamports
      const lamports = Math.floor(amount * LAMPORTS_PER_SOL);

      // Create transaction
      const transaction = new Transaction().add(
        SystemProgram.transfer({
          fromPubkey,
          toPubkey,
          lamports,
        })
      );

      // Get recent blockhash
      const { blockhash } = await this.connection.getLatestBlockhash();
      transaction.recentBlockhash = blockhash;
      transaction.feePayer = fromPubkey;

      // Sign transaction
      transaction.sign(keypair);

      // Send transaction
      const signature = await this.connection.sendRawTransaction(
        transaction.serialize(),
        { skipPreflight: false }
      );

      // Confirm transaction
      await this.connection.confirmTransaction({
        signature,
        blockhash,
        lastValidBlockHeight: (await this.connection.getLatestBlockhash()).lastValidBlockHeight,
      });

      // Record transaction
      await transactionService.recordTransaction(
        userId,
        walletId,
        'transfer_sol',
        signature,
        {
          from: fromPubkey.toBase58(),
          to: toAddress,
          amount,
          token: 'SOL',
        }
      );

      logger.info('SOL transfer successful', { signature, amount });

      return {
        signature,
        amount,
      };
    } catch (error: any) {
      logger.error('SOL transfer failed:', error);
      throw new Error(`Failed to transfer SOL: ${error.message}`);
    }
  }

  /**
   * Transfer SPL token to another address
   */
  async transferToken(
    userId: string,
    walletId: string,
    toAddress: string,
    tokenMint: string,
    amount: number,
    decimals: number = 9
  ): Promise<{ signature: string; amount: number }> {
    try {
      logger.info('Transferring SPL token', {
        userId,
        walletId,
        toAddress,
        tokenMint,
        amount,
      });

      // Get wallet keypair
      const keypair = await walletService.getKeypair(walletId);
      const fromPubkey = keypair.publicKey;
      const toPubkey = new PublicKey(toAddress);
      const mintPubkey = new PublicKey(tokenMint);

      // Get associated token accounts
      const fromTokenAccount = await getAssociatedTokenAddress(
        mintPubkey,
        fromPubkey
      );

      const toTokenAccount = await getAssociatedTokenAddress(
        mintPubkey,
        toPubkey
      );

      // Convert amount to token units
      const tokenAmount = Math.floor(amount * Math.pow(10, decimals));

      // Create transaction
      const transaction = new Transaction().add(
        createTransferInstruction(
          fromTokenAccount,
          toTokenAccount,
          fromPubkey,
          tokenAmount,
          [],
          TOKEN_PROGRAM_ID
        )
      );

      // Get recent blockhash
      const { blockhash } = await this.connection.getLatestBlockhash();
      transaction.recentBlockhash = blockhash;
      transaction.feePayer = fromPubkey;

      // Sign transaction
      transaction.sign(keypair);

      // Send transaction
      const signature = await this.connection.sendRawTransaction(
        transaction.serialize(),
        { skipPreflight: false }
      );

      // Confirm transaction
      await this.connection.confirmTransaction({
        signature,
        blockhash,
        lastValidBlockHeight: (await this.connection.getLatestBlockhash()).lastValidBlockHeight,
      });

      // Record transaction
      await transactionService.recordTransaction(
        userId,
        walletId,
        'transfer_token',
        signature,
        {
          from: fromPubkey.toBase58(),
          to: toAddress,
          amount,
          tokenMint,
          decimals,
        }
      );

      logger.info('Token transfer successful', { signature, amount });

      return {
        signature,
        amount,
      };
    } catch (error: any) {
      logger.error('Token transfer failed:', error);
      throw new Error(`Failed to transfer token: ${error.message}`);
    }
  }

  /**
   * Estimate transfer fee
   */
  async estimateTransferFee(
    tokenMint?: string
  ): Promise<{ fee: number; feeInSOL: number }> {
    try {
      // Base fee for transaction (5000 lamports is typical)
      const baseFee = 5000; // lamports
      
      // Additional fee for token transfer (creating ATA if needed)
      const tokenFee = tokenMint ? 2039280 : 0; // lamports for ATA creation

      const totalFee = baseFee + tokenFee;
      const feeInSOL = totalFee / LAMPORTS_PER_SOL;

      return {
        fee: totalFee,
        feeInSOL,
      };
    } catch (error: any) {
      logger.error('Fee estimation failed:', error);
      throw new Error(`Failed to estimate fee: ${error.message}`);
    }
  }

  /**
   * Validate transfer parameters
   */
  async validateTransfer(
    walletId: string,
    _userId: string,
    amount: number,
    tokenMint?: string
  ): Promise<{ valid: boolean; error?: string }> {
    try {
      // Check if amount is positive
      if (amount <= 0) {
        return { valid: false, error: 'Amount must be greater than 0' };
      }

      // Get wallet balance
      const balance = await walletService.getWalletBalance(walletId);

      if (tokenMint) {
        // Check token balance
        const token = balance.tokens?.find((t: any) => t.mint === tokenMint);
        if (!token || token.amount < amount) {
          return { valid: false, error: 'Insufficient token balance' };
        }
      } else {
        // Check SOL balance
        if (balance.sol < amount) {
          return { valid: false, error: 'Insufficient SOL balance' };
        }

        // Check if enough SOL for fee
        const { feeInSOL } = await this.estimateTransferFee();
        if (balance.sol < amount + feeInSOL) {
          return {
            valid: false,
            error: `Insufficient SOL for transfer + fee (need ${feeInSOL} SOL for fee)`,
          };
        }
      }

      return { valid: true };
    } catch (error: any) {
      logger.error('Transfer validation failed:', error);
      return { valid: false, error: error.message };
    }
  }
}

export default new TokenTransferService();
