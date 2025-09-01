# Self Hosting Community-Enhanced Personal Finance App

This guide covers hosting the enhanced personal finance app that includes Yahoo Finance integration, enhanced forecasting, and expense reimbursement tracking.

## 🚀 Quick Start

### Prerequisites
- [Docker](https://docs.docker.com/engine/install/) installed and running
- Git (optional, for cloning) or download capability

### Simple Setup (3 Steps)

1. **Get the Repository**:
   ```bash
   # Clone the repository
   git clone https://github.com/[your-username]/[your-repository-name].git
   cd [your-repository-name]
   
   # OR download ZIP and extract, then cd into folder
   ```

2. **Build and Start**:
   ```bash
   docker-compose build --no-cache
   docker-compose up -d
   ```

3. **Access Application**:
   - Visit http://localhost:3000
   - Create your account on first visit

That's it! 🎉

### What You Get Out of the Box

✅ **Yahoo Finance Integration** - Real-time security price updates  
✅ **Enhanced 24-Month Forecasting** - More responsive financial forecasts  
✅ **Expense Reimbursement Tracking** - Business expense management  
✅ **All Original Features** - Complete Maybe Finance functionality  
✅ **Pre-configured Environment** - SECRET_KEY_BASE already set  
✅ **Python Dependencies** - yfinance and supporting libraries included

## 🔧 Configuration

### Environment Variables

The `compose.yml` file includes a pre-configured SECRET_KEY_BASE. For production deployments, you should:

1. **Generate a new secret key**:
   ```bash
   openssl rand -hex 64
   ```

2. **Update compose.yml** with your new key:
   ```yaml
   environment:
     SECRET_KEY_BASE: "your-generated-key-here"
   ```

### Additional Security (Optional)

For deployments outside localhost, consider:

- **Database Password**: Change the default PostgreSQL password in `compose.yml`
- **Network Security**: Use reverse proxy (nginx) for HTTPS
- **Firewall**: Restrict port 3000 access as needed

## 🔄 Managing Your App

### Start/Stop the Application
```bash
# Start in background
docker-compose up -d

# Stop the application
docker-compose down

# View logs
docker-compose logs web

# Restart a specific service
docker-compose restart web
```

### Update the Application

Since this is a local build, updates involve rebuilding:

```bash
# Pull latest changes (if using git)
git pull origin main

# Rebuild with latest changes
docker-compose build --no-cache

# Restart with updated code
docker-compose up -d
```

### Database Management

```bash
# View database logs
docker-compose logs db

# Access database directly
docker-compose exec db psql -U maybe_user -d maybe_production

# Backup database
docker-compose exec db pg_dump -U maybe_user maybe_production > backup.sql

# Reset database (WARNING: destroys data)
docker-compose down -v
docker-compose up -d
```

## ⚙️ Using Enhanced Features

### Yahoo Finance Integration

1. **Go to Settings** → **Hosting**
2. **Enable** "Use Yahoo Finance for price updates"
3. **Test** with "Update All Prices Now" button
4. **Add securities** by typing ticker symbols directly (e.g., "AAPL", "ASML.AS")

### Enhanced Forecasting

The 24-month rolling window forecasting works automatically:
- **Recent changes** have greater impact on forecasts
- **Seasonal patterns** from last 2 years are prioritized
- **Performance** is improved with smaller datasets

### Expense Reimbursement

1. **Create category** with "Allow negative expenses" enabled
2. **Record expenses** normally (e.g., €600 business meal)
3. **Record reimbursements** as positive amounts (e.g., €600 reimbursement)
4. **View results** in budget (€0 net) and increased account balance

## 🔍 Troubleshooting

### Common Issues

#### Build Failures
```bash
# Clean Docker cache and rebuild
docker system prune -a
docker-compose build --no-cache
```

#### Python/Yahoo Finance Issues
```bash
# Verify Python installation
docker-compose exec web python3 --version
docker-compose exec web pip3 list | grep yfinance

# Check logs for Python errors
docker-compose logs web | grep -i python
```

#### Database Connection Issues
```bash
# Check database status
docker-compose ps
docker-compose logs db

# Reset database (destroys data)
docker-compose down -v
docker-compose up -d
```

#### Application Won't Start
```bash
# Check all service status
docker-compose ps

# View detailed logs
docker-compose logs

# Restart everything
docker-compose down
docker-compose up -d
```

### Performance Tips

- **Memory**: Allocate at least 2GB RAM to Docker
- **Storage**: Ensure sufficient disk space for database growth
- **Updates**: Regular updates for security and features
- **Monitoring**: Use `docker stats` to monitor resource usage

## 📊 Monitoring

### Health Checks
```bash
# Check if services are running
docker-compose ps

# Monitor resource usage
docker stats

# View recent logs
docker-compose logs --tail=100 web
```

### Backup Strategy

Regular backups are recommended:

```bash
#!/bin/bash
# backup-script.sh
DATE=$(date +%Y%m%d_%H%M%S)
docker-compose exec db pg_dump -U maybe_user maybe_production > backup_$DATE.sql
echo "Backup created: backup_$DATE.sql"
```

## 🚀 Production Deployment

### Security Considerations

1. **Change default secrets** in `compose.yml`
2. **Use HTTPS** with reverse proxy (nginx/traefik)
3. **Regular backups** of database
4. **Update regularly** for security patches
5. **Monitor logs** for unusual activity

### Reverse Proxy Example (nginx)

```nginx
server {
    listen 80;
    server_name your-domain.com;
    
    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

## 🆘 Getting Help

### Resources
- **[Troubleshooting Guide](../troubleshooting/common-issues.md)** - Common issues and solutions
- **[Feature Documentation](../features/)** - How to use enhanced features
- **[Migration Guide](../setup/migration-guide.md)** - Upgrade from original Maybe

### Support
- **GitHub Issues**: Report bugs and request features
- **Documentation**: Check `/docs/` folder for guides
- **Logs**: Always check Docker logs first when troubleshooting

### Debug Information

When reporting issues, include:
```bash
# System information
docker version
docker-compose version
uname -a

# Application status
docker-compose ps
docker-compose logs web --tail=50
```

---

## 📝 Notes

### Differences from Original Maybe

- **Local Build**: No image downloads from GitHub Container Registry
- **Enhanced Features**: Yahoo Finance, forecasting, expense reimbursement included
- **Python Dependencies**: Additional libraries for financial data integration
- **Pre-configured**: SECRET_KEY_BASE and environment ready to use

### Migration from Original

If migrating from original Maybe Finance, see [Migration Guide](../setup/migration-guide.md) for step-by-step instructions.

---

*This guide covers the enhanced community fork. For questions about original Maybe Finance, refer to their documentation.*