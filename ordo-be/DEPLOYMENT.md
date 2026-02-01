# Deployment Guide

## Prerequisites

- Docker & Docker Compose installed
- Server dengan minimal 2GB RAM
- Domain name (optional, untuk HTTPS)
- SSL certificate (optional, untuk HTTPS)

## Deployment Options

### Option 1: Docker Compose (Recommended)

1. **Clone repository di server**:
```bash
git clone <repository-url>
cd ordo-be
```

2. **Setup environment variables**:
```bash
cp .env.production.example .env
nano .env  # Edit dengan production values
```

3. **Build dan run**:
```bash
docker-compose up -d
```

4. **Check logs**:
```bash
docker-compose logs -f
```

5. **Check health**:
```bash
curl http://localhost:3000/health
```

### Option 2: Manual Deployment

1. **Install Node.js 18+**:
```bash
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs
```

2. **Clone dan setup**:
```bash
git clone <repository-url>
cd ordo-be
npm install
cp .env.production.example .env
nano .env  # Edit dengan production values
```

3. **Build**:
```bash
npm run build
```

4. **Run dengan PM2**:
```bash
npm install -g pm2
pm2 start dist/index.js --name ordo-backend
pm2 save
pm2 startup
```

5. **Monitor**:
```bash
pm2 logs ordo-backend
pm2 monit
```

### Option 3: Kubernetes (Advanced)

Coming soon...

## Environment Variables

### Required Variables

```env
NODE_ENV=production
PORT=3000
SUPABASE_URL=<your-supabase-url>
SUPABASE_KEY=<your-supabase-key>
JWT_SECRET=<secure-random-string>
ENCRYPTION_KEY=<32-character-key>
SOLANA_RPC_URL=<helius-mainnet-url>
OPENROUTER_API_KEY=<your-openrouter-key>
AI_MODELS=<comma-separated-model-list>
```

### Optional Variables

```env
SENTRY_DSN=<sentry-dsn>
DATADOG_API_KEY=<datadog-key>
CORS_ORIGIN=<frontend-domain>
```

## Database Setup

1. **Create Supabase project**:
   - Go to https://supabase.com
   - Create new project
   - Copy URL and anon key

2. **Run migrations**:
   - Open Supabase SQL Editor
   - Copy contents of `src/config/migrations.sql`
   - Execute

3. **Verify tables**:
   - Check that all 9 tables are created
   - Verify indexes and constraints

## SSL/HTTPS Setup

### Using Nginx as Reverse Proxy

1. **Install Nginx**:
```bash
sudo apt-get install nginx
```

2. **Configure Nginx**:
```bash
sudo nano /etc/nginx/sites-available/ordo-backend
```

```nginx
server {
    listen 80;
    server_name api.yourdomain.com;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

3. **Enable site**:
```bash
sudo ln -s /etc/nginx/sites-available/ordo-backend /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

4. **Setup SSL with Let's Encrypt**:
```bash
sudo apt-get install certbot python3-certbot-nginx
sudo certbot --nginx -d api.yourdomain.com
```

## Monitoring

### Health Checks

```bash
# Basic health check
curl https://api.yourdomain.com/health

# Detailed health check
curl https://api.yourdomain.com/health/detailed
```

### Logs

**Docker Compose**:
```bash
docker-compose logs -f
```

**PM2**:
```bash
pm2 logs ordo-backend
```

**File logs**:
```bash
tail -f logs/app.log
tail -f logs/app-error.log
```

### Metrics

Setup monitoring dengan:
- **Sentry** untuk error tracking
- **Datadog** untuk metrics dan APM
- **Prometheus + Grafana** untuk custom metrics

## Backup

### Database Backup

Supabase provides automatic backups. For manual backup:

```bash
# Export dari Supabase dashboard
# Settings > Database > Backups
```

### Application Backup

```bash
# Backup environment variables
cp .env .env.backup

# Backup logs
tar -czf logs-backup-$(date +%Y%m%d).tar.gz logs/
```

## Scaling

### Horizontal Scaling

1. **Load Balancer Setup**:
```nginx
upstream ordo_backend {
    server backend1:3000;
    server backend2:3000;
    server backend3:3000;
}

server {
    location / {
        proxy_pass http://ordo_backend;
    }
}
```

2. **Session Management**:
   - Use JWT tokens (stateless)
   - No session storage needed

### Vertical Scaling

Increase server resources:
- RAM: 2GB → 4GB → 8GB
- CPU: 1 core → 2 cores → 4 cores

## Troubleshooting

### Server won't start

1. Check logs:
```bash
docker-compose logs
# or
pm2 logs
```

2. Verify environment variables:
```bash
cat .env
```

3. Test database connection:
```bash
curl -X GET "https://your-supabase-url/rest/v1/" \
  -H "apikey: your-supabase-key"
```

### High memory usage

1. Check Node.js memory:
```bash
pm2 monit
```

2. Increase memory limit:
```bash
pm2 start dist/index.js --name ordo-backend --max-memory-restart 1G
```

### Slow response times

1. Check health endpoint:
```bash
curl https://api.yourdomain.com/health/detailed
```

2. Monitor dependencies:
   - Database response time
   - Solana RPC response time
   - OpenRouter API response time

3. Enable caching (Redis):
```bash
docker-compose up -d redis
```

## Security Checklist

- [ ] Environment variables secured
- [ ] HTTPS enabled
- [ ] Rate limiting configured
- [ ] Input sanitization enabled
- [ ] Database credentials rotated
- [ ] API keys secured
- [ ] Firewall configured
- [ ] SSH key-based auth only
- [ ] Regular security updates
- [ ] Backup strategy in place

## Rollback

### Docker Compose

```bash
# Rollback to previous version
docker-compose down
git checkout <previous-commit>
docker-compose up -d
```

### PM2

```bash
# Stop current version
pm2 stop ordo-backend

# Checkout previous version
git checkout <previous-commit>
npm run build

# Start
pm2 restart ordo-backend
```

## Support

For deployment issues, contact the development team or open an issue on GitHub.
