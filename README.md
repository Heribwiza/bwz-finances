# BWZ CORPORATION Finance Tracker

![GitHub Pages](https://img.shields.io/badge/GitHub%20Pages-Deployed-181717?style=for-the-badge&logo=github&logoColor=white)
![GitHub Actions](https://img.shields.io/badge/GitHub%20Actions-Automated%20Deploy-2088FF?style=for-the-badge&logo=github-actions&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-Backend-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)

A personal finance management web application for tracking expenses, debts, income, and savings.

## Live Demo

🌐 **Deployed at:** https://heribwiza.github.io/bwz-finances/

*(GitHub Pages automatically deploys from the `master` branch)*

## Features

- 💰 **Expense Tracking** - Log spending with categories and descriptions
- 📋 **Debt Management** - Track owed amounts with paid/unpaid status
- 💵 **Income Logging** - Record income sources with categories
- 🏦 **Savings Tracker** - Manage deposits and withdrawals
- 📊 **Monthly Reports** - Filter and view data by month
- 🔄 **Real-time Sync** - Updates automatically via Supabase
- 💾 **Backup & Restore** - Export/import JSON backups
- 📱 **Mobile Friendly** - Responsive design for all devices
- 🖨️ **Print Support** - Print financial reports

## Tech Stack

- **Frontend:** Vanilla HTML/CSS/JavaScript
- **Backend:** Supabase (PostgreSQL + Auth + Realtime)
- **Hosting:** GitHub Pages (static deployment)
- **CI/CD:** GitHub Actions (automated deployment)

## Setup

### Prerequisites

1. A Supabase project with the following tables:
   - `expenses`
   - `debts`
   - `income`
   - `savings`

2. Run the SQL setup:
   ```sql
   -- Execute supabase_setup.sql in your Supabase SQL Editor
   ```

3. Configure Supabase credentials in `finance_tracker.html`:
   ```javascript
   const SUPABASE_URL = "your-project-url.supabase.co";
   const SUPABASE_PUBLISHABLE_KEY = "sb_publishable_...";
   ```

## Deployment

This project is deployed via **GitHub Pages** with **GitHub Actions** automation. Every push to the `master` branch automatically triggers a deployment.

### Deployment Flow

```
git push origin master
    ↓
GitHub Actions Workflow Triggers
    ↓
Build & Upload Artifact
    ↓
Deploy to GitHub Pages
    ↓
Live Site Updates Automatically
```

### Local Development

```bash
# No build step required - it's a static site
# Just open finance_tracker.html in your browser
```

### Publishing Changes

```bash
git add .
git commit -m "Your commit message"
git push origin master
# GitHub Actions automatically deploys the update to GitHub Pages
```

### Manual Deployment Trigger

You can also manually trigger a deployment from the GitHub Actions tab:
1. Go to **Actions** tab in your repository
2. Select the "Deploy to GitHub Pages" workflow
3. Click **"Run workflow"**

## Enable GitHub Pages (First Time Setup)

If GitHub Pages is not yet enabled:

1. Go to your repository on GitHub
2. Click **Settings** → **Pages** (in the left sidebar)
3. Under **Source**, select **GitHub Actions** as the source
4. Click **Save**
5. The deployment will start automatically

## Security Notes

- Uses only Supabase anon/publishable key (safe for client-side)
- Row Level Security (RLS) enabled on all tables
- Never commit service_role keys or secrets

## License

Private - All rights reserved
