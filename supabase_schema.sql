-- ═══════════════════════════════════════════════════════════════════════════════
-- SUPABASE SQL COMPLET — 14ème Congrès Orano-Eurélieen de Rhumatologie
-- Exécuter dans Supabase SQL Editor dans l'ordre
-- ═══════════════════════════════════════════════════════════════════════════════

-- ── Extensions ──────────────────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ── Types ENUM ───────────────────────────────────────────────────────────────
DO $$ BEGIN
  CREATE TYPE user_role   AS ENUM ('super_admin','admin','moderator','receptionist','guest');
  CREATE TYPE user_status AS ENUM ('pending','validated','banned','reserved');
  CREATE TYPE session_type AS ENUM ('talk','symposium','break','workshop','ceremony');
  CREATE TYPE question_status AS ENUM ('pending','pinned','answered','rejected');
  CREATE TYPE connection_status AS ENUM ('pending','accepted');
  CREATE TYPE notif_type AS ENUM (
    'validated','banned','reserved','arrived',
    'qa_open','feedback_open','connection','certificate'
  );
EXCEPTION WHEN duplicate_object THEN null;
END $$;

-- ═══════════════════════════════════════════════════════════════════════════════
-- TABLE: congress_users
-- ═══════════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS congress_users (
  id                UUID        PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  role              user_role   NOT NULL DEFAULT 'guest',
  status            user_status NOT NULL DEFAULT 'pending',
  first_name        TEXT        NOT NULL DEFAULT '',
  last_name         TEXT        NOT NULL DEFAULT '',
  specialty         TEXT,
  institution       TEXT,
  country           TEXT,
  phone             TEXT,
  phone_country_code TEXT,                          -- ex: '+213'
  email             TEXT,
  avatar_url        TEXT,
  qr_token          TEXT        UNIQUE,              -- UUID généré par trigger à la validation
  networking_token  TEXT        UNIQUE,              -- UUID séparé pour le networking
  admin_notes       TEXT,
  arrived_at        TIMESTAMPTZ,
  google_id         TEXT,
  email_verified    BOOLEAN     NOT NULL DEFAULT FALSE,
  profile_complete  BOOLEAN     NOT NULL DEFAULT FALSE,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ═══════════════════════════════════════════════════════════════════════════════
-- TABLE: congress_sessions (programme)
-- ═══════════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS congress_sessions (
  id             SERIAL        PRIMARY KEY,
  date           DATE          NOT NULL,
  start_time     TEXT          NOT NULL,              -- '14h30'
  end_time       TEXT,
  title          TEXT          NOT NULL,
  speaker_name   TEXT,
  speaker_country TEXT,
  session_number INTEGER       NOT NULL DEFAULT 0,
  type           session_type  NOT NULL DEFAULT 'talk',
  hall           TEXT,                               -- salle workshop
  is_zoom        BOOLEAN       NOT NULL DEFAULT FALSE,
  qa_open        BOOLEAN       NOT NULL DEFAULT FALSE,
  feedback_open  BOOLEAN       NOT NULL DEFAULT FALSE,
  moderator_id   UUID          REFERENCES congress_users(id),
  created_at     TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

-- ═══════════════════════════════════════════════════════════════════════════════
-- TABLE: congress_questions (Q&A live)
-- ═══════════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS congress_questions (
  id             BIGSERIAL       PRIMARY KEY,
  session_id     INTEGER         NOT NULL REFERENCES congress_sessions(id) ON DELETE CASCADE,
  user_id        UUID            NOT NULL REFERENCES congress_users(id) ON DELETE CASCADE,
  text           TEXT            NOT NULL CHECK (char_length(text) <= 280),
  is_anonymous   BOOLEAN         NOT NULL DEFAULT FALSE,
  status         question_status NOT NULL DEFAULT 'pending',
  votes_count    INTEGER         NOT NULL DEFAULT 0,
  author_name    TEXT,
  author_country TEXT,
  created_at     TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

-- ═══════════════════════════════════════════════════════════════════════════════
-- TABLE: question_votes
-- ═══════════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS question_votes (
  question_id BIGINT  NOT NULL REFERENCES congress_questions(id) ON DELETE CASCADE,
  user_id     UUID    NOT NULL REFERENCES congress_users(id) ON DELETE CASCADE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (question_id, user_id)
);

-- ═══════════════════════════════════════════════════════════════════════════════
-- TABLE: congress_connections (networking)
-- ═══════════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS congress_connections (
  id           BIGSERIAL         PRIMARY KEY,
  requester_id UUID              NOT NULL REFERENCES congress_users(id) ON DELETE CASCADE,
  target_id    UUID              NOT NULL REFERENCES congress_users(id) ON DELETE CASCADE,
  status       connection_status NOT NULL DEFAULT 'pending',
  created_at   TIMESTAMPTZ       NOT NULL DEFAULT NOW(),
  UNIQUE (requester_id, target_id),
  CHECK (requester_id != target_id)
);

-- ═══════════════════════════════════════════════════════════════════════════════
-- TABLE: session_feedbacks
-- ═══════════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS session_feedbacks (
  session_id INTEGER NOT NULL REFERENCES congress_sessions(id) ON DELETE CASCADE,
  user_id    UUID    NOT NULL REFERENCES congress_users(id) ON DELETE CASCADE,
  rating     INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment    TEXT    CHECK (char_length(comment) <= 200),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (session_id, user_id)
);

-- ═══════════════════════════════════════════════════════════════════════════════
-- TABLE: congress_notifications
-- ═══════════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS congress_notifications (
  id         BIGSERIAL  PRIMARY KEY,
  user_id    UUID       NOT NULL REFERENCES congress_users(id) ON DELETE CASCADE,
  title      TEXT       NOT NULL,
  body       TEXT       NOT NULL,
  type       notif_type NOT NULL,
  read       BOOLEAN    NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ═══════════════════════════════════════════════════════════════════════════════
-- TABLE: congress_certificates
-- ═══════════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS congress_certificates (
  id           BIGSERIAL   PRIMARY KEY,
  user_id      UUID        NOT NULL REFERENCES congress_users(id) ON DELETE CASCADE,
  pdf_url      TEXT        NOT NULL,
  generated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  downloaded_at TIMESTAMPTZ,
  UNIQUE (user_id)
);

-- ═══════════════════════════════════════════════════════════════════════════════
-- INDEX
-- ═══════════════════════════════════════════════════════════════════════════════
CREATE INDEX IF NOT EXISTS idx_users_status         ON congress_users(status);
CREATE INDEX IF NOT EXISTS idx_users_role           ON congress_users(role);
CREATE INDEX IF NOT EXISTS idx_users_arrived        ON congress_users(arrived_at) WHERE arrived_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_questions_session    ON congress_questions(session_id);
CREATE INDEX IF NOT EXISTS idx_questions_votes      ON congress_questions(votes_count DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_user   ON congress_notifications(user_id, read);
CREATE INDEX IF NOT EXISTS idx_connections_requester ON congress_connections(requester_id);
CREATE INDEX IF NOT EXISTS idx_connections_target    ON congress_connections(target_id);

-- ═══════════════════════════════════════════════════════════════════════════════
-- TRIGGER 1: generate_qr_on_validate
-- Génère qr_token + networking_token à la validation
-- Envoie notification selon le statut
-- ═══════════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION generate_qr_on_validate()
RETURNS TRIGGER AS $$
BEGIN
  -- ── Validation ──
  IF NEW.status = 'validated' AND (OLD.status IS NULL OR OLD.status != 'validated') THEN
    -- Générer les tokens uniquement s'ils n'existent pas
    IF NEW.qr_token IS NULL THEN
      NEW.qr_token := gen_random_uuid()::TEXT;
    END IF;
    IF NEW.networking_token IS NULL THEN
      NEW.networking_token := gen_random_uuid()::TEXT;
    END IF;
    -- Notification invitation confirmée
    INSERT INTO congress_notifications(user_id, title, body, type)
    VALUES (
      NEW.id,
      '🎉 Invitation confirmée !',
      'Bienvenue au 14ème Congrès Orano-Eurélieen de Rhumatologie. '
      'Votre QR badge est disponible. Présentez-le à la réception.',
      'validated'
    );

  -- ── Refus ──
  ELSIF NEW.status = 'banned' AND OLD.status != 'banned' THEN
    INSERT INTO congress_notifications(user_id, title, body, type)
    VALUES (
      NEW.id,
      'Inscription non retenue',
      'Votre demande d''inscription au congrès n''a pas été retenue. '
      'Contactez l''organisation pour plus d''informations.',
      'banned'
    );

  -- ── Réserve (infos manquantes) ──
  ELSIF NEW.status = 'reserved' AND OLD.status != 'reserved' THEN
    INSERT INTO congress_notifications(user_id, title, body, type)
    VALUES (
      NEW.id,
      '⚠️ Informations complémentaires requises',
      COALESCE(
        NEW.admin_notes,
        'Des informations complémentaires sont nécessaires pour valider votre inscription.'
      ),
      'reserved'
    );
  END IF;

  NEW.updated_at := NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_user_status_change ON congress_users;
CREATE TRIGGER on_user_status_change
  BEFORE UPDATE ON congress_users
  FOR EACH ROW EXECUTE FUNCTION generate_qr_on_validate();

-- ═══════════════════════════════════════════════════════════════════════════════
-- TRIGGER 2: on_vote_insert → incrémente votes_count
-- ═══════════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION increment_vote_count()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE congress_questions
  SET votes_count = votes_count + 1
  WHERE id = NEW.question_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_vote_insert ON question_votes;
CREATE TRIGGER on_vote_insert
  AFTER INSERT ON question_votes
  FOR EACH ROW EXECUTE FUNCTION increment_vote_count();

-- ═══════════════════════════════════════════════════════════════════════════════
-- TRIGGER 3: on_qa_open → notification à tous les invités présents
-- ═══════════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION notify_qa_open()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.qa_open = TRUE AND OLD.qa_open = FALSE THEN
    -- Insérer une notification pour chaque invité validé et arrivé
    INSERT INTO congress_notifications(user_id, title, body, type)
    SELECT
      u.id,
      '💬 Q&A ouvert !',
      'Posez vos questions en direct pour la session : ' || NEW.title,
      'qa_open'
    FROM congress_users u
    WHERE u.role = 'guest'
      AND u.status = 'validated'
      AND u.arrived_at IS NOT NULL;
  END IF;

  IF NEW.feedback_open = TRUE AND OLD.feedback_open = FALSE THEN
    INSERT INTO congress_notifications(user_id, title, body, type)
    SELECT
      u.id,
      '⭐ Donnez votre avis !',
      'Évaluez la session : ' || NEW.title,
      'feedback_open'
    FROM congress_users u
    WHERE u.role = 'guest'
      AND u.status = 'validated'
      AND u.arrived_at IS NOT NULL;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_session_update ON congress_sessions;
CREATE TRIGGER on_session_update
  AFTER UPDATE ON congress_sessions
  FOR EACH ROW EXECUTE FUNCTION notify_qa_open();

-- ═══════════════════════════════════════════════════════════════════════════════
-- TRIGGER 4: on_connection_accepted → notification aux deux users
-- ═══════════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION notify_connection()
RETURNS TRIGGER AS $$
DECLARE
  requester_name TEXT;
  target_name    TEXT;
BEGIN
  IF NEW.status = 'accepted' AND OLD.status = 'pending' THEN
    SELECT first_name || ' ' || last_name INTO requester_name
    FROM congress_users WHERE id = NEW.requester_id;

    SELECT first_name || ' ' || last_name INTO target_name
    FROM congress_users WHERE id = NEW.target_id;

    -- Notifier le demandeur
    INSERT INTO congress_notifications(user_id, title, body, type)
    VALUES (
      NEW.requester_id,
      '🤝 Connexion acceptée',
      target_name || ' a accepté votre demande de connexion.',
      'connection'
    );

    -- Notifier la cible
    INSERT INTO congress_notifications(user_id, title, body, type)
    VALUES (
      NEW.target_id,
      '🤝 Nouvelle connexion',
      'Vous êtes maintenant connecté avec ' || requester_name,
      'connection'
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_connection_accepted ON congress_connections;
CREATE TRIGGER on_connection_accepted
  AFTER UPDATE ON congress_connections
  FOR EACH ROW EXECUTE FUNCTION notify_connection();

-- ═══════════════════════════════════════════════════════════════════════════════
-- TRIGGER 5: updated_at auto
-- ═══════════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at := NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_users_updated_at
  BEFORE UPDATE ON congress_users
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ═══════════════════════════════════════════════════════════════════════════════
-- REALTIME
-- ═══════════════════════════════════════════════════════════════════════════════
ALTER PUBLICATION supabase_realtime
  ADD TABLE congress_users, congress_notifications,
            congress_questions, congress_sessions, congress_connections;

-- ═══════════════════════════════════════════════════════════════════════════════
-- ROW LEVEL SECURITY (RLS)
-- ═══════════════════════════════════════════════════════════════════════════════
ALTER TABLE congress_users           ENABLE ROW LEVEL SECURITY;
ALTER TABLE congress_sessions        ENABLE ROW LEVEL SECURITY;
ALTER TABLE congress_questions       ENABLE ROW LEVEL SECURITY;
ALTER TABLE question_votes           ENABLE ROW LEVEL SECURITY;
ALTER TABLE congress_connections     ENABLE ROW LEVEL SECURITY;
ALTER TABLE session_feedbacks        ENABLE ROW LEVEL SECURITY;
ALTER TABLE congress_notifications   ENABLE ROW LEVEL SECURITY;
ALTER TABLE congress_certificates    ENABLE ROW LEVEL SECURITY;

-- Helpers
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM congress_users
    WHERE id = auth.uid()
    AND role IN ('admin', 'super_admin')
  );
$$ LANGUAGE sql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION is_moderator()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM congress_users
    WHERE id = auth.uid()
    AND role IN ('admin', 'super_admin', 'moderator')
  );
$$ LANGUAGE sql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION is_receptionist()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM congress_users
    WHERE id = auth.uid()
    AND role IN ('admin', 'super_admin', 'receptionist')
  );
$$ LANGUAGE sql SECURITY DEFINER;

-- ── congress_users RLS ────────────────────────────────────────────────────────
CREATE POLICY "admin_all_users" ON congress_users
  FOR ALL USING (is_admin());

CREATE POLICY "receptionist_read_users" ON congress_users
  FOR SELECT USING (is_receptionist());

CREATE POLICY "receptionist_update_arrived" ON congress_users
  FOR UPDATE USING (is_receptionist())
  WITH CHECK (is_receptionist());

CREATE POLICY "user_own_read" ON congress_users
  FOR SELECT USING (id = auth.uid());

CREATE POLICY "user_own_update_profile" ON congress_users
  FOR UPDATE USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

CREATE POLICY "user_own_insert" ON congress_users
  FOR INSERT WITH CHECK (id = auth.uid());

-- ── congress_sessions RLS ─────────────────────────────────────────────────────
CREATE POLICY "everyone_read_sessions" ON congress_sessions
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "moderator_update_sessions" ON congress_sessions
  FOR UPDATE USING (is_moderator());

CREATE POLICY "admin_all_sessions" ON congress_sessions
  FOR ALL USING (is_admin());

-- ── congress_questions RLS ────────────────────────────────────────────────────
CREATE POLICY "moderator_all_questions" ON congress_questions
  FOR ALL USING (is_moderator());

CREATE POLICY "guest_read_questions" ON congress_questions
  FOR SELECT USING (status != 'rejected' AND auth.uid() IS NOT NULL);

CREATE POLICY "guest_insert_question" ON congress_questions
  FOR INSERT WITH CHECK (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM congress_sessions s
      WHERE s.id = session_id AND s.qa_open = TRUE
    )
  );

-- ── question_votes RLS ────────────────────────────────────────────────────────
CREATE POLICY "guest_vote" ON question_votes
  FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "guest_read_votes" ON question_votes
  FOR SELECT USING (auth.uid() IS NOT NULL);

-- ── congress_connections RLS ──────────────────────────────────────────────────
CREATE POLICY "user_own_connections" ON congress_connections
  FOR ALL USING (
    requester_id = auth.uid() OR target_id = auth.uid()
  );

-- ── session_feedbacks RLS ─────────────────────────────────────────────────────
CREATE POLICY "admin_read_feedbacks" ON session_feedbacks
  FOR SELECT USING (is_admin() OR is_moderator());

CREATE POLICY "guest_own_feedback" ON session_feedbacks
  FOR ALL USING (user_id = auth.uid());

-- ── congress_notifications RLS ────────────────────────────────────────────────
CREATE POLICY "user_own_notifications" ON congress_notifications
  FOR ALL USING (user_id = auth.uid());

-- ── congress_certificates RLS ─────────────────────────────────────────────────
CREATE POLICY "admin_all_certs" ON congress_certificates
  FOR ALL USING (is_admin());

CREATE POLICY "user_own_cert" ON congress_certificates
  FOR SELECT USING (user_id = auth.uid());

-- ═══════════════════════════════════════════════════════════════════════════════
-- SUPABASE STORAGE BUCKETS
-- ═══════════════════════════════════════════════════════════════════════════════
-- Exécuter dans Storage → Nouveau bucket

-- INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
-- VALUES
--   ('congress-avatars',      'congress-avatars',      true,  2097152, ARRAY['image/jpeg','image/png','image/webp']),
--   ('congress-certificates', 'congress-certificates', false, 5242880, ARRAY['application/pdf']),
--   ('session-slides',        'session-slides',        false, 20971520, ARRAY['application/pdf']);

-- ═══════════════════════════════════════════════════════════════════════════════
-- DONNÉES DE TEST — Programme complet 23-25 Avril 2026
-- ═══════════════════════════════════════════════════════════════════════════════
INSERT INTO congress_sessions (date, start_time, end_time, title, speaker_name, speaker_country, session_number, type) VALUES
-- Jeudi 23 Avril
('2026-04-23','13h00',NULL,'Accueil des invités et inscription',NULL,NULL,0,'ceremony'),
('2026-04-23','14h00','14h30','Cérémonie d''ouverture',NULL,NULL,0,'ceremony'),
('2026-04-23','14h30','14h55','Management of hyperparathyroidism','Ibrahim Medhet','Égypte (Le Caire)',1,'talk'),
('2026-04-23','14h55','15h20','Customized Management of Osteoporosis Beyond WHO Guidelines','Basel K Masri','Jordanie (Amman)',1,'talk'),
('2026-04-23','15h20','15h35','Behind the fracture: A Forgotten Diagnosis in Men','Boukabous Abdenour','Algérie (Alger)',1,'talk'),
('2026-04-23','15h35','15h55','Updates of osteoporosis of chronic inflammatory rheumatism','Ouafi Mouloud','France (Paris)',1,'talk'),
('2026-04-23','15h55','16h15','Fractures in elderly subjects','Yakoubi Mustapha','Algérie (Alger)',1,'talk'),
('2026-04-23','16h15','16h45','Symposium AMGEN — Denosumab in Osteoporosis','Medjadi Mohsine','Algérie (Oran)',1,'symposium'),
('2026-04-23','16h45','17h05','Débat',NULL,NULL,1,'break'),
('2026-04-23','17h05','17h30','Pause café',NULL,NULL,0,'break'),
('2026-04-23','17h30','17h55','Botulinum toxin: pain reliever of today?','Viel Eric','France (Nîmes)',2,'talk'),
('2026-04-23','17h55','18h10','Immunomodulatory Properties of Baclofen','Keniche Assia','Algérie (Tlemcen)',2,'talk'),
('2026-04-23','18h10','18h35','Concept du Care or healing — Evidence-Based Medicine','Djebbar Mourad','Algérie (Oran)',2,'talk'),
('2026-04-23','18h35','18h55','Long-term corticosteroid therapy in 2026','Merad Samir','Algérie (Oran)',2,'talk'),
('2026-04-23','18h55','19h25','Symposium Pharmadis — Management of corticosteroids on RA','Khaled Tarek','Algérie (Constantine)',2,'symposium'),
('2026-04-23','19h25',NULL,'Débat',NULL,NULL,2,'break'),
-- Vendredi 24 Avril — Workshops
('2026-04-24','08h30','09h20','Workshop 1 — Interventional ultrasound of the knee','Dr Belmouhoub Abdessamad','France (Privas)',0,'workshop'),
('2026-04-24','08h30','09h20','Workshop 2 — When RA Isn''t typical','Pr Acheli Dehbia','Algérie (Alger)',0,'workshop'),
('2026-04-24','08h30','09h20','Workshop 3 — Dupuytren''s needle aponeurotomy','Pr Touzi Mongi','Tunisie (Monastir)',0,'workshop'),
('2026-04-24','08h30','09h20','Workshop 4 — Capillaroscopy','Pr Rahou Amine','Algérie (Oran)',0,'workshop'),
('2026-04-24','08h30','09h20','Workshop 5 — Clinical cases: Spinal Pathologies','Dr Rouidi Sid Ahmed','France (Châteaudun)',0,'workshop'),
('2026-04-24','09h20','09h40','Juvenile idiopathic arthritis','Hashad Soad Salem','Libye (Tripoli)',3,'talk'),
('2026-04-24','09h40','10h00','Rheumatoid Vasculitis','Huseynova Nargiz','Azerbaïdjan (Bakou)',3,'talk'),
('2026-04-24','10h00','10h20','AI in managing patients with autoimmune diseases','Ghadanfar Yaser','Koweït',3,'talk'),
('2026-04-24','10h20','11h05','Symposium J&J — Role of IL-23 inhibitors','Bengana Bilal','Algérie (Alger)',3,'symposium'),
('2026-04-24','11h05','11h20','PSORIATIC ARTHRITIS: Predicting its appearance','Bouziane Kheira','Algérie (Oran)',3,'talk'),
('2026-04-24','11h20','11h35','Psoriatic arthritis is difficult to treat','Abdelaoui Selma','Algérie (Alger)',3,'talk'),
('2026-04-24','11h35','12h20','Symposium Biopharm Lilly — Anti-IL-17 Therapy','Pr Durez Patrick','Belgique (Bruxelles)',3,'symposium'),
('2026-04-24','12h20','13h00','Débat',NULL,NULL,3,'break'),
('2026-04-24','13h00','14h30','Déjeuner',NULL,NULL,0,'break'),
('2026-04-24','14h30','15h00','Musculoskeletal ultrasound in RA — Maghreb recommendations','Haddouche Assia & Slimani Samy','Algérie (Batna)',4,'talk'),
('2026-04-24','15h00','15h30','What''s new in interventional rheumatology?','Ould Henia Ahmed','France (Chartres)',4,'talk'),
('2026-04-24','15h30','15h50','Gout: Epidemiology and management strategies','Kurmann Patric Thierry','Suisse (Neuchâtel)',4,'talk'),
('2026-04-24','15h50','16h10','Updates Criteria for pseudo gout','El Sayed Rageh','Égypte (Tanta)',4,'talk'),
('2026-04-24','16h10','16h25','Surgical treatment of osteonecrosis of the hip','Amouri Saadedine Hichem','Algérie (Alger)',4,'talk'),
('2026-04-24','16h25','16h40','Management of rheumatoid Wrist','Bessaa Fouad','Algérie (Alger)',4,'talk'),
('2026-04-24','16h40','17h15','Symposium SANOFI — Mucopolysaccharidosis type 1','Bencharif Imene','Algérie (Constantine)',4,'symposium'),
('2026-04-24','17h15','18h10','Débat',NULL,NULL,4,'break'),
('2026-04-24','18h10',NULL,'Pause café',NULL,NULL,0,'break'),
-- Samedi 25 Avril
('2026-04-25','08h30','08h45','Inflammatory rheumatism and work','Bordji Youcef','Algérie (Ain-Témouchent)',5,'talk'),
('2026-04-25','08h45','09h05','Diet and rheumatism','Bencharif Imene','Algérie (Constantine)',5,'talk'),
('2026-04-25','09h05','09h25','Rheumatoid Vasculitis','Huseynova Nargiz','Azerbaïdjan (Bakou)',5,'talk'),
('2026-04-25','09h25','09h45','RA-ILD','Elomir Mohammed','Arabie Saoudite (Abha)',5,'talk'),
('2026-04-25','09h45','10h05','Stress and rheumatic diseases','Ndiaye Abdou Rajack','Sénégal (Dakar)',5,'talk'),
('2026-04-25','10h05','10h35','Symposium J&J — Golimumab in inflammatory rheumatism','Dr Medjadi Mohsine','Algérie (Oran)',5,'symposium'),
('2026-04-25','10h35','10h50','Débat',NULL,NULL,5,'break'),
('2026-04-25','10h50',NULL,'Pause café',NULL,NULL,0,'break'),
('2026-04-25','11h10','11h35','Overcoming Diagnostic Delays in Axial Spondyloarthritis','Duruoz Tuncay','Turquie (Istanbul)',6,'talk'),
('2026-04-25','11h35','11h55','Structural Progression in axial Spondyloarthritis','Abi Ayad Abdelatif','Algérie (Tlemcen)',6,'talk'),
('2026-04-25','11h55','12h15','Difficult To-Treat Spondyloarthritis (SPA)','Hadiyeva Shahla','Azerbaïdjan (Bakou)',6,'talk'),
('2026-04-25','12h15','12h35','Axial spondyloarthritis associated with IBD','Sahli Hela','Tunisie',6,'talk'),
('2026-04-25','12h35','12h55','IBD and its treatment','Gamar Leila','Algérie (Alger)',6,'talk'),
('2026-04-25','12h55','13h00','Symposium Roche — Role of Tocilizumab in RA','Lamri Zahia','Algérie (Oran)',6,'symposium'),
('2026-04-25','13h00',NULL,'Débat',NULL,NULL,6,'break'),
('2026-04-25','14h30',NULL,'Clôture du congrès et cérémonie de remise des prix',NULL,NULL,0,'ceremony'),
('2026-04-25','14h30',NULL,'Déjeuner de clôture',NULL,NULL,0,'break')
ON CONFLICT DO NOTHING;

-- Update hall pour les workshops
UPDATE congress_sessions SET hall = 'Salle Mascara'  WHERE title LIKE 'Workshop 1%';
UPDATE congress_sessions SET hall = 'Salle Tlemcen'  WHERE title LIKE 'Workshop 2%';
UPDATE congress_sessions SET hall = 'Salle Chlef'    WHERE title LIKE 'Workshop 3%';
UPDATE congress_sessions SET hall = 'Salle Saida'    WHERE title LIKE 'Workshop 4%';
UPDATE congress_sessions SET hall = 'Salle Andalous' WHERE title LIKE 'Workshop 5%';
UPDATE congress_sessions SET is_zoom = TRUE WHERE speaker_name = 'El Sayed Rageh';
