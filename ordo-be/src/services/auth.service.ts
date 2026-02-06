import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import { v4 as uuidv4 } from 'uuid';
import supabase from '../config/database';
import env from '../config/env';
import logger from '../config/logger';
import { User, Wallet } from '../types';
import walletService from './wallet.service';

const SALT_ROUNDS = 10;

export class AuthService {
  async register(email: string, password: string, role: 'user' | 'admin' = 'user'): Promise<{ user: Omit<User, 'password_hash'>; token: string; wallet: Wallet }> {
    try {
      // Check if user already exists
      const { data: existingUser } = await supabase
        .from('users')
        .select('id')
        .eq('email', email)
        .single();

      if (existingUser) {
        throw new Error('User already exists');
      }

      // Hash password
      const passwordHash = await bcrypt.hash(password, SALT_ROUNDS);

      // Create user
      const userId = uuidv4();
      const { data: user, error } = await supabase
        .from('users')
        .insert({
          id: userId,
          email,
          password_hash: passwordHash,
          role,
        })
        .select('id, email, role, created_at, updated_at')
        .single();

      if (error) {
        logger.error('Failed to create user:', error);
        throw new Error('Failed to create user');
      }

      // Auto-create wallet for new user
      const wallet = await walletService.createWallet(userId);
      logger.info(`Auto-created wallet for new user: ${wallet.public_key}`);

      // Generate JWT token
      const token = this.generateToken(user.id, user.email, user.role);

      logger.info(`User registered: ${email}`);
      return { user, token, wallet };
    } catch (error) {
      logger.error('Registration error:', error);
      throw error;
    }
  }

  async login(email: string, password: string): Promise<{ user: Omit<User, 'password_hash'>; token: string }> {
    try {
      // Find user
      const { data: user, error } = await supabase
        .from('users')
        .select('*')
        .eq('email', email)
        .single();

      if (error || !user) {
        throw new Error('Invalid credentials');
      }

      // Verify password
      const isValidPassword = await bcrypt.compare(password, user.password_hash);
      if (!isValidPassword) {
        throw new Error('Invalid credentials');
      }

      // Generate JWT token
      const token = this.generateToken(user.id, user.email, user.role);

      logger.info(`User logged in: ${email}`);
      
      // Remove password_hash from response
      const { password_hash, ...userWithoutPassword } = user;
      return { user: userWithoutPassword, token };
    } catch (error) {
      logger.error('Login error:', error);
      throw error;
    }
  }

  generateToken(userId: string, email: string, role: string): string {
    const payload = { userId, email, role };
    return jwt.sign(payload, env.JWT_SECRET, { expiresIn: env.JWT_EXPIRES_IN } as jwt.SignOptions);
  }

  verifyToken(token: string): { userId: string; email: string; role: string } {
    try {
      const decoded = jwt.verify(token, env.JWT_SECRET) as {
        userId: string;
        email: string;
        role: string;
      };
      return decoded;
    } catch (error) {
      throw new Error('Invalid or expired token');
    }
  }

  async refreshToken(oldToken: string): Promise<string> {
    try {
      const decoded = this.verifyToken(oldToken);
      
      // Verify user still exists
      const { data: user, error } = await supabase
        .from('users')
        .select('id, email, role')
        .eq('id', decoded.userId)
        .single();

      if (error || !user) {
        throw new Error('User not found');
      }

      // Generate new token
      return this.generateToken(user.id, user.email, user.role);
    } catch (error) {
      logger.error('Token refresh error:', error);
      throw error;
    }
  }

  /**
   * Verify user password for sensitive operations
   */
  async verifyPassword(userId: string, password: string): Promise<boolean> {
    try {
      const { data: user, error } = await supabase
        .from('users')
        .select('password_hash')
        .eq('id', userId)
        .single();

      if (error || !user) {
        throw new Error('User not found');
      }

      const isValid = await bcrypt.compare(password, user.password_hash);
      return isValid;
    } catch (error) {
      logger.error('Password verification error:', error);
      throw error;
    }
  }
}

export default new AuthService();
