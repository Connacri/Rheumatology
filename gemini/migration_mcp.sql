-- ================================================================
--  MIGRATION SUPABASE — EVENT REGISTRATION
--  Compatible MCP @modelcontextprotocol/server-postgres
--  Chaque bloc entre "-- [BLOC X]" peut être exécuté
--  indépendamment via l'outil MCP "query".
--
--  REMPLACE avant usage :
--    [TON_PROJECT_REF]  → ex: abcdefghijklmnop
--    [TON_DB_PASSWORD]  → mot de passe DB Supabase
-- ================================================================


-- ================================================================
-- [BLOC 1] EXTENSIONS
-- Dépendances : aucune
-- ================================================================
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "moddatetime";


-- ================================================================
-- [BLOC 2] TABLE profiles
-- Dépendances : BLOC 1, auth.users (Supabase natif)
-- ================================================================
CREATE TABLE IF NOT EXISTS public.profiles (
  id            UUID        PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email         TEXT        NOT NULL,
  first_name    TEXT        NOT NULL DEFAULT '',
  last_name     TEXT        NOT NULL DEFAULT '',
  phone_number  TEXT,
  city          TEXT,
  avatar_url    TEXT,
  role          TEXT        NOT NULL DEFAULT 'user'
                            CHECK (role IN ('user', 'admin')),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ================================================================
-- [BLOC 3] TRIGGER updated_at sur profiles
-- Dépendances : BLOC 1 (moddatetime), BLOC 2
-- ================================================================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgname = 'profiles_updated_at'
  ) THEN
    CREATE TRIGGER profiles_updated_at
      BEFORE UPDATE ON public.profiles
      FOR EACH ROW EXECUTE PROCEDURE moddatetime(updated_at);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_profiles_role ON public.profiles(role);


-- ================================================================
-- [BLOC 4] FONCTION + TRIGGER auto-création profil au signup
-- Dépendances : BLOC 2
-- ================================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, email, first_name, last_name)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'first_name', ''),
    COALESCE(NEW.raw_user_meta_data->>'last_name',  '')
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgname = 'on_auth_user_created'
  ) THEN
    CREATE TRIGGER on_auth_user_created
      AFTER INSERT ON auth.users
      FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();
  END IF;
END $$;


-- ================================================================
-- [BLOC 5] TABLE event_registrations
-- Dépendances : BLOC 2
-- ================================================================
CREATE TABLE IF NOT EXISTS public.event_registrations (
  id                   UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id              UUID        REFERENCES public.profiles(id) ON DELETE SET NULL,

  -- Identité saisie dans le formulaire
  email                TEXT        NOT NULL,
  first_name           TEXT        NOT NULL,
  last_name            TEXT        NOT NULL,
  phone_number         TEXT        NOT NULL,
  city                 TEXT        NOT NULL,

  -- Champs à choix multiple (validation côté UI Flutter uniquement)
  title                TEXT        NOT NULL,
  title_other          TEXT,
  medical_specialty    TEXT        NOT NULL,
  specialty_other      TEXT,
  healthcare_facility  TEXT        NOT NULL,
  participation_type   TEXT        NOT NULL,

  -- Workflow admin
  status               TEXT        NOT NULL DEFAULT 'pending'
                                   CHECK (status IN ('pending', 'approved', 'rejected')),
  admin_notes          TEXT,
  validated_by         UUID        REFERENCES public.profiles(id) ON DELETE SET NULL,
  validated_at         TIMESTAMPTZ,

  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ================================================================
-- [BLOC 6] INDEX + TRIGGER updated_at sur event_registrations
-- Dépendances : BLOC 1, BLOC 5
-- ================================================================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgname = 'event_registrations_updated_at'
  ) THEN
    CREATE TRIGGER event_registrations_updated_at
      BEFORE UPDATE ON public.event_registrations
      FOR EACH ROW EXECUTE PROCEDURE moddatetime(updated_at);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_reg_status     ON public.event_registrations(status);
CREATE INDEX IF NOT EXISTS idx_reg_user_id    ON public.event_registrations(user_id);
CREATE INDEX IF NOT EXISTS idx_reg_created_at ON public.event_registrations(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_reg_email      ON public.event_registrations(email);


-- ================================================================
-- [BLOC 7] RLS — profiles
-- Dépendances : BLOC 2
-- ================================================================
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "profiles: owner read"         ON public.profiles;
DROP POLICY IF EXISTS "profiles: owner update"       ON public.profiles;
DROP POLICY IF EXISTS "profiles: admin full access"  ON public.profiles;

CREATE POLICY "profiles: owner read"
  ON public.profiles FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "profiles: owner update"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = id);

