import { Router, Response } from 'express';
import { z } from 'zod';
import { authenticate, requireAdmin } from '../middleware/auth.middleware';
import adminService from '../services/admin.service';
import aiModelService from '../services/ai-model.service';
import pluginAdminService from '../services/plugin-admin.service';
import configService from '../services/config.service';
import logger from '../config/logger';
import { AuthenticatedRequest } from '../types';

const router = Router();

// All admin routes require authentication and admin role
router.use(authenticate);
router.use(requireAdmin);

// Dashboard metrics
router.get('/dashboard', async (_req: AuthenticatedRequest, res: Response) => {
  try {
    const metrics = await adminService.getDashboardMetrics();
    res.json({ success: true, data: metrics });
  } catch (error) {
    logger.error('Error getting dashboard metrics:', error);
    res.status(500).json({ success: false, error: 'Failed to get dashboard metrics' });
  }
});

// User management
const getUsersSchema = z.object({
  search: z.string().optional(),
  page: z.coerce.number().int().positive().optional(),
  limit: z.coerce.number().int().positive().max(100).optional(),
});

router.get('/users', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const filters = getUsersSchema.parse(req.query);
    const users = await adminService.getUsers(filters);
    res.json({ success: true, data: users });
  } catch (error) {
    if (error instanceof z.ZodError) {
      res.status(400).json({ success: false, error: error.errors });
      return;
    }
    logger.error('Error getting users:', error);
    res.status(500).json({ success: false, error: 'Failed to get users' });
  }
});

router.get('/users/:id', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const user = await adminService.getUserById(req.params.id);
    if (!user) {
      res.status(404).json({ success: false, error: 'User not found' });
      return;
    }
    res.json({ success: true, data: user });
  } catch (error) {
    logger.error('Error getting user:', error);
    res.status(500).json({ success: false, error: 'Failed to get user' });
  }
});

router.delete('/users/:id', async (req: AuthenticatedRequest, res: Response) => {
  try {
    if (!req.user) {
      res.status(401).json({ success: false, error: 'Unauthorized' });
      return;
    }

    await adminService.deleteUser(req.params.id, req.user.id);
    res.json({ success: true, message: 'User deleted successfully' });
  } catch (error) {
    logger.error('Error deleting user:', error);
    res.status(500).json({ success: false, error: 'Failed to delete user' });
  }
});

// Transaction monitoring
const getTransactionsSchema = z.object({
  userId: z.string().uuid().optional(),
  status: z.enum(['pending', 'confirmed', 'failed']).optional(),
  type: z.string().optional(),
  startDate: z.string().datetime().optional(),
  endDate: z.string().datetime().optional(),
  page: z.coerce.number().int().positive().optional(),
  limit: z.coerce.number().int().positive().max(100).optional(),
});

router.get('/transactions', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const filters = getTransactionsSchema.parse(req.query);
    const transactions = await adminService.getTransactions(filters);
    res.json({ success: true, data: transactions });
  } catch (error) {
    if (error instanceof z.ZodError) {
      res.status(400).json({ success: false, error: error.errors });
      return;
    }
    logger.error('Error getting transactions:', error);
    res.status(500).json({ success: false, error: 'Failed to get transactions' });
  }
});

router.get('/transactions/stats', async (_req: AuthenticatedRequest, res: Response) => {
  try {
    const stats = await adminService.getTransactionStats();
    res.json({ success: true, data: stats });
  } catch (error) {
    logger.error('Error getting transaction stats:', error);
    res.status(500).json({ success: false, error: 'Failed to get transaction stats' });
  }
});

// Audit logs
const getAuditLogsSchema = z.object({
  adminId: z.string().uuid().optional(),
  action: z.string().optional(),
  startDate: z.string().datetime().optional(),
  endDate: z.string().datetime().optional(),
  page: z.coerce.number().int().positive().optional(),
  limit: z.coerce.number().int().positive().max(100).optional(),
});

router.get('/audit-logs', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const filters = getAuditLogsSchema.parse(req.query);
    const logs = await adminService.getAuditLogs(filters);
    res.json({ success: true, data: logs });
  } catch (error) {
    if (error instanceof z.ZodError) {
      res.status(400).json({ success: false, error: error.errors });
      return;
    }
    logger.error('Error getting audit logs:', error);
    res.status(500).json({ success: false, error: 'Failed to get audit logs' });
  }
});

// AI Model Management
router.get('/models', async (_req: AuthenticatedRequest, res: Response) => {
  try {
    const models = await aiModelService.getAllModels();
    res.json({ success: true, data: models });
  } catch (error) {
    logger.error('Error getting models:', error);
    res.status(500).json({ success: false, error: 'Failed to get models' });
  }
});

const createModelSchema = z.object({
  name: z.string().min(1),
  provider: z.string().min(1),
  model_id: z.string().min(1),
  config: z.record(z.any()).optional(),
});

