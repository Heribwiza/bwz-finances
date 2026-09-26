-- ==============================================================================
-- BWZ CORPORATION - EMAIL NOTIFICATIONS & AUDIT QUEUE SETUP
-- Run this script in the Supabase SQL Editor.
-- Safe to re-run: Uses IF NOT EXISTS and idempotent statements.
-- ==============================================================================

-- 1. NOTIFICATION QUEUE TABLE
-- Holds pending instant & daily summary notifications to be dispatched.
CREATE TABLE IF NOT EXISTS public.notification_queue (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users,
  type TEXT NOT NULL,                  -- 'login', 'transaction', 'savings_summary', 'daily_summary'
  recipient TEXT NOT NULL,             -- target email, e.g. 'hheribwiza1@gmail.com'
  subject TEXT NOT NULL,
  html_body TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'sent', 'failed')),
  error_message TEXT,
  payload JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  sent_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX IF NOT EXISTS idx_notification_queue_status_created 
  ON public.notification_queue (status, created_at);

-- Enable RLS on notification_queue
ALTER TABLE public.notification_queue ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DROP POLICY IF EXISTS "Users can insert notifications" ON public.notification_queue;
DROP POLICY IF EXISTS "Users can view own notifications" ON public.notification_queue;

-- Allow authenticated users to insert notification requests
CREATE POLICY "Users can insert notifications" 
  ON public.notification_queue FOR INSERT 
  TO authenticated 
  WITH CHECK (auth.uid() = user_id OR user_id IS NULL);

-- Allow authenticated users to inspect their own notification status
CREATE POLICY "Users can view own notifications" 
  ON public.notification_queue FOR SELECT 
  TO authenticated 
  USING (auth.uid() = user_id);

-- 2. LOGIN AUDIT LOGS TABLE
-- Records login activity for security auditing and login notification triggers
CREATE TABLE IF NOT EXISTS public.login_records (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users NOT NULL,
  user_email TEXT NOT NULL,
  client_info JSONB DEFAULT '{}'::jsonb,
  login_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_login_records_user_time 
  ON public.login_records (user_id, login_at DESC);

-- Enable RLS on login_records
ALTER TABLE public.login_records ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can insert own login records" ON public.login_records;
DROP POLICY IF EXISTS "Users can view own login records" ON public.login_records;

CREATE POLICY "Users can insert own login records" 
  ON public.login_records FOR INSERT 
  TO authenticated 
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can view own login records" 
  ON public.login_records FOR SELECT 
  TO authenticated 
  USING (auth.uid() = user_id);