CREATE POLICY "profiles: admin full access"
  ON public.profiles FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid() AND p.role = 'admin'
    )
  );


-- ================================================================
-- [BLOC 8] RLS — event_registrations
-- Dépendances : BLOC 5
-- ================================================================
ALTER TABLE public.event_registrations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "registrations: owner read"           ON public.event_registrations;
DROP POLICY IF EXISTS "registrations: owner insert"         ON public.event_registrations;
DROP POLICY IF EXISTS "registrations: owner update pending" ON public.event_registrations;
DROP POLICY IF EXISTS "registrations: admin full access"    ON public.event_registrations;

CREATE POLICY "registrations: owner read"
  ON public.event_registrations FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "registrations: owner insert"
  ON public.event_registrations FOR INSERT
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "registrations: owner update pending"
  ON public.event_registrations FOR UPDATE
  USING (user_id = auth.uid() AND status = 'pending')
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "registrations: admin full access"
  ON public.event_registrations FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid() AND p.role = 'admin'
    )
  );


-- ================================================================
-- [BLOC 9] BUCKET storage avatars
-- Dépendances : extension storage (native Supabase)
-- ================================================================
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'avatars',
  'avatars',
  false,
  2097152,
  ARRAY['image/jpeg','image/png','image/webp']
)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "avatars: owner upload"        ON storage.objects;
DROP POLICY IF EXISTS "avatars: owner update"        ON storage.objects;
DROP POLICY IF EXISTS "avatars: owner delete"        ON storage.objects;
DROP POLICY IF EXISTS "avatars: owner or admin read" ON storage.objects;

CREATE POLICY "avatars: owner upload"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'avatars'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "avatars: owner update"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'avatars'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "avatars: owner delete"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'avatars'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "avatars: owner or admin read"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'avatars'
    AND (
      auth.uid()::text = (storage.foldername(name))[1]
      OR EXISTS (
        SELECT 1 FROM public.profiles p
        WHERE p.id = auth.uid() AND p.role = 'admin'
      )
    )
  );


-- ================================================================
-- [BLOC 10] VUE admin + FONCTION validate_registration
-- Dépendances : BLOC 5, BLOC 2
-- ================================================================
CREATE OR REPLACE VIEW public.v_registrations_admin
WITH (security_invoker = true)
AS
SELECT
  r.id,
  r.status,
  r.created_at,
  r.validated_at,
  r.first_name,
  r.last_name,
  r.email,
  r.phone_number,
  r.city,
  r.title,
  r.title_other,
  r.medical_specialty,
  r.specialty_other,
  r.healthcare_facility,
  r.participation_type,
  r.admin_notes,
  p.first_name  AS admin_first_name,
  p.last_name   AS admin_last_name
FROM public.event_registrations r
LEFT JOIN public.profiles p ON p.id = r.validated_by;


CREATE OR REPLACE FUNCTION public.validate_registration(
  p_registration_id UUID,
  p_new_status       TEXT,
  p_admin_notes      TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_role TEXT;
BEGIN
  SELECT role INTO v_caller_role
  FROM public.profiles
  WHERE id = auth.uid();

  IF v_caller_role <> 'admin' THEN
    RAISE EXCEPTION 'Accès refusé : rôle admin requis';
  END IF;

  IF p_new_status NOT IN ('approved', 'rejected') THEN
    RAISE EXCEPTION 'Statut invalide : %', p_new_status;
  END IF;

  UPDATE public.event_registrations
  SET
    status       = p_new_status,
    admin_notes  = COALESCE(p_admin_notes, admin_notes),
    validated_by = auth.uid(),
    validated_at = NOW()
  WHERE id = p_registration_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Inscription introuvable : %', p_registration_id;
  END IF;
END;
$$;


-- ================================================================
-- [BLOC 11] OPTIONNEL — promouvoir un user en admin
-- Dépendances : BLOC 2 + user existant dans auth.users
-- ================================================================
-- UPDATE public.profiles
-- SET role = 'admin'
-- WHERE email = 'admin@tondomaine.com';


-- ================================================================
-- [BLOC 12] VÉRIFICATION post-migration
-- Retourne la liste des tables et policies créées
-- ================================================================
SELECT
  t.table_name,
  COUNT(p.policyname) AS nb_policies
FROM information_schema.tables t
LEFT JOIN pg_policies p
  ON p.tablename = t.table_name
  AND p.schemaname = 'public'
WHERE t.table_schema = 'public'
  AND t.table_type = 'BASE TABLE'
GROUP BY t.table_name
ORDER BY t.table_name;
