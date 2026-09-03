-- ====================================================================
-- PAWTBOOK SUPABASE DATABASE SCHEMA MIGRATION
-- Project Reference: phltvzkhbnjpfrgphvvw
-- Idempotent Migration: Safe to re-run multiple times
-- ====================================================================

-- 1. Create Enum for Post Status safely
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'post_status_type') THEN
        CREATE TYPE post_status_type AS ENUM ('pending_review', 'active', 'rejected');
    END IF;
END $$;

-- 2. Profiles Table (Human Tutors & Sponsors)
CREATE TABLE IF NOT EXISTS public.profiles (
    id TEXT PRIMARY KEY,
    wallet_address TEXT UNIQUE NOT NULL,
    username TEXT NOT NULL,
    pawt_score INT DEFAULT 0 NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- 3. Pets Table (Creator Profiles)
CREATE TABLE IF NOT EXISTS public.pets (
    id TEXT PRIMARY KEY,
    owner_id TEXT NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    species TEXT DEFAULT 'Dog' NOT NULL,
    breed TEXT DEFAULT 'Mixed' NOT NULL,
    bio TEXT DEFAULT '',
    avatar_url TEXT DEFAULT '',
    nft_mint_address TEXT,
    total_sponsored_score INT DEFAULT 0 NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- 4. Posts Table (Exclusive Content Published by Pets)
CREATE TABLE IF NOT EXISTS public.posts (
    id TEXT PRIMARY KEY,
    pet_id TEXT NOT NULL REFERENCES public.pets(id) ON DELETE CASCADE,
    media_url TEXT NOT NULL,
    media_type TEXT DEFAULT 'image' NOT NULL,
    caption TEXT DEFAULT '',
    likes_count INT DEFAULT 0 NOT NULL,
    status post_status_type DEFAULT 'pending_review' NOT NULL,
    report_count INT DEFAULT 0 NOT NULL,
    moderation_reason TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- 5. Orders Table (Rewards Shop Exchanges)
CREATE TABLE IF NOT EXISTS public.orders (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    reward_name TEXT NOT NULL,
    points_cost INT NOT NULL,
    status TEXT DEFAULT 'pending' NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- ====================================================================
-- INDEXES FOR MAXIMUM QUERY PERFORMANCE
-- ====================================================================
CREATE INDEX IF NOT EXISTS idx_profiles_wallet ON public.profiles(wallet_address);
CREATE INDEX IF NOT EXISTS idx_pets_owner ON public.pets(owner_id);
CREATE INDEX IF NOT EXISTS idx_posts_pet ON public.posts(pet_id);
CREATE INDEX IF NOT EXISTS idx_posts_feed ON public.posts(status, created_at DESC);

-- ====================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ====================================================================

-- Enable RLS on all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

-- Profiles Policies
DROP POLICY IF EXISTS "Public Profiles Read Access" ON public.profiles;
CREATE POLICY "Public Profiles Read Access" ON public.profiles
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;
CREATE POLICY "Users can insert own profile" ON public.profiles
    FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can update own profile" ON public.profiles
    FOR UPDATE USING (true);

-- Pets Policies
DROP POLICY IF EXISTS "Public Pets Read Access" ON public.pets;
CREATE POLICY "Public Pets Read Access" ON public.pets
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Owners can insert pets" ON public.pets;
CREATE POLICY "Owners can insert pets" ON public.pets
    FOR INSERT WITH CHECK (true);

-- Posts Policies (Key Rule: Only active posts public & Pet Creator restriction)
DROP POLICY IF EXISTS "Public Active Posts Read Access" ON public.posts;
CREATE POLICY "Public Active Posts Read Access" ON public.posts
    FOR SELECT USING (status = 'active');

DROP POLICY IF EXISTS "Pets can insert posts" ON public.posts;
CREATE POLICY "Pets can insert posts" ON public.posts
    FOR INSERT WITH CHECK (
        EXISTS (SELECT 1 FROM public.pets WHERE pets.id = posts.pet_id)
    );

-- Orders Policies
DROP POLICY IF EXISTS "Users can view own orders" ON public.orders;
CREATE POLICY "Users can view own orders" ON public.orders
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can insert orders" ON public.orders;
CREATE POLICY "Users can insert orders" ON public.orders
    FOR INSERT WITH CHECK (true);
