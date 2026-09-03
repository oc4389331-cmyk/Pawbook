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
    favorite_species TEXT[] DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Safely add column if upgrading existing database
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS favorite_species TEXT[] DEFAULT '{}';

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
    media_type TEXT DEFAULT 'video' NOT NULL,
    caption TEXT DEFAULT '',
    likes_count INT DEFAULT 0 NOT NULL,
    views_count INT DEFAULT 0 NOT NULL,
    tags TEXT[] DEFAULT '{}',
    status post_status_type DEFAULT 'pending_review' NOT NULL,
    report_count INT DEFAULT 0 NOT NULL,
    moderation_reason TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Safely add columns if upgrading existing database
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS views_count INT DEFAULT 0 NOT NULL;
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS tags TEXT[] DEFAULT '{}';

-- 5. Post Likes Table (Prevents duplicates & feeds recommendation algorithm)
CREATE TABLE IF NOT EXISTS public.post_likes (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    post_id TEXT NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    CONSTRAINT unique_user_post_like UNIQUE (user_id, post_id)
);

-- 6. Comments Table (TikTok-style comments under video posts)
CREATE TABLE IF NOT EXISTS public.comments (
    id TEXT PRIMARY KEY,
    post_id TEXT NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
    user_id TEXT NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- 7. Sponsorships Table (Stripe Fiat & Solana Pay Crypto audit trail)
CREATE TABLE IF NOT EXISTS public.sponsorships (
    id TEXT PRIMARY KEY,
    sponsor_id TEXT NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    pet_id TEXT NOT NULL REFERENCES public.pets(id) ON DELETE CASCADE,
    amount INT NOT NULL,
    payment_method TEXT DEFAULT 'stripe' NOT NULL, -- 'stripe' or 'solana_pay'
    tx_hash TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- 8. Orders Table (Rewards Shop Exchanges)
CREATE TABLE IF NOT EXISTS public.orders (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    reward_name TEXT NOT NULL,
    points_cost INT NOT NULL,
    status TEXT DEFAULT 'pending' NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- ====================================================================
-- INDEXES FOR MAXIMUM QUERY PERFORMANCE & ALGORITHM RECOMMENDATION
-- ====================================================================
CREATE INDEX IF NOT EXISTS idx_profiles_wallet ON public.profiles(wallet_address);
CREATE INDEX IF NOT EXISTS idx_pets_owner ON public.pets(owner_id);
CREATE INDEX IF NOT EXISTS idx_posts_pet ON public.posts(pet_id);
CREATE INDEX IF NOT EXISTS idx_posts_feed ON public.posts(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_post_likes_user ON public.post_likes(user_id);
CREATE INDEX IF NOT EXISTS idx_post_likes_post ON public.post_likes(post_id);
CREATE INDEX IF NOT EXISTS idx_comments_post ON public.comments(post_id);
CREATE INDEX IF NOT EXISTS idx_sponsorships_pet ON public.sponsorships(pet_id);

-- ====================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ====================================================================

-- Enable RLS on all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sponsorships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

-- Profiles Policies
DROP POLICY IF EXISTS "Public Profiles Read Access" ON public.profiles;
CREATE POLICY "Public Profiles Read Access" ON public.profiles FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;
CREATE POLICY "Users can insert own profile" ON public.profiles FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can update own profile" ON public.profiles FOR UPDATE USING (true);

-- Pets Policies
DROP POLICY IF EXISTS "Public Pets Read Access" ON public.pets;
CREATE POLICY "Public Pets Read Access" ON public.pets FOR SELECT USING (true);

DROP POLICY IF EXISTS "Owners can insert pets" ON public.pets;
CREATE POLICY "Owners can insert pets" ON public.pets FOR INSERT WITH CHECK (true);

-- Posts Policies
DROP POLICY IF EXISTS "Public Active Posts Read Access" ON public.posts;
CREATE POLICY "Public Active Posts Read Access" ON public.posts FOR SELECT USING (status = 'active');

DROP POLICY IF EXISTS "Pets can insert posts" ON public.posts;
CREATE POLICY "Pets can insert posts" ON public.posts FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM public.pets WHERE pets.id = posts.pet_id)
);

-- Post Likes Policies
DROP POLICY IF EXISTS "Public Likes Read Access" ON public.post_likes;
CREATE POLICY "Public Likes Read Access" ON public.post_likes FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can insert likes" ON public.post_likes;
CREATE POLICY "Users can insert likes" ON public.post_likes FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Users can delete own likes" ON public.post_likes;
CREATE POLICY "Users can delete own likes" ON public.post_likes FOR DELETE USING (true);

-- Comments Policies
DROP POLICY IF EXISTS "Public Comments Read Access" ON public.comments;
CREATE POLICY "Public Comments Read Access" ON public.comments FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can insert comments" ON public.comments;
CREATE POLICY "Users can insert comments" ON public.comments FOR INSERT WITH CHECK (true);

-- Sponsorships Policies
DROP POLICY IF EXISTS "Public Sponsorships Read Access" ON public.sponsorships;
CREATE POLICY "Public Sponsorships Read Access" ON public.sponsorships FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can insert sponsorships" ON public.sponsorships;
CREATE POLICY "Users can insert sponsorships" ON public.sponsorships FOR INSERT WITH CHECK (true);

-- Orders Policies
DROP POLICY IF EXISTS "Users can view own orders" ON public.orders;
CREATE POLICY "Users can view own orders" ON public.orders FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can insert orders" ON public.orders;
CREATE POLICY "Users can insert orders" ON public.orders FOR INSERT WITH CHECK (true);