router.post('/models', async (req: AuthenticatedRequest, res: Response) => {
  try {
    if (!req.user) {
      res.status(401).json({ success: false, error: 'Unauthorized' });
      return;
    }

    const input = createModelSchema.parse(req.body);
    const model = await aiModelService.createModel(input, req.user.id);
    res.status(201).json({ success: true, data: model });
  } catch (error) {
    if (error instanceof z.ZodError) {
      res.status(400).json({ success: false, error: error.errors });
      return;
    }
    logger.error('Error creating model:', error);
    res.status(500).json({ success: false, error: (error as Error).message });
  }
});

const updateModelSchema = z.object({
  name: z.string().min(1).optional(),
  provider: z.string().min(1).optional(),
  model_id: z.string().min(1).optional(),
  is_enabled: z.boolean().optional(),
  config: z.record(z.any()).optional(),
});

router.put('/models/:id', async (req: AuthenticatedRequest, res: Response) => {
  try {
    if (!req.user) {
      res.status(401).json({ success: false, error: 'Unauthorized' });
      return;
    }

    const input = updateModelSchema.parse(req.body);
    const model = await aiModelService.updateModel(req.params.id, input, req.user.id);
    res.json({ success: true, data: model });
  } catch (error) {
    if (error instanceof z.ZodError) {
      res.status(400).json({ success: false, error: error.errors });
      return;
    }
    logger.error('Error updating model:', error);
    res.status(500).json({ success: false, error: (error as Error).message });
  }
});

router.delete('/models/:id', async (req: AuthenticatedRequest, res: Response) => {
  try {
    if (!req.user) {
      res.status(401).json({ success: false, error: 'Unauthorized' });
      return;
    }

    await aiModelService.deleteModel(req.params.id, req.user.id);
    res.json({ success: true, message: 'Model deleted successfully' });
  } catch (error) {
    logger.error('Error deleting model:', error);
    res.status(500).json({ success: false, error: (error as Error).message });
  }
});

router.put('/models/:id/default', async (req: AuthenticatedRequest, res: Response) => {
  try {
    if (!req.user) {
      res.status(401).json({ success: false, error: 'Unauthorized' });
      return;
    }

    const model = await aiModelService.setDefaultModel(req.params.id, req.user.id);
    res.json({ success: true, data: model });
  } catch (error) {
    logger.error('Error setting default model:', error);
    res.status(500).json({ success: false, error: (error as Error).message });
  }
});

router.put('/models/:id/enable', async (req: AuthenticatedRequest, res: Response) => {
  try {
    if (!req.user) {
      res.status(401).json({ success: false, error: 'Unauthorized' });
      return;
    }

    const model = await aiModelService.enableModel(req.params.id, req.user.id);
    res.json({ success: true, data: model });
  } catch (error) {
    logger.error('Error enabling model:', error);
    res.status(500).json({ success: false, error: (error as Error).message });
  }
});

router.put('/models/:id/disable', async (req: AuthenticatedRequest, res: Response) => {
  try {
    if (!req.user) {
      res.status(401).json({ success: false, error: 'Unauthorized' });
      return;
    }

    const model = await aiModelService.disableModel(req.params.id, req.user.id);
    res.json({ success: true, data: model });
  } catch (error) {
    logger.error('Error disabling model:', error);
    res.status(500).json({ success: false, error: (error as Error).message });
  }
});

// Plugin Management
router.get('/plugins', async (_req: AuthenticatedRequest, res: Response) => {
  try {
    const plugins = await pluginAdminService.getAllPlugins();
    res.json({ success: true, data: plugins });
  } catch (error) {
    logger.error('Error getting plugins:', error);
    res.status(500).json({ success: false, error: 'Failed to get plugins' });
  }
});

const createPluginSchema = z.object({
  name: z.string().min(3),
  version: z.string().regex(/^\d+\.\d+\.\d+$/, 'Invalid version format. Use semantic versioning (e.g., 1.0.0)'),
  description: z.string().min(1),
  config: z.record(z.any()).optional(),
});

router.post('/plugins', async (req: AuthenticatedRequest, res: Response) => {
  try {
    if (!req.user) {
      res.status(401).json({ success: false, error: 'Unauthorized' });
      return;
    }

    const input = createPluginSchema.parse(req.body);
    const plugin = await pluginAdminService.createPlugin(input, req.user.id);
    res.status(201).json({ success: true, data: plugin });
  } catch (error) {
    if (error instanceof z.ZodError) {
      res.status(400).json({ success: false, error: error.errors });
      return;
    }
    logger.error('Error creating plugin:', error);
    res.status(500).json({ success: false, error: (error as Error).message });
  }
});

const updatePluginSchema = z.object({
  name: z.string().min(3).optional(),
  version: z.string().regex(/^\d+\.\d+\.\d+$/).optional(),
  description: z.string().min(1).optional(),
  config: z.record(z.any()).optional(),
});

router.put('/plugins/:id', async (req: AuthenticatedRequest, res: Response) => {
  try {
    if (!req.user) {
      res.status(401).json({ success: false, error: 'Unauthorized' });
      return;
    }

    const input = updatePluginSchema.parse(req.body);
    const plugin = await pluginAdminService.updatePlugin(req.params.id, input, req.user.id);
    res.json({ success: true, data: plugin });
  } catch (error) {
    if (error instanceof z.ZodError) {
      res.status(400).json({ success: false, error: error.errors });
      return;
    }
    logger.error('Error updating plugin:', error);
    res.status(500).json({ success: false, error: (error as Error).message });
  }
});

router.delete('/plugins/:id', async (req: AuthenticatedRequest, res: Response) => {
  try {
    if (!req.user) {
      res.status(401).json({ success: false, error: 'Unauthorized' });
      return;
    }

    await pluginAdminService.deletePlugin(req.params.id, req.user.id);
    res.json({ success: true, message: 'Plugin deleted successfully' });
  } catch (error) {
    logger.error('Error deleting plugin:', error);
    res.status(500).json({ success: false, error: (error as Error).message });
  }
});

router.put('/plugins/:id/enable', async (req: AuthenticatedRequest, res: Response) => {
  try {
    if (!req.user) {
      res.status(401).json({ success: false, error: 'Unauthorized' });
      return;
    }

    const plugin = await pluginAdminService.enablePlugin(req.params.id, req.user.id);
    res.json({ success: true, data: plugin });
  } catch (error) {
    logger.error('Error enabling plugin:', error);
    res.status(500).json({ success: false, error: (error as Error).message });
  }
});

router.put('/plugins/:id/disable', async (req: AuthenticatedRequest, res: Response) => {
  try {
    if (!req.user) {
      res.status(401).json({ success: false, error: 'Unauthorized' });
      return;
    }

    const plugin = await pluginAdminService.disablePlugin(req.params.id, req.user.id);
    res.json({ success: true, data: plugin });
  } catch (error) {
    logger.error('Error disabling plugin:', error);
    res.status(500).json({ success: false, error: (error as Error).message });
  }
});

// Configuration Management
router.get('/config', async (_req: AuthenticatedRequest, res: Response) => {
  try {
    const configs = await configService.getAllConfigs();
    res.json({ success: true, data: configs });
  } catch (error) {
    logger.error('Error getting configs:', error);
    res.status(500).json({ success: false, error: 'Failed to get configs' });
  }
});

router.get('/config/:key', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const config = await configService.getConfigByKey(req.params.key);
    if (!config) {
      res.status(404).json({ success: false, error: 'Config not found' });
      return;
    }
    res.json({ success: true, data: config });
  } catch (error) {
    logger.error('Error getting config:', error);
    res.status(500).json({ success: false, error: 'Failed to get config' });
  }
});

const updateConfigSchema = z.object({
  value: z.any().refine((val) => val !== undefined, {
    message: 'Value is required',
  }),
});

router.put('/config/:key', async (req: AuthenticatedRequest, res: Response) => {
  try {
    if (!req.user) {
      res.status(401).json({ success: false, error: 'Unauthorized' });
      return;
    }

    const input = updateConfigSchema.parse(req.body);
    const config = await configService.updateConfig(req.params.key, { value: input.value }, req.user.id);
    res.json({ success: true, data: config });
  } catch (error) {
    if (error instanceof z.ZodError) {
      res.status(400).json({ success: false, error: error.errors });
      return;
    }
    logger.error('Error updating config:', error);
    res.status(500).json({ success: false, error: (error as Error).message });
  }
});

router.get('/config/:key/history', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const history = await configService.getConfigHistory(req.params.key);
    res.json({ success: true, data: history });
  } catch (error) {
    logger.error('Error getting config history:', error);
    res.status(500).json({ success: false, error: 'Failed to get config history' });
  }
});

const rollbackConfigSchema = z.object({
  version: z.number().int().positive(),
});

router.post('/config/:key/rollback', async (req: AuthenticatedRequest, res: Response) => {
  try {
    if (!req.user) {
      res.status(401).json({ success: false, error: 'Unauthorized' });
      return;
    }

    const input = rollbackConfigSchema.parse(req.body);
    const config = await configService.rollbackConfig(req.params.key, input.version, req.user.id);
    res.json({ success: true, data: config });
  } catch (error) {
    if (error instanceof z.ZodError) {
      res.status(400).json({ success: false, error: error.errors });
      return;
    }
    logger.error('Error rolling back config:', error);
    res.status(500).json({ success: false, error: (error as Error).message });
  }
});

export default router;
