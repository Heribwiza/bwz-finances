# BWZ CORPORATION Finance Tracker

A personal finance management web application for tracking expenses, debts, income, and savings.

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

This project is deployed via GitHub Pages. Every push to the `main` branch automatically updates the live site.

### Local Development

```bash
# No build step required - it's a static site
# Just open finance_tracker.html in your browser
```

### Publishing Changes

```bash
git add .
git commit -m "Your commit message"
git push origin main
# GitHub Pages automatically deploys the update
```

## Security Notes

- Uses only Supabase anon/publishable key (safe for client-side)
- Row Level Security (RLS) enabled on all tables
- Never commit service_role keys or secrets

## License

Private - All rights reserved
