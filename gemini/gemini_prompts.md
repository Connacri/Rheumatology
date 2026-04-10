# PROMPTS GEMINI MCP — migration_mcp.sql
# Copie-colle ces prompts dans le terminal Gemini de Android Studio
# après avoir configuré ~/.gemini/settings.json

# ─────────────────────────────────────────────
# BLOC 1 — Extensions
# ─────────────────────────────────────────────
Exécute cette requête SQL sur la base de données supabase-db :
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "moddatetime";

# ─────────────────────────────────────────────
# BLOC 2 — Table profiles
# ─────────────────────────────────────────────
Exécute ce SQL : [coller BLOC 2 du fichier migration_mcp.sql]

# ─────────────────────────────────────────────
# Vérification rapide après chaque bloc
# ─────────────────────────────────────────────
Interroge la base supabase-db : SELECT table_name FROM information_schema.tables WHERE table_schema = 'public';

# ─────────────────────────────────────────────
# Vérification finale (BLOC 12)
# ─────────────────────────────────────────────
Interroge la base supabase-db :
SELECT t.table_name, COUNT(p.policyname) AS nb_policies
FROM information_schema.tables t
LEFT JOIN pg_policies p ON p.tablename = t.table_name AND p.schemaname = 'public'
WHERE t.table_schema = 'public' AND t.table_type = 'BASE TABLE'
GROUP BY t.table_name ORDER BY t.table_name;
