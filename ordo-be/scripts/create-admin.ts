import authService from '../src/services/auth.service';
import logger from '../src/config/logger';

async function createAdmin() {
  try {
    const email = 'admin@ordo.com';
    const password = 'admin123';
    
    const result = await authService.register(email, password, 'admin');
    
    logger.info('Admin user created successfully:', {
      email: result.user.email,
      role: result.user.role,
    });
    
    console.log('\nAdmin credentials:');
    console.log('Email:', email);
    console.log('Password:', password);
    console.log('\nToken:', result.token);
    
    process.exit(0);
  } catch (error) {
    logger.error('Failed to create admin:', error);
    process.exit(1);
  }
}

createAdmin();
