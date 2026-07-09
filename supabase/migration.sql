-- SQL Migration: Add Subscription, Scan Limit, & Blocked URL Sync Features

-- 1. Alter users table to add cached premium indicator, scan count, and blocked list array
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS is_premium BOOLEAN DEFAULT FALSE NOT NULL,
ADD COLUMN IF NOT EXISTS lifetime_scan_count INT DEFAULT 0 NOT NULL,
ADD COLUMN IF NOT EXISTS blocked_list TEXT[] DEFAULT '{}'::text[] NOT NULL,
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW();

-- 2. Create index on is_premium for faster lookups
CREATE INDEX IF NOT EXISTS idx_users_premium ON public.users(user_id, is_premium);

-- 3. Create plans table
CREATE TABLE IF NOT EXISTS public.plans (
    plan_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    description TEXT,
    duration_months INT NOT NULL,
    price NUMERIC(10, 2) NOT NULL,
    currency VARCHAR(10) DEFAULT 'INR' NOT NULL,
    features JSONB DEFAULT '[]'::jsonb NOT NULL,
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW() NOT NULL
);

-- 4. Create subscriptions table
CREATE TABLE IF NOT EXISTS public.subscriptions (
    subscription_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(user_id) ON DELETE CASCADE,
    plan_id UUID NOT NULL REFERENCES public.plans(plan_id) ON DELETE CASCADE,
    status VARCHAR(50) DEFAULT 'pending' NOT NULL,
    payment_provider VARCHAR(50) DEFAULT 'razorpay' NOT NULL,
    payment_id VARCHAR(100),
    order_id VARCHAR(100),
    payment_signature VARCHAR(255),
    amount NUMERIC(10, 2),
    currency VARCHAR(10) DEFAULT 'INR' NOT NULL,
    start_date TIMESTAMP WITHOUT TIME ZONE,
    expiry_date TIMESTAMP WITHOUT TIME ZONE,
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW() NOT NULL
);

-- Create indexes on subscriptions
CREATE INDEX IF NOT EXISTS idx_subscriptions_user ON public.subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_status ON public.subscriptions(user_id, status);

-- 5. Create app_settings table
CREATE TABLE IF NOT EXISTS public.app_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    setting_key VARCHAR(100) UNIQUE NOT NULL,
    setting_value VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW() NOT NULL
);

-- 6. Create blocked_urls table
CREATE TABLE IF NOT EXISTS public.blocked_urls (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(user_id) ON DELETE CASCADE,
    url TEXT NOT NULL,
    reason TEXT,
    blocked_at TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW() NOT NULL
);

-- Create indexes on blocked_urls
CREATE INDEX IF NOT EXISTS idx_blocked_urls_user ON public.blocked_urls(user_id);
CREATE INDEX IF NOT EXISTS idx_blocked_urls_url ON public.blocked_urls(user_id, url);

-- 7. Seed default data if not exists
INSERT INTO public.app_settings (setting_key, setting_value)
VALUES ('free_scan_limit', '10')
ON CONFLICT (setting_key) DO NOTHING;

-- Seed plans
INSERT INTO public.plans (plan_id, name, description, duration_months, price, currency, features, is_active)
VALUES 
  ('a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d', 'Free', 'Basic scan protection with limited monthly credits', 0, 0.00, 'INR', '["10 Lifetime URL Scans", "Basic Threat Detection"]'::jsonb, true),
  ('b2c3d4e5-f6a7-8b9c-0d1e-2f3a4b5c6d7e', 'Monthly', 'Full protection billed monthly', 1, 99.00, 'INR', '["Unlimited URL Scans", "AI Threat Analysis", "Community Threat Intelligence", "Priority Processing"]'::jsonb, true),
  ('c3d4e5f6-a7b8-9c0d-1e2f-3a4b5c6d7e8f', 'Yearly', 'Complete protection with annual savings', 12, 999.00, 'INR', '["Unlimited URL Scans", "AI Threat Analysis", "Community Threat Intelligence", "Priority Processing", "15% Savings vs Monthly"]'::jsonb, true)
ON CONFLICT (plan_id) DO NOTHING;

-- 8. Create function to enforce scan limit BEFORE inserting into url_scans
CREATE OR REPLACE FUNCTION check_scan_limit()
RETURNS TRIGGER AS $$
DECLARE
    user_is_premium BOOLEAN;
    user_scan_count INT;
    free_limit INT;
BEGIN
    -- Skip check for anonymous scans (scans without user_id)
    IF NEW.user_id IS NULL THEN
        RETURN NEW;
    END IF;

    -- Get the user's premium status and current scan count
    SELECT is_premium, lifetime_scan_count 
    INTO user_is_premium, user_scan_count
    FROM public.users
    WHERE user_id = NEW.user_id;

    -- If user record doesn't exist, allow (handled by RLS / users table inserts)
    IF user_is_premium IS NULL THEN
        RETURN NEW;
    END IF;

    -- If the user is premium, always allow the scan
    IF user_is_premium = TRUE THEN
        RETURN NEW;
    END IF;

    -- Fetch free scan limit from app_settings
    SELECT CAST(setting_value AS INTEGER)
    INTO free_limit
    FROM public.app_settings
    WHERE setting_key = 'free_scan_limit';

    -- Fallback to default 10 if not found
    IF free_limit IS NULL THEN
        free_limit := 10;
    END IF;

    -- Enforce scan limit for free users
    IF user_scan_count >= free_limit THEN
        RAISE EXCEPTION 'Free scan limit reached. Please upgrade to Premium.';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 9. Attach BEFORE INSERT trigger to url_scans
