/**
 * Jupiter Swap Service
 * Handles token swaps via Jupiter aggregator
 */

import axios from 'axios';
import { Connection, VersionedTransaction } from '@solana/web3.js';
import env from '../config/env';
import logger from '../config/logger';
import walletService from './wallet.service';
import transactionService from './transaction.service';
import userPreferencesService from './user-preferences.service';
import approvalService from './approval.service';

const JUPITER_API_URL = 'https://quote-api.jup.ag/v6';

interface SwapQuoteParams {
  inputMint: string;
  outputMint: string;
  amount: number;
  slippageBps?: number;
}

interface SwapExecuteParams {
  userId: string;
  walletId: string;
  quoteResponse: any;
}

export class JupiterService {
  private connection: Connection;

  constructor() {
    this.connection = new Connection(env.SOLANA_RPC_URL, 'confirmed');
  }

  /**
   * Get swap quote from Jupiter
   */
  async getSwapQuote(params: SwapQuoteParams): Promise<any> {
    try {
      const { inputMint, outputMint, amount, slippageBps = 50 } = params;

      logger.info('Getting Jupiter swap quote', {
        inputMint,
        outputMint,
        amount,
        slippageBps,
      });

      // Convert amount to lamports/token units (assuming 9 decimals for now)
      const amountInSmallestUnit = Math.floor(amount * Math.pow(10, 9));

      const response = await axios.get(`${JUPITER_API_URL}/quote`, {
        params: {
          inputMint,
          outputMint,
          amount: amountInSmallestUnit,
          slippageBps,
          onlyDirectRoutes: false,
          asLegacyTransaction: false,
        },
      });

      const quote = response.data;

      // Calculate human-readable amounts
      const inputAmount = parseInt(quote.inAmount) / Math.pow(10, 9);
      const outputAmount = parseInt(quote.outAmount) / Math.pow(10, 9);
      const priceImpact = parseFloat(quote.priceImpactPct);

      logger.info('Jupiter quote received', {
        inputAmount,
        outputAmount,
        priceImpact,
      });

      return {
        quote,
        inputAmount,
        outputAmount,
        priceImpact,
        route: quote.routePlan,
      };
    } catch (error: any) {
      logger.error('Failed to get Jupiter quote:', {
        message: error.message,
        status: error.response?.status,
        data: error.response?.data,
      });
      
      const errorMessage = error.response?.data?.error || error.message || 'Unknown error';
      throw new Error(`Failed to get swap quote: ${errorMessage}`);
    }
  }

