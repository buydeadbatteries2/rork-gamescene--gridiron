#!/bin/bash
# Phase 13C.1 — verifies the Supabase secret-injection wiring in the REAL
# project files follows the proven AdMob pattern exactly:
#   Rork secret (SUPABASE_URL / SUPABASE_ANON_KEY)
#     → differently-named build setting (SUPABASE_URL_VALUE / SUPABASE_ANON_KEY_VALUE)
#       → AppInfo.plist expansion ($(SUPABASE_URL_VALUE) / $(SUPABASE_ANON_KEY_VALUE))
# Run from the project root: scripts/verify-supabase-wiring.sh
set -euo pipefail
cd "$(dirname "$0")/.."

PBX="ios-gamescene-gridiron/GameSceneGridiron.xcodeproj/project.pbxproj"
PLIST="ios-gamescene-gridiron/AppInfo.plist"

fail() { echo "FAIL: $1" >&2; exit 1; }

# AdMob reference pattern (proven working in the live pipeline)
grep -q 'ADMOB_APP_ID_VALUE = "$(ADMOB_IOS_APP_ID)"' "$PBX" \
  || fail "AdMob reference pattern missing from pbxproj"

# Supabase intermediary build settings — both app-target configs (Debug + Release)
[ "$(grep -c 'SUPABASE_URL_VALUE = "$(SUPABASE_URL)"' "$PBX")" -eq 2 ] \
  || fail "SUPABASE_URL_VALUE intermediary not declared in both app-target configs"
[ "$(grep -c 'SUPABASE_ANON_KEY_VALUE = "$(SUPABASE_ANON_KEY)"' "$PBX")" -eq 2 ] \
  || fail "SUPABASE_ANON_KEY_VALUE intermediary not declared in both app-target configs"

# No self-referencing settings left over from the previous attempt
grep -q 'SUPABASE_URL = "$(SUPABASE_URL)"' "$PBX" \
  && fail "self-referencing SUPABASE_URL build setting still present"
grep -q 'SUPABASE_ANON_KEY = "$(SUPABASE_ANON_KEY)"' "$PBX" \
  && fail "self-referencing SUPABASE_ANON_KEY build setting still present"

# Plist expands the intermediary build settings only — never the raw secrets
grep -q '<string>$(SUPABASE_URL_VALUE)</string>' "$PLIST" \
  || fail "AppInfo.plist does not expand SUPABASE_URL_VALUE"
grep -q '<string>$(SUPABASE_ANON_KEY_VALUE)</string>' "$PLIST" \
  || fail "AppInfo.plist does not expand SUPABASE_ANON_KEY_VALUE"
grep -q '<string>$(SUPABASE_URL)</string>' "$PLIST" \
  && fail "AppInfo.plist still references the raw SUPABASE_URL secret"
grep -q '<string>$(SUPABASE_ANON_KEY)</string>' "$PLIST" \
  && fail "AppInfo.plist still references the raw SUPABASE_ANON_KEY secret"

echo "OK — Supabase wiring matches the AdMob pattern"
