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
- 🇷 **Rwandan Franc (FRW)** - Books are kept in FRW by default, with optional USD or CDF per entry
- 🧮 **Per-currency totals** - FRW, USD and CDF amounts are never added together; a mixed total shows the FRW figure with the other currencies listed beneath it (`445 000 RWF` + `80 USD · -25 CDF`)
- 🛡️ **Currency is never lost** - the picked currency is stored per row and, if a database is missing the `currency` column, remembered per entry until the one-time migration runs (see Troubleshooting below)
- 📊 **Monthly Reports** - Filter and view data by month
- 🔄 **Real-time Sync** - Updates automatically via Supabase
- 💱 **Live exchange rates** - the ticker pulls real USD rates (FRW, CDF, EUR, GBP, UGX, KES, JPY, CNY) from free key-less feeds, caches them for 6 hours and falls back to a saved or bundled estimate when offline
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
   -- It creates/updates the tables and adds the `currency` column,
   -- which defaults to 'RWF' (Rwandan Franc / FRW).
   ```

   If your tables already exist, just re-run the **CURRENCY COLUMN** section of
   `supabase_setup.sql` — it is idempotent and backfills old rows to RWF.

   Totals are always kept per currency: the big figure is the Rwandan franc
   (or whichever currency your books mostly use) and any USD/CDF amounts appear
   on their own line underneath, so different currencies are never merged into
   one misleading number.

3. Configure Supabase credentials in `finance_tracker.html`:
   ```javascript
   const SUPABASE_URL = "your-project-url.supabase.co";
   const SUPABASE_PUBLISHABLE_KEY = "sb_publishable_...";
   ```

## Live Exchange Rates

The ticker at the top of the page shows real market rates, quoted per **1 USD**.
It needs no API key and no configuration — no secret is stored in the page.

**Where the numbers come from.** Two free, key-less feeds are tried in order:

1. [`open.er-api.com`](https://open.er-api.com/v6/latest/USD)
2. [`jsdelivr` CDN currency API](https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/usd.json)

If the first feed is down, times out (10 s) or returns something unexpected, the
second one is used instead. The feed that answered is printed in the ticker label.

**The status pill tells you which reading you are looking at:**

| Pill | Meaning |
| --- | --- |
| **Live** | Fresh rates just fetched from the feed. |
| **Saved copy** | The feed was unreachable, so the last saved reading is shown. |
| **Offline** | The browser is offline — a saved copy is shown if there is one, otherwise the bundled snapshot. |
| **Bundled estimate** | No feed *and* nothing saved: a built-in snapshot is shown and the sub-label reads "Bundled estimate". |

**Caching and refresh.** A fetched reading is saved in `localStorage`
(`bwzFxRates:v1`) and is considered fresh for **6 hours**; the ticker polls again
every **5 minutes**, when the browser comes back online, and when the tab is
brought to the front. The change percentage next to each currency is computed
against the previous reading (`bwzFxPrevRates:v1`), so it reflects an actual
move rather than a hardcoded value.

**FRW and CDF are highlighted** because they are the currencies this book is kept
in. These market rates are display-only — they never convert or alter the amounts
you log, so your per-currency totals stay exact.

## Troubleshooting: a CDF or USD entry reloads as FRW

**Cause.** The app stores each entry's currency in a `currency` column. If your
database was created before that column existed, Supabase rejects the `currency`
field ("Could not find the 'currency' column ... in the schema cache"), so the
row is saved *without* it and reloads as the FRW default. The app never loses
the entry — it just loses the currency.

**Fix (one time).** Run this in the Supabase SQL Editor, then refresh the page:

```sql
alter table public.expenses add column if not exists currency text not null default 'RWF';
alter table public.debts    add column if not exists currency text not null default 'RWF';
alter table public.income   add column if not exists currency text not null default 'RWF';
alter table public.savings  add column if not exists currency text not null default 'RWF';
```

The app detects the missing column and shows a banner with this SQL (and a
**Copy SQL** button) the moment a currency cannot be stored, so you never have
to guess. The same statements are in the **CURRENCY COLUMN** section of
`supabase_setup.sql`.

**Meanwhile.** `insertRow()` retries the save without the `currency` field so
the entry is never blocked, and the app remembers the currency you picked for
that row's id in `localStorage` (`bwzRowCurrency:v1`). Your CDF and USD entries
therefore still render correctly in that browser before the migration — after the
migration the database itself holds the currency and it syncs everywhere.

**Entries you created *before* running the SQL.** The migration adds the column
with `default 'RWF'`, so every older row is backfilled to FRW — including a CDF
or USD entry whose currency was never stored. The app handles this: when the
database holds nothing but the default while this browser remembers a deliberate
pick for that same row id, the **remembered** currency is shown instead. So those
entries come back as CDF/USD rather than FRW.

Two limits worth knowing:

- That recovery is **per browser**. In a browser that never logged the entry,
  the old row reads FRW because the database genuinely never stored it. Re-saving
  such an entry (or editing it) stores the currency properly from now on.
- Once the column really holds a foreign currency, the **database always wins**
  over anything remembered, so this can never override correct data.

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
