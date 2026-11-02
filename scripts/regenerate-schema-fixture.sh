#!/bin/bash
# Regenerates the SchemaFixture.swift snapshot from supabase/schema.sql.
# The test runner only receives the app folder, so the fixture pins the
# schema for SchemaHardeningTests. Run after every schema.sql edit:
#   scripts/regenerate-schema-fixture.sh
set -euo pipefail
cd "$(dirname "$0")/.."

SCHEMA="supabase/schema.sql"
FIXTURE="ios-gamescene-gridiron/GameSceneGridironTests/SchemaFixture.swift"

{
  cat <<'HEAD'
import Foundation

/// Byte-identical snapshot of `supabase/schema.sql` (repo root). The test
/// runner only receives the app folder — the repo-root `supabase/` directory
/// is not part of the uploaded source — so the tests pin this copy. Keep the
/// two files in sync: schema.sql is what gets pasted into Supabase, this
/// fixture is what SchemaHardeningTests validates. Regenerate with
/// scripts/regenerate-schema-fixture.sh after editing schema.sql.
enum SchemaFixture {
    static let sql = #"""
HEAD
  cat "$SCHEMA"
  printf '"""#\n}\n'
} > "$FIXTURE"

echo "Regenerated $FIXTURE from $SCHEMA"

# Phase 14: the ranked-result Edge Function is pinned the same way so the
# security tests can assert its JWT / idempotency / no-score rules.
EDGE="supabase/functions/submit-ranked-result/index.ts"
START="supabase/functions/start-ranked-match/index.ts"
EDGE_FIXTURE="ios-gamescene-gridiron/GameSceneGridironTests/EdgeFunctionFixture.swift"
{
  cat <<'HEAD'
import Foundation

/// Byte-identical snapshots of the ranked Edge Functions
/// (`supabase/functions/submit-ranked-result/index.ts` and, Phase 14B,
/// `supabase/functions/start-ranked-match/index.ts`).
/// Regenerate with scripts/regenerate-schema-fixture.sh after editing them.
enum EdgeFunctionFixture {
    static let submitRankedResult = #"""
HEAD
  cat "$EDGE"
  printf '"""#\n\n    static let startRankedMatch = #"""\n'
  cat "$START"
  printf '"""#\n}\n'
} > "$EDGE_FIXTURE"

echo "Regenerated $EDGE_FIXTURE from $EDGE and $START"

# Phase 15A: the Versus Edge Functions are pinned the same way so the Swift
# tests can assert their JWT-only / difficulty-only / no-score rules.
FIND="supabase/functions/find-versus-match/index.ts"
SUBMIT="supabase/functions/submit-versus-result/index.ts"
VERSUS_FIXTURE="ios-gamescene-gridiron/GameSceneGridironTests/VersusEdgeFunctionFixture.swift"
{
  cat <<'HEAD'
import Foundation

/// Byte-identical snapshots of the Phase 15A Versus Edge Functions
/// (`supabase/functions/find-versus-match/index.ts` and
/// `supabase/functions/submit-versus-result/index.ts`).
/// Regenerate with scripts/regenerate-schema-fixture.sh after editing them.
enum VersusEdgeFunctionFixture {
    static let findVersusMatch = #"""
HEAD
  cat "$FIND"
  printf '"""#\n\n    static let submitVersusResult = #"""\n'
  cat "$SUBMIT"
  printf '"""#\n}\n'
} > "$VERSUS_FIXTURE"

echo "Regenerated $VERSUS_FIXTURE from $FIND and $SUBMIT"
