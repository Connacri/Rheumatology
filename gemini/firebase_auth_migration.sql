-- ═══════════════════════════════════════════════════════════════════════════════
-- MIGRATION : ADAPTATION POUR AUTHENTIFICATION FIREBASE
-- ═══════════════════════════════════════════════════════════════════════════════

-- 1. Supprimer la contrainte de clé étrangère vers auth.users
--    Car les IDs Firebase ne sont pas présents dans la table auth.users de Supabase.
ALTER TABLE public.congress_users DROP CONSTRAINT IF EXISTS congress_users_id_fkey;

-- 2. Fonction pour extraire l'ID utilisateur (Firebase ou Supabase)
--    On cherche d'abord dans le header 'x-user-id', puis dans l'auth Supabase native.
CREATE OR REPLACE FUNCTION public.get_my_id()
RETURNS UUID AS $$
DECLARE
  _id TEXT;
BEGIN
  -- Tentative de lecture du header personnalisé (utile si on bypass Supabase Auth)
  _id := current_setting('request.headers', true)::json->>'x-user-id';
  IF _id IS NOT NULL THEN
    RETURN _id::uuid;
  END IF;
  -- Fallback sur l'ID standard de Supabase
  RETURN auth.uid();
EXCEPTION WHEN OTHERS THEN
  RETURN auth.uid();
END;
$$ LANGUAGE plpgsql STABLE;

-- 3. Mise à jour des fonctions de rôles pour utiliser get_my_id()
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.congress_users
    WHERE id = public.get_my_id()
    AND role IN ('admin', 'super_admin')
  );
$$ LANGUAGE sql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.is_moderator()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.congress_users
    WHERE id = public.get_my_id()
    AND role IN ('admin', 'super_admin', 'moderator')
  );
$$ LANGUAGE sql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.is_receptionist()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.congress_users
    WHERE id = public.get_my_id()
    AND role IN ('admin', 'super_admin', 'receptionist')
  );
$$ LANGUAGE sql SECURITY DEFINER;

-- 4. Donner les accès aux tables pour le rôle 'anon' (Firebase users)
GRANT USAGE ON SCHEMA public TO anon;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO anon;

-- 5. Recréer les politiques RLS en utilisant get_my_id() au lieu de auth.uid()

-- congress_users
DROP POLICY IF EXISTS "user_own_read" ON public.congress_users;
CREATE POLICY "user_own_read" ON public.congress_users
  FOR SELECT USING (id = public.get_my_id());

DROP POLICY IF EXISTS "user_own_update_profile" ON public.congress_users;
CREATE POLICY "user_own_update_profile" ON public.congress_users
  FOR UPDATE USING (id = public.get_my_id())
  WITH CHECK (id = public.get_my_id());

DROP POLICY IF EXISTS "user_own_insert" ON public.congress_users;
CREATE POLICY "user_own_insert" ON public.congress_users
  FOR INSERT WITH CHECK (id = public.get_my_id());

-- congress_sessions
DROP POLICY IF EXISTS "everyone_read_sessions" ON public.congress_sessions;
CREATE POLICY "everyone_read_sessions" ON public.congress_sessions
  FOR SELECT USING (true); -- Permettre la lecture même sans auth Supabase

-- congress_questions
DROP POLICY IF EXISTS "guest_read_questions" ON public.congress_questions;
CREATE POLICY "guest_read_questions" ON public.congress_questions
  FOR SELECT USING (status != 'rejected');

DROP POLICY IF EXISTS "guest_insert_question" ON public.congress_questions;
CREATE POLICY "guest_insert_question" ON public.congress_questions
  FOR INSERT WITH CHECK (
    user_id = public.get_my_id()
    AND EXISTS (
      SELECT 1 FROM public.congress_sessions s
      WHERE s.id = session_id AND s.qa_open = TRUE
    )
  );

-- question_votes
DROP POLICY IF EXISTS "guest_vote" ON public.question_votes;
CREATE POLICY "guest_vote" ON public.question_votes
  FOR INSERT WITH CHECK (user_id = public.get_my_id());

DROP POLICY IF EXISTS "guest_read_votes" ON public.question_votes;
CREATE POLICY "guest_read_votes" ON public.question_votes
  FOR SELECT USING (true);

-- congress_connections
DROP POLICY IF EXISTS "user_own_connections" ON public.congress_connections;
CREATE POLICY "user_own_connections" ON public.congress_connections
  FOR ALL USING (
    requester_id = public.get_my_id() OR target_id = public.get_my_id()
  );

-- session_feedbacks
DROP POLICY IF EXISTS "guest_own_feedback" ON public.session_feedbacks;
CREATE POLICY "guest_own_feedback" ON public.session_feedbacks
  FOR ALL USING (user_id = public.get_my_id());

-- congress_notifications
DROP POLICY IF EXISTS "user_own_notifications" ON public.congress_notifications;
CREATE POLICY "user_own_notifications" ON public.congress_notifications
  FOR ALL USING (user_id = public.get_my_id());

-- congress_certificates
DROP POLICY IF EXISTS "user_own_cert" ON public.congress_certificates;
CREATE POLICY "user_own_cert" ON public.congress_certificates
  FOR SELECT USING (user_id = public.get_my_id());
