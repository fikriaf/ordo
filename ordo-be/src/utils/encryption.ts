import crypto from 'crypto';
import env from '../config/env';

const ALGORITHM = 'aes-256-gcm';
const IV_LENGTH = 16; // 128 bits

export interface EncryptedData {
  ciphertext: string;
  iv: string;
  authTag: string;
}

export const encrypt = (plaintext: string): EncryptedData => {
  try {
    // Generate random IV
    const iv = crypto.randomBytes(IV_LENGTH);

    // Create cipher
    const cipher = crypto.createCipheriv(ALGORITHM, Buffer.from(env.ENCRYPTION_KEY), iv);

    // Encrypt data
    let ciphertext = cipher.update(plaintext, 'utf8', 'hex');
    ciphertext += cipher.final('hex');

    // Get authentication tag
    const authTag = cipher.getAuthTag();

    return {
      ciphertext,
      iv: iv.toString('hex'),
      authTag: authTag.toString('hex'),
    };
  } catch (error) {
    throw new Error(`Encryption failed: ${error}`);
  }
};

export const decrypt = (encryptedData: EncryptedData): string => {
  try {
    const { ciphertext, iv, authTag } = encryptedData;

    // Create decipher
    const decipher = crypto.createDecipheriv(
      ALGORITHM,
      Buffer.from(env.ENCRYPTION_KEY),
      Buffer.from(iv, 'hex')
    );

    // Set authentication tag
    decipher.setAuthTag(Buffer.from(authTag, 'hex'));

    // Decrypt data
    let plaintext = decipher.update(ciphertext, 'hex', 'utf8');
    plaintext += decipher.final('utf8');

    return plaintext;
  } catch (error) {
    throw new Error(`Decryption failed: ${error}`);
  }
};

export const encryptPrivateKey = (privateKey: string): EncryptedData => {
  return encrypt(privateKey);
};

export const decryptPrivateKey = (encryptedData: EncryptedData): string => {
  return decrypt(encryptedData);
};
