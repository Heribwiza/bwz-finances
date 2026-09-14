-- ============================================
-- CLEAN SUPABASE SETUP FOR INCOME AND SAVINGS
-- Run these commands in your Supabase SQL Editor
-- This script handles existing objects gracefully
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
-- VERIFICATION
-- ============================================
-- Check that tables were created successfully
SELECT table_name 
FROM information_schema.tables 
WHERE table_name IN ('income', 'savings');

-- Check that triggers were created
SELECT trigger_name, event_object_table, action_statement, action_timing
FROM information_schema.triggers
WHERE event_object_table IN ('income', 'savings');