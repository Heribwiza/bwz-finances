-- ============================================
-- CLEAN SUPABASE SETUP FOR INCOME AND SAVINGS
-- Run these commands in your Supabase SQL Editor
-- This script handles existing objects gracefully
-- Data currency is the Rwandan Franc (FRW / RWF): the CURRENCY COLUMN
-- section below adds `currency` to all four tracker tables, defaulting
-- to RWF and backfilling existing rows.
-- ============================================

-- Enable UUID extension if not already enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- HELPER FUNCTION FOR AUTOMATIC USER_ID ASSIGNMENT
-- ============================================
CREATE OR REPLACE FUNCTION handle_user_id()
RETURNS TRIGGER AS $$
BEGIN
  NEW.user_id = auth.uid();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- INCOME TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS income (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users NOT NULL,
  title TEXT NOT NULL,
  category TEXT NOT NULL,
  description TEXT,
  amount NUMERIC NOT NULL,
  currency TEXT NOT NULL DEFAULT 'RWF',
  date DATE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE income ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view own income" ON income;
DROP POLICY IF EXISTS "Users can insert own income" ON income;
DROP POLICY IF EXISTS "Users can update own income" ON income;
DROP POLICY IF EXISTS "Users can delete own income" ON income;

-- Create RLS Policies for Income Table
CREATE POLICY "Users can view own income" 
ON income FOR SELECT 
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own income" 
ON income FOR INSERT 
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own income" 
ON income FOR UPDATE 
USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own income" 
ON income FOR DELETE 
USING (auth.uid() = user_id);

-- Create trigger to automatically set user_id
DROP TRIGGER IF EXISTS set_user_id_income ON income;
CREATE TRIGGER set_user_id_income
  BEFORE INSERT ON income
  FOR EACH ROW
  EXECUTE FUNCTION handle_user_id();

-- ============================================
-- SAVINGS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS savings (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('deposit', 'withdrawal')),
  amount NUMERIC NOT NULL,
  currency TEXT NOT NULL DEFAULT 'RWF',
  reason TEXT NOT NULL,
  date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE savings ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view own savings" ON savings;
DROP POLICY IF EXISTS "Users can insert own savings" ON savings;
DROP POLICY IF EXISTS "Users can update own savings" ON savings;
DROP POLICY IF EXISTS "Users can delete own savings" ON savings;

-- Create RLS Policies for Savings Table
CREATE POLICY "Users can view own savings" 
ON savings FOR SELECT 
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own savings" 
ON savings FOR INSERT 
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own savings" 
ON savings FOR UPDATE 
USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own savings" 
ON savings FOR DELETE 
USING (auth.uid() = user_id);

-- Create trigger to automatically set user_id
DROP TRIGGER IF EXISTS set_user_id_savings ON savings;
CREATE TRIGGER set_user_id_savings
  BEFORE INSERT ON savings
  FOR EACH ROW
  EXECUTE FUNCTION handle_user_id();

-- ============================================
-- CURRENCY COLUMN (Rwandan Franc default)
-- ============================================
-- The tracker books are kept in Rwandan francs (FRW / ISO code RWF), so RWF
-- is the default for every new row. Existing rows are backfilled to RWF.
-- The app still accepts a per-entry currency: RWF, USD or CDF.
-- Safe to run repeatedly and on projects where the column already exists.

ALTER TABLE IF EXISTS income   ADD COLUMN IF NOT EXISTS currency TEXT NOT NULL DEFAULT 'RWF';
ALTER TABLE IF EXISTS savings  ADD COLUMN IF NOT EXISTS currency TEXT NOT NULL DEFAULT 'RWF';
ALTER TABLE IF EXISTS expenses ADD COLUMN IF NOT EXISTS currency TEXT NOT NULL DEFAULT 'RWF';
ALTER TABLE IF EXISTS debts    ADD COLUMN IF NOT EXISTS currency TEXT NOT NULL DEFAULT 'RWF';

-- Backfill / normalise every row saved before the column existed, or holding an
-- unexpected code, so the CHECK constraints below can always be applied.
UPDATE income   SET currency = 'RWF' WHERE currency IS NULL OR currency NOT IN ('RWF', 'USD', 'CDF');
UPDATE savings  SET currency = 'RWF' WHERE currency IS NULL OR currency NOT IN ('RWF', 'USD', 'CDF');
UPDATE expenses SET currency = 'RWF' WHERE currency IS NULL OR currency NOT IN ('RWF', 'USD', 'CDF');
UPDATE debts    SET currency = 'RWF' WHERE currency IS NULL OR currency NOT IN ('RWF', 'USD', 'CDF');

-- Keep the data clean: only the three supported currencies are allowed.
ALTER TABLE IF EXISTS income   DROP CONSTRAINT IF EXISTS income_currency_check;
ALTER TABLE IF EXISTS income   ADD  CONSTRAINT income_currency_check   CHECK (currency IN ('RWF', 'USD', 'CDF'));
ALTER TABLE IF EXISTS savings  DROP CONSTRAINT IF EXISTS savings_currency_check;
ALTER TABLE IF EXISTS savings  ADD  CONSTRAINT savings_currency_check  CHECK (currency IN ('RWF', 'USD', 'CDF'));
ALTER TABLE IF EXISTS expenses DROP CONSTRAINT IF EXISTS expenses_currency_check;
ALTER TABLE IF EXISTS expenses ADD  CONSTRAINT expenses_currency_check CHECK (currency IN ('RWF', 'USD', 'CDF'));
ALTER TABLE IF EXISTS debts    DROP CONSTRAINT IF EXISTS debts_currency_check;
ALTER TABLE IF EXISTS debts    ADD  CONSTRAINT debts_currency_check    CHECK (currency IN ('RWF', 'USD', 'CDF'));

-- ============================================
-- VERIFICATION
-- ============================================
-- Check that tables were created successfully
SELECT table_name 
FROM information_schema.tables 
WHERE table_name IN ('income', 'savings', 'expenses', 'debts');

-- Check that the currency column exists and defaults to RWF (FRW)
SELECT table_name, column_name, data_type, column_default, is_nullable
FROM information_schema.columns
WHERE column_name = 'currency'
  AND table_name IN ('income', 'savings', 'expenses', 'debts')
ORDER BY table_name;

-- Check how many rows are booked in each currency
SELECT 'income' AS source, currency, COUNT(*) AS rows FROM income GROUP BY currency
UNION ALL
SELECT 'savings',  currency, COUNT(*) FROM savings  GROUP BY currency
UNION ALL
SELECT 'expenses', currency, COUNT(*) FROM expenses GROUP BY currency
UNION ALL
SELECT 'debts',    currency, COUNT(*) FROM debts    GROUP BY currency
ORDER BY source, currency;

-- Check that triggers were created
SELECT trigger_name, event_object_table, action_statement, action_timing
FROM information_schema.triggers
WHERE event_object_table IN ('income', 'savings');