  /**
   * Execute swap with approval check
   */
  async executeSwapWithApproval(
    userId: string,
    walletId: string,
    quoteResponse: any,
    inputTokenPriceUsd: number = 1,
    outputTokenPriceUsd: number = 1,
    tokenRiskScore?: number
  ): Promise<{ signature?: string; approval_required?: boolean; approval_id?: string; message?: string }> {
    try {
      // Calculate USD values
      const inputAmount = parseInt(quoteResponse.inAmount) / Math.pow(10, 9);
      const outputAmount = parseInt(quoteResponse.outAmount) / Math.pow(10, 9);
      const inputAmountUsdc = inputAmount * inputTokenPriceUsd;
      const outputAmountUsdc = outputAmount * outputTokenPriceUsd;
      const priceImpact = parseFloat(quoteResponse.priceImpactPct || '0');

      // Check if approval is required (based on output value)
      const approvalCheck = await userPreferencesService.checkTransactionApprovalRequired(
        userId,
        outputAmountUsdc,
        tokenRiskScore
      );

      if (approvalCheck.required) {
        // Create approval request
        const requestType = tokenRiskScore && tokenRiskScore > 70 ? 'high_risk_token' : 'large_transfer';
        
        const approval = await approvalService.createApprovalRequest(
          userId,
          requestType,
          {
            action: 'swap',
            walletId,
            quoteResponse,
            inputAmount,
            outputAmount,
            inputAmountUsdc,
            outputAmountUsdc,
            priceImpact,
          },
          {
            estimatedUsdValue: outputAmountUsdc,
            estimatedRiskScore: tokenRiskScore,
            agentReasoning: approvalCheck.reason,
            alternativeOptions: this.generateSwapAlternatives(inputAmount, outputAmount, priceImpact),
          }
        );

        logger.info('Swap requires approval', { userId, approvalId: approval.id });

        return {
          approval_required: true,
          approval_id: approval.id,
          message: `Swap requires your approval: ${approvalCheck.reason}`,
        };
      }

      // Check daily volume limit
      const volumeCheck = await userPreferencesService.checkDailyVolumeLimit(userId, outputAmountUsdc);
      if (!volumeCheck.allowed) {
        const approval = await approvalService.createApprovalRequest(
          userId,
          'large_transfer',
          {
            action: 'swap',
            walletId,
            quoteResponse,
            inputAmount,
            outputAmount,
            inputAmountUsdc,
            outputAmountUsdc,
            priceImpact,
          },
          {
            estimatedUsdValue: outputAmountUsdc,
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

      // Execute swap
      const result = await this.executeSwap({
        userId,
        walletId,
        quoteResponse,
      });

      return {
        signature: result.signature,
        message: 'Swap executed successfully',
      };
    } catch (error: any) {
      logger.error('Swap with approval check failed:', error);
      throw error;
    }
  }

  /**
   * Generate alternative swap options
   */
  private generateSwapAlternatives(inputAmount: number, _outputAmount: number, priceImpact: number): any[] {
    const alternatives = [];

    // Suggest reducing amount if price impact is high
    if (priceImpact > 1) {
      const reducedAmount = inputAmount * 0.5;
      alternatives.push({
        option: 'reduce_amount',
        description: `Swap ${reducedAmount.toFixed(2)} instead of ${inputAmount.toFixed(2)} to reduce price impact`,
        risk_reduction: `Lower price impact (estimated ${(priceImpact * 0.5).toFixed(2)}%)`,
      });
    }

    // Suggest splitting into multiple swaps
    if (inputAmount > 1) {
      const splitCount = Math.ceil(inputAmount / 0.5);
      alternatives.push({
        option: 'split_swap',
        description: `Split into ${splitCount} smaller swaps of ~${(inputAmount / splitCount).toFixed(2)} each`,
        risk_reduction: 'Reduce price impact per transaction',
      });
    }

    // Suggest waiting for better price
    alternatives.push({
      option: 'wait_for_better_price',
      description: 'Wait for better market conditions',
      risk_reduction: 'Potentially better exchange rate',
    });

    return alternatives;
  }

  /**
   * Execute swap transaction
   */
  async executeSwap(params: SwapExecuteParams): Promise<{ signature: string }> {
    try {
      const { userId, walletId, quoteResponse } = params;

      logger.info('Executing Jupiter swap', { userId, walletId });

      // Get wallet keypair
      const keypair = await walletService.getKeypair(walletId);
      const userPublicKey = keypair.publicKey.toBase58();

      // Get swap transaction from Jupiter
      const swapResponse = await axios.post(`${JUPITER_API_URL}/swap`, {
        quoteResponse,
        userPublicKey,
        wrapAndUnwrapSol: true,
        dynamicComputeUnitLimit: true,
        prioritizationFeeLamports: 'auto',
      });

      const { swapTransaction } = swapResponse.data;

      // Deserialize transaction
      const transactionBuf = Buffer.from(swapTransaction, 'base64');
      const transaction = VersionedTransaction.deserialize(transactionBuf);

      // Sign transaction
      transaction.sign([keypair]);

      // Send transaction
      const rawTransaction = transaction.serialize();
      const signature = await this.connection.sendRawTransaction(rawTransaction, {
        skipPreflight: false,
        maxRetries: 3,
      });

      logger.info('Swap transaction sent', { signature });

      // Confirm transaction
      const latestBlockhash = await this.connection.getLatestBlockhash();
      await this.connection.confirmTransaction({
        signature,
        blockhash: latestBlockhash.blockhash,
        lastValidBlockHeight: latestBlockhash.lastValidBlockHeight,
      });

      // Record transaction
      await transactionService.recordTransaction(
        userId,
        walletId,
        'swap',
        signature,
        {
          inputMint: quoteResponse.inputMint,
          outputMint: quoteResponse.outputMint,
          inputAmount: parseInt(quoteResponse.inAmount) / Math.pow(10, 9),
          outputAmount: parseInt(quoteResponse.outAmount) / Math.pow(10, 9),
          priceImpact: quoteResponse.priceImpactPct,
        }
      );

      logger.info('Swap executed successfully', { signature });

      return { signature };
    } catch (error: any) {
      logger.error('Swap execution failed:', error);
      throw new Error(`Failed to execute swap: ${error.message}`);
    }
  }

  /**
   * Get token price in USD
   */
  async getTokenPrice(tokenMint: string): Promise<number> {
    try {
      // Use Jupiter price API
      const response = await axios.get(`${JUPITER_API_URL}/price`, {
        params: {
          ids: tokenMint,
        },
      });

      const priceData = response.data.data[tokenMint];
      if (!priceData) {
        throw new Error('Token price not found');
      }

      return priceData.price;
    } catch (error: any) {
      logger.error('Failed to get token price:', {
        message: error.message,
        status: error.response?.status,
      });
      
      const errorMessage = error.response?.data?.error || error.message || 'Unknown error';
      throw new Error(`Failed to get token price: ${errorMessage}`);
    }
  }

  /**
   * Get list of supported tokens
   */
  async getSupportedTokens(): Promise<any[]> {
    try {
      const response = await axios.get('https://token.jup.ag/strict');
      return response.data;
    } catch (error: any) {
      logger.error('Failed to get supported tokens:', {
        message: error.message,
        status: error.response?.status,
      });
      
      const errorMessage = error.response?.data?.error || error.message || 'Unknown error';
      throw new Error(`Failed to get supported tokens: ${errorMessage}`);
    }
  }

  /**
   * Validate swap parameters
   */
  async validateSwap(
    walletId: string,
    inputMint: string,
    amount: number
  ): Promise<{ valid: boolean; error?: string }> {
    try {
      // Check if amount is positive
      if (amount <= 0) {
        return { valid: false, error: 'Amount must be greater than 0' };
      }

      // Get wallet balance
      const balance = await walletService.getWalletBalance(walletId);

      // Check if it's SOL or token
      if (inputMint === 'So11111111111111111111111111111111111111112') {
        // SOL swap
        if (balance.sol < amount) {
          return { valid: false, error: 'Insufficient SOL balance' };
        }
      } else {
        // Token swap
        const token = balance.tokens?.find((t: any) => t.mint === inputMint);
        if (!token || token.amount < amount) {
          return { valid: false, error: 'Insufficient token balance' };
        }
      }

      return { valid: true };
    } catch (error: any) {
      logger.error('Swap validation failed:', error);
      return { valid: false, error: error.message };
    }
  }
}

export default new JupiterService();
