#!/usr/bin/env bash
# Runs migrations + SQL tests against a throwaway local Postgres (15+), without the Supabase CLI.
# Usage: ./supabase/tests/run_local.sh      (needs initdb/pg_ctl/psql on PATH or PG_BIN set)
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
PG_BIN="${PG_BIN:-$(ls -d /usr/lib/postgresql/*/bin 2>/dev/null | sort -V | tail -1)}"
export PATH="$PG_BIN:$PATH"
DATA="$(mktemp -d)"; PORT="${PGPORT_TEST:-55432}"
cleanup() { "${RUNAS[@]}" "export PATH='$PG_BIN':\$PATH; pg_ctl -D '$DATA' -m immediate stop" >/dev/null 2>&1 || true; rm -rf "$DATA"; }
trap cleanup EXIT
if [ "$(id -u)" = "0" ]; then RUNAS=(su postgres -s /bin/bash -c); chown -R postgres "$DATA"; else RUNAS=(bash -c); fi
"${RUNAS[@]}" "export PATH='$PG_BIN':$PATH; initdb -D '$DATA' -U postgres -A trust >/dev/null && pg_ctl -D '$DATA' -o '-p $PORT -k /tmp' -l '$DATA/log' start >/dev/null"
PSQL=(psql -h /tmp -p "$PORT" -U postgres -v ON_ERROR_STOP=1 -q)
"${PSQL[@]}" -c "create database halisaha_test" >/dev/null
DB=("${PSQL[@]}" -d halisaha_test)
"${DB[@]}" -f "$HERE/00_supabase_shim.sql"
for f in "$ROOT"/migrations/*.sql; do echo "migrate: $(basename "$f")"; "${DB[@]}" -f "$f" >/dev/null; done
"${DB[@]}" -f "$ROOT/seed.sql" >/dev/null; echo "seed: ok"
for t in "$HERE"/[1-9]*.sql; do echo "test:    $(basename "$t")"; "${DB[@]}" -f "$t"; done
echo "ALL SQL TESTS PASSED"
