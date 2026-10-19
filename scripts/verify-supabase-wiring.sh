#!/bin/bash
# Phase 13C.2 — verifies the Supabase configuration reaches the native app
# through the Rork-supported PUBLIC surface (generated Config.swift), and that
# the old server-side-secret pbxproj/plist workaround is fully removed:
#   Rork public variable (EXPO_PUBLIC_SUPABASE_URL / EXPO_PUBLIC_SUPABASE_ANON_KEY)
#     → generated Config.swift
#       → SupabaseClientProvider (Config.EXPO_PUBLIC_* reads)
# Run from the project root: scripts/verify-supabase-wiring.sh
set -euo pipefail
cd "$(dirname "$0")/.."

PBX="ios-gamescene-gridiron/GameSceneGridiron.xcodeproj/project.pbxproj"
PLIST="ios-gamescene-gridiron/AppInfo.plist"
CONFIG="ios-gamescene-gridiron/GameSceneGridiron/Config.swift"
PROVIDER="ios-gamescene-gridiron/GameSceneGridiron/Services/Auth/SupabaseClientProvider.swift"

fail() { echo "FAIL: $1" >&2; exit 1; }

# Generated Config.swift exposes the public Supabase variables
grep -q 'EXPO_PUBLIC_SUPABASE_URL' "$CONFIG" \
  || fail "Config.swift does not expose EXPO_PUBLIC_SUPABASE_URL"
grep -q 'EXPO_PUBLIC_SUPABASE_ANON_KEY' "$CONFIG" \
  || fail "Config.swift does not expose EXPO_PUBLIC_SUPABASE_ANON_KEY"

# The provider reads ONLY the public Config surface
grep -q 'Config.EXPO_PUBLIC_SUPABASE_URL' "$PROVIDER" \
  || fail "SupabaseClientProvider does not read EXPO_PUBLIC_SUPABASE_URL from Config"
grep -q 'Config.EXPO_PUBLIC_SUPABASE_ANON_KEY' "$PROVIDER" \
  || fail "SupabaseClientProvider does not read EXPO_PUBLIC_SUPABASE_ANON_KEY from Config"
grep -q 'plistValue(forKey: "SUPABASE' "$PROVIDER" \
  && fail "SupabaseClientProvider still reads server-side secrets from Info.plist"

# The broken pbxproj/plist workaround is fully removed
grep -q 'SUPABASE' "$PBX" \
  && fail "project.pbxproj still contains Supabase build settings"
grep -q '<key>SUPABASE_\|>$(SUPABASE_' "$PLIST" \
  && fail "AppInfo.plist still contains Supabase keys or expansions"

# The working AdMob configuration is untouched
grep -q 'ADMOB_APP_ID_VALUE = "$(ADMOB_IOS_APP_ID)"' "$PBX" \
  || fail "AdMob reference pattern missing from pbxproj"

echo "OK — Supabase uses the Rork public Config.swift path; AdMob untouched"
