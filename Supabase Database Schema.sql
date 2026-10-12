-- ====================================================================
-- LINGUAFLOW AI - SUPABASE DATABASE SCHEMA (PostgreSQL + RLS)
-- ====================================================================

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. ENUM TYPES
CREATE TYPE user_plan AS ENUM ('free', 'pro');
CREATE TYPE difficulty_level AS ENUM ('beginner', 'intermediate', 'advanced');
CREATE TYPE exercise_type AS ENUM ('mcq', 'match', 'word_order', 'fill', 'translate');
CREATE TYPE srs_status AS ENUM ('new', 'review', 'remembered', 'mastered');

-- 3. PROFILES TABLE (Linked to auth.users)
CREATE TABLE public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT UNIQUE NOT NULL,
    full_name TEXT,
    avatar_url TEXT,
    active_language_id VARCHAR(10) DEFAULT 'ko',
    explanation_language VARCHAR(10) DEFAULT 'id',
    plan user_plan DEFAULT 'free',
    daily_target_minutes INT DEFAULT 15,
    streak_days INT DEFAULT 1,
    last_active_date DATE DEFAULT CURRENT_DATE,
    total_xp INT DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. LANGUAGES CATALOG
CREATE TABLE public.languages (
    id VARCHAR(10) PRIMARY KEY,
    name TEXT NOT NULL,
    flag_emoji VARCHAR(10) NOT NULL,
    script_name TEXT NOT NULL,
    is_available BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 5. COURSES TABLE
CREATE TABLE public.courses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    language_id VARCHAR(10) REFERENCES public.languages(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    level difficulty_level DEFAULT 'beginner',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 6. UNITS TABLE
CREATE TABLE public.units (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    course_id UUID REFERENCES public.courses(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    order_index INT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 7. LESSONS TABLE
CREATE TABLE public.lessons (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    unit_id UUID REFERENCES public.units(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    xp_reward INT DEFAULT 20,
    duration_minutes INT DEFAULT 5,
    explanation_text TEXT,
    order_index INT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 8. EXERCISES TABLE
CREATE TABLE public.exercises (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    lesson_id UUID REFERENCES public.lessons(id) ON DELETE CASCADE,
    type exercise_type NOT NULL,
    question TEXT NOT NULL,
    payload JSONB NOT NULL, -- Holds options, correct answers, or pairs
    explanation TEXT,
    order_index INT NOT NULL
);

-- 9. USER LESSON PROGRESS
CREATE TABLE public.lesson_progress (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    lesson_id UUID REFERENCES public.lessons(id) ON DELETE CASCADE,
    score INT DEFAULT 0,
    completed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, lesson_id)
);

-- 10. VOCABULARY PROGRESS (SRS)
CREATE TABLE public.vocabulary_progress (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    language_id VARCHAR(10) REFERENCES public.languages(id) ON DELETE CASCADE,
    word_target TEXT NOT NULL,
    pronunciation TEXT,
    meaning TEXT NOT NULL,
    example_sentence TEXT,
    srs_level INT DEFAULT 1,
    status srs_status DEFAULT 'new',
    is_favorite BOOLEAN DEFAULT FALSE,
    next_review_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 11. AI CHAT SESSIONS
CREATE TABLE public.chat_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    language_id VARCHAR(10) REFERENCES public.languages(id) ON DELETE CASCADE,
    scenario VARCHAR(50) DEFAULT 'greetings',
    messages JSONB DEFAULT '[]'::jsonb,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ====================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ====================================================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lesson_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vocabulary_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_sessions ENABLE ROW LEVEL SECURITY;

-- Profiles: User can view and update only their own profile
CREATE POLICY "Users can view own profile" ON public.profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id);

-- Lesson Progress Policies
CREATE POLICY "Users can view own lesson progress" ON public.lesson_progress FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own lesson progress" ON public.lesson_progress FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Vocabulary Progress Policies
CREATE POLICY "Users can manage own vocab" ON public.vocabulary_progress FOR ALL USING (auth.uid() = user_id);

-- Chat Sessions Policies
CREATE POLICY "Users can manage own chat sessions" ON public.chat_sessions FOR ALL USING (auth.uid() = user_id);

-- Public Read access for catalog
ALTER TABLE public.languages ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public catalog read" ON public.languages FOR SELECT USING (true);