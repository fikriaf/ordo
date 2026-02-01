import supabase from '../src/config/database';
import logger from '../src/config/logger';

async function updateUserRole() {
  try {
    const email = process.argv[2] || 'admin@ordo.com';
    const role = process.argv[3] || 'admin';
    
    const { data, error } = await supabase
      .from('users')
      .update({ role })
      .eq('email', email)
      .select()
      .single();
    
    if (error) {
      throw error;
    }
    
    logger.info('User role updated successfully:', {
      email: data.email,
      role: data.role,
    });
    
    console.log('\nUser updated:');
    console.log('Email:', data.email);
    console.log('Role:', data.role);
    
    process.exit(0);
  } catch (error) {
    logger.error('Failed to update user role:', error);
    process.exit(1);
  }
}

updateUserRole();
