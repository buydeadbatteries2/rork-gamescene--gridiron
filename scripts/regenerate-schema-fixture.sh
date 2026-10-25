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
EDGE_FIXTURE="ios-gamescene-gridiron/GameSceneGridironTests/EdgeFunctionFixture.swift"
{
  cat <<'HEAD'
import Foundation

/// Byte-identical snapshot of `supabase/functions/submit-ranked-result/index.ts`.
/// Regenerate with scripts/regenerate-schema-fixture.sh after editing it.
enum EdgeFunctionFixture {
    static let submitRankedResult = #"""
HEAD
  cat "$EDGE"
  printf '"""#\n}\n'
} > "$EDGE_FIXTURE"

echo "Regenerated $EDGE_FIXTURE from $EDGE"