DROP TRIGGER IF EXISTS trigger_check_scan_limit ON public.url_scans;
CREATE TRIGGER trigger_check_scan_limit
BEFORE INSERT ON public.url_scans
FOR EACH ROW
EXECUTE FUNCTION check_scan_limit();

-- 10. Create function to automatically increment lifetime_scan_count AFTER inserting into url_scans
CREATE OR REPLACE FUNCTION increment_user_scan_count()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.user_id IS NOT NULL THEN
        UPDATE public.users
        SET lifetime_scan_count = lifetime_scan_count + 1,
            updated_at = NOW()
        WHERE user_id = NEW.user_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 11. Attach AFTER INSERT trigger to url_scans
DROP TRIGGER IF EXISTS trigger_increment_scan_count ON public.url_scans;
CREATE TRIGGER trigger_increment_scan_count
AFTER INSERT ON public.url_scans
FOR EACH ROW
EXECUTE FUNCTION increment_user_scan_count();

-- 12. Create function to sync blocked_urls table inserts/updates/deletes with users.blocked_list array
CREATE OR REPLACE FUNCTION sync_user_blocked_list()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        -- Add the URL to the user's blocked_list array if it doesn't already exist
        UPDATE public.users
        SET blocked_list = array_append(
            array_remove(blocked_list, NEW.url), -- avoid duplicates
            NEW.url
        ),
        updated_at = NOW()
        WHERE user_id = NEW.user_id;
        
    ELSIF (TG_OP = 'UPDATE') THEN
        -- Remove the old URL and add the new URL
        UPDATE public.users
        SET blocked_list = array_append(
            array_remove(blocked_list, OLD.url),
            NEW.url
        ),
        updated_at = NOW()
        WHERE user_id = NEW.user_id;
        
    ELSIF (TG_OP = 'DELETE') THEN
        -- Remove the URL from the user's blocked_list array
        UPDATE public.users
        SET blocked_list = array_remove(blocked_list, OLD.url),
            updated_at = NOW()
        WHERE user_id = OLD.user_id;
    END IF;
    
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- 13. Attach AFTER INSERT/UPDATE/DELETE trigger to blocked_urls
DROP TRIGGER IF EXISTS trigger_sync_blocked_urls ON public.blocked_urls;
CREATE TRIGGER trigger_sync_blocked_urls
AFTER INSERT OR UPDATE OR DELETE ON public.blocked_urls
FOR EACH ROW
EXECUTE FUNCTION sync_user_blocked_list();

-- 14. Sync existing blocked_urls into users.blocked_list array (one-time migration check)
UPDATE public.users u
SET blocked_list = COALESCE(
    (
        SELECT array_agg(url)
        FROM public.blocked_urls b
        WHERE b.user_id = u.user_id
    ),
    '{}'::text[]
);

-- 14.5 Create function and trigger to handle automatic profile creation on signup
-- This cleans up any old orphaned profiles with the same email if a user is recreated in auth
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  DELETE FROM public.users WHERE email = NEW.email;
  
  INSERT INTO public.users (user_id, username, email, role)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'username', SPLIT_PART(NEW.email, '@', 1)),
    NEW.email,
    'user'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 15. Row Level Security (RLS) policies

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.blocked_urls ENABLE ROW LEVEL SECURITY;

-- users policies
DROP POLICY IF EXISTS "Allow users to read their own profile" ON public.users;
CREATE POLICY "Allow users to read their own profile"
ON public.users
FOR SELECT
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Allow users to insert their own profile" ON public.users;
CREATE POLICY "Allow users to insert their own profile"
ON public.users
FOR INSERT
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Allow users to update their own subscription and profile" ON public.users;
CREATE POLICY "Allow users to update their own subscription and profile"
ON public.users
FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- plans policies
DROP POLICY IF EXISTS "Allow public read access to plans" ON public.plans;
CREATE POLICY "Allow public read access to plans"
ON public.plans
FOR SELECT
USING (true);

-- subscriptions policies
DROP POLICY IF EXISTS "Allow users to read their own subscriptions" ON public.subscriptions;
CREATE POLICY "Allow users to read their own subscriptions"
ON public.subscriptions
FOR SELECT
USING (auth.uid() = user_id);

-- app_settings policies
DROP POLICY IF EXISTS "Allow public read access to app_settings" ON public.app_settings;
CREATE POLICY "Allow public read access to app_settings"
ON public.app_settings
FOR SELECT
USING (true);

-- blocked_urls policies
DROP POLICY IF EXISTS "Allow users to read their own blocked urls" ON public.blocked_urls;
CREATE POLICY "Allow users to read their own blocked urls"
ON public.blocked_urls
FOR SELECT
USING (
    auth.uid() = user_id
    OR
    (SELECT is_premium FROM public.users WHERE user_id = auth.uid()) = TRUE
);

DROP POLICY IF EXISTS "Allow users to block a url" ON public.blocked_urls;
CREATE POLICY "Allow users to block a url"
ON public.blocked_urls
FOR INSERT
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Allow users to unblock a url" ON public.blocked_urls;
CREATE POLICY "Allow users to unblock a url"
ON public.blocked_urls
FOR DELETE
USING (auth.uid() = user_id);

-- url_scans policies
ALTER TABLE public.url_scans ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow users to read their own scans" ON public.url_scans;
CREATE POLICY "Allow users to read their own scans"
ON public.url_scans
FOR SELECT
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Allow users to insert scans" ON public.url_scans;
CREATE POLICY "Allow users to insert scans"
ON public.url_scans
FOR INSERT
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Allow users to delete their own scans" ON public.url_scans;
CREATE POLICY "Allow users to delete their own scans"
ON public.url_scans
FOR DELETE
USING (auth.uid() = user_id);
