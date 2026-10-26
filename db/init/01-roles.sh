#!/bin/bash
# Runs once, when the data volume is first created.
# Creates the owner and app roles; migrations in db/migrations run as pos_owner.
set -euo pipefail

psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
  -v owner_pw="$POS_OWNER_PASSWORD" -v app_pw="$POS_APP_PASSWORD" <<'SQL'
CREATE ROLE pos_owner LOGIN PASSWORD :'owner_pw';
CREATE ROLE pos_app   LOGIN PASSWORD :'app_pw';
ALTER DATABASE abarrotes_pos OWNER TO pos_owner;
REVOKE ALL ON SCHEMA public FROM PUBLIC;
GRANT USAGE ON SCHEMA public TO pos_app;
ALTER DATABASE abarrotes_pos SET timezone TO 'America/Mexico_City';
SQL
