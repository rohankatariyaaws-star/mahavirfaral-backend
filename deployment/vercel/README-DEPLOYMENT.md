# Ecommerce App Deployment Guide

This guide will help you deploy the ecommerce application using Vercel (frontend), Fly.io (backend), and Supabase (database).

## Prerequisites

1. **Node.js** (v16+)
2. **Java** (v17+)
3. **Git**
4. **Accounts on:**
   - [Vercel](https://vercel.com)
   - [Fly.io](https://fly.io)
   - [Supabase](https://supabase.com)

## Quick Deployment

Run the deployment script:
```bash
chmod +x deploy.sh
./deploy.sh
```

## Manual Deployment Steps

### 1. Database Setup (Supabase)

1. **Create Supabase Project:**
   ```bash
   npm install -g supabase
   supabase login
   supabase projects create ecommerce-app
   ```

2. **Link Project:**
   ```bash
   cd backend
   supabase link --project-ref YOUR_PROJECT_REF
   ```

3. **Run Migrations:**
   ```bash
   supabase db push
   ```

4. **Get Database URL:**
   - Go to Supabase Dashboard → Settings → Database
   - Copy the connection string

### 2. Backend Deployment (Fly.io)

1. **Install Fly CLI:**
   ```bash
   # macOS
   brew install flyctl
   
   # Windows
   iwr https://fly.io/install.ps1 -useb | iex
   
   # Linux
   curl -L https://fly.io/install.sh | sh
   ```

2. **Login and Deploy:**
   ```bash
   cd backend
   flyctl auth login
   flyctl launch
   ```

3. **Set Environment Variables:**
   ```bash
   flyctl secrets set DATABASE_URL="your_supabase_connection_string"
   flyctl secrets set DB_USERNAME="postgres"
   flyctl secrets set DB_PASSWORD="your_db_password"
   flyctl secrets set JWT_SECRET="your_jwt_secret_key"
   flyctl secrets set FRONTEND_URL="https://your-frontend.vercel.app"
   ```

4. **Deploy:**
   ```bash
   flyctl deploy
   ```

### 3. Frontend Deployment (Vercel)

1. **Install Vercel CLI:**
   ```bash
   npm install -g vercel
   ```

2. **Deploy:**
   ```bash
   cd frontend
   vercel login
   vercel
   ```

3. **Set Environment Variables:**
   - Go to Vercel Dashboard → Your Project → Settings → Environment Variables
   - Add: `REACT_APP_API_URL` = `https://your-backend.fly.dev/api`

4. **Redeploy:**
   ```bash
   vercel --prod
   ```

## Environment Variables

### Backend (Fly.io)
- `DATABASE_URL`: Supabase connection string
- `DB_USERNAME`: Database username (usually 'postgres')
- `DB_PASSWORD`: Database password
- `JWT_SECRET`: Secret key for JWT tokens
- `FRONTEND_URL`: Your Vercel frontend URL

### Frontend (Vercel)
- `REACT_APP_API_URL`: Your Fly.io backend URL + '/api'

## Post-Deployment

1. **Test the Application:**
   - Visit your Vercel URL
   - Try logging in with: admin / admin123
   - Test adding products to cart
   - Test checkout flow

2. **Update CORS Settings:**
   - Ensure backend allows your frontend domain
   - Update `application-production.yml` if needed

3. **Monitor Logs:**
   ```bash
   # Backend logs
   flyctl logs
   
   # Frontend logs
   vercel logs
   ```

## Troubleshooting

### Common Issues:

1. **CORS Errors:**
   - Check `FRONTEND_URL` environment variable
   - Verify CORS configuration in backend

2. **Database Connection:**
   - Verify `DATABASE_URL` is correct
   - Check Supabase project is active

3. **Build Failures:**
   - Check Java version (17+)
   - Verify all dependencies are installed

4. **Environment Variables:**
   - Ensure all required variables are set
   - Check for typos in variable names

### Useful Commands:

```bash
# Check Fly.io app status
flyctl status

# View Fly.io logs
flyctl logs

# Check Vercel deployments
vercel ls

# View Vercel logs
vercel logs

# Check Supabase project
supabase projects list
```

## Scaling

### Backend (Fly.io)
- Increase machine resources in `fly.toml`
- Add more regions for global deployment

### Frontend (Vercel)
- Automatic scaling included
- Consider CDN optimization

### Database (Supabase)
- Upgrade plan for more connections
- Add read replicas for better performance

## Security Checklist

- [ ] Change default admin password
- [ ] Use strong JWT secret
- [ ] Enable HTTPS only
- [ ] Set up proper CORS
- [ ] Configure rate limiting
- [ ] Enable database backups
- [ ] Set up monitoring and alerts

## Support

For deployment issues:
1. Check the logs first
2. Verify environment variables
3. Test locally with production config
4. Check service status pages