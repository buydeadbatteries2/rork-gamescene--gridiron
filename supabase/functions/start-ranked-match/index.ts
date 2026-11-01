// GameScene: Gridiron — Phase 14B ranked match assignment.
//
// POST /functions/v1/start-ranked-match  (Authorization: Bearer <user JWT>)
// Body: {"season_id": "<uuid>" | null, "game_number": 1-12, "difficulty": "rookie"|"pro"|"all_pro"|"hall_of_famer"}
//
// Trust model:
//   * The user comes from the JWT ONLY. Any user_id in the body is ignored.
//   * The SERVER owns seasons and case selection. issue_ranked_match_assignment
//     (service_role only, SECURITY DEFINER, search_path='') validates or
//     creates the season (season_id null = new season, game 1 only; the
//     difficulty is locked at creation), checks the game window, selects the
//     five cases from the private catalog with a server-random seed, snapshots
//     the EXACT adapted solutions and persists the assignment with a server
//     match_id. Clients can neither insert nor update assignments.
//   * The response carries ONLY what the client needs to play: match id,
//     season id, game number, difficulty, case ids + versions, timestamps and
//     catalog fingerprint. Never solutions, the adapter variant or the seed.
//   * Offline policy A: the client prefetches at most
//     ranked_scoring_config.assignment_prefetch_games assignments ahead of its
//     last recorded game (GAME_OUT_OF_WINDOW beyond that). A game played
//     without an assignment is unranked.
//   * Re-requesting the same (season, game) returns the live assignment
//     (reused=true) — idempotent for retries.
//   * Bundled case solutions ship inside the app and are NOT secret; this is
//     integrity/consistency checking, not anti-cheat.
//
// Responses:
//   200 {"status":"assigned", "assignment": {...}}
//   4xx {"status":"rejected","reason"}   — final for this request
//   401 / 429 / 5xx                      — transient; the client may retry
import { createClient } from "jsr:@supabase/supabase-js@2";

const DIFFICULTIES = ["rookie", "pro", "all_pro", "hall_of_famer"] as const;
type Difficulty = (typeof DIFFICULTIES)[number];
const MAX_BODY_BYTES = 2 * 1024;
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export interface StartRequest {
  season_id: string | null;
  game_number: number;
  difficulty: Difficulty;
}

class Rejection extends Error {
  constructor(public reason: string) {
    super(reason);
  }
}

function json(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function reject(reason: string, status = 422): Response {
  return json(status, { status: "rejected", reason });
}

function isInt(value: unknown, min: number, max: number): value is number {
  return typeof value === "number" && Number.isInteger(value) && value >= min && value <= max;
}

function ensure(condition: boolean, reason: string): asserts condition {
  if (!condition) throw new Rejection(reason);
}

/// Structural validation only (pure). The database is the authority for
/// season ownership, difficulty lock, game window and case selection.
export function validateStartRequest(body: unknown): StartRequest {
  ensure(typeof body === "object" && body !== null && !Array.isArray(body), "malformed_body");
  const p = body as Record<string, unknown>;
  const season = p.season_id ?? null;
  ensure(season === null || (typeof season === "string" && UUID_RE.test(season)), "invalid_season_id");
  ensure(isInt(p.game_number, 1, 12), "invalid_game_number");
  ensure(DIFFICULTIES.includes(p.difficulty as Difficulty), "invalid_difficulty");
  // A new season always starts at game 1.
  ensure(season !== null || p.game_number === 1, "season_required");
  return {
    season_id: season as string | null,
    game_number: p.game_number as number,
    difficulty: p.difficulty as Difficulty,
  };
}

/// Database error → (reason, HTTP status). Unknown errors are transient (503).
export const ISSUE_ERRORS: ReadonlyArray<readonly [string, number]> = [
  ["SEASON_REQUIRED", 409],
  ["SEASON_NOT_FOUND", 404],
  ["SEASON_CONFLICT", 403],
  ["SEASON_DIFFICULTY_MISMATCH", 409],
  ["SEASON_CLOSED", 409],
  ["GAME_ALREADY_RECORDED", 409],
  ["GAME_OUT_OF_WINDOW", 409],
  ["INVALID_GAME_NUMBER", 422],
  ["INVALID_DIFFICULTY", 422],
  ["INVALID_ARGUMENTS", 422],
  ["CATALOG_NOT_LOADED", 503],
  ["CATALOG_POOL_TOO_SMALL", 503],
  ["SOLUTION_MISSING", 503],
  ["SCORING_CONFIG_MISSING", 503],
];

export function mapIssueError(message: string): { reason: string; status: number } {
  for (const [code, status] of ISSUE_ERRORS) {
    if (message.includes(code)) return { reason: code.toLowerCase(), status };
  }
  return { reason: "assignment_failed", status: 503 };
}

/// ISO-8601 with millisecond precision (Postgres returns microseconds).
function isoMillis(value: unknown): unknown {
  const parsed = typeof value === "string" ? Date.parse(value) : NaN;
  return Number.isFinite(parsed) ? new Date(parsed).toISOString() : value;
}

/// Whitelist of fields returned to the client.
export function publicAssignment(row: Record<string, unknown>): Record<string, unknown> {
  return {
    assignment_id: row.assignment_id,
    match_id: row.match_id,
    season_id: row.season_id,
    game_number: row.game_number,
    difficulty: row.difficulty,
    case_ids: row.case_ids,
    case_versions: row.case_versions,
    issued_at: isoMillis(row.issued_at),
    expires_at: isoMillis(row.expires_at),
    catalog_fingerprint: row.catalog_fingerprint,
    reused: row.reused === true,
  };
}

Deno.serve(async (req: Request): Promise<Response> => {
  // 1. Method.
  if (req.method !== "POST") return json(405, { status: "error", reason: "method_not_allowed" });

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) return json(500, { status: "error", reason: "server_misconfigured" });

  // 2. Authenticate: the user comes from the JWT, never from the body.
  const authHeader = req.headers.get("Authorization") ?? "";
  const token = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : "";
  if (!token) return json(401, { status: "error", reason: "unauthorized" });
  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: userData, error: userError } = await admin.auth.getUser(token);
  const userID = userData?.user?.id;
  if (userError || !userID) return json(401, { status: "error", reason: "unauthorized" });

  // 3. Declared size precheck BEFORE reading the body.
  const declared = Number(req.headers.get("Content-Length") ?? "0");
  if (Number.isFinite(declared) && declared > MAX_BODY_BYTES) return reject("body_too_large", 413);

  // 4. Atomic per-user rate limit ('assign' bucket).
  const { data: allowed, error: limitError } = await admin.rpc("consume_ranked_rate_limit", {
    p_user_id: userID,
    p_bucket: "assign",
  });
  if (limitError) return json(503, { status: "error", reason: "rate_limit_unavailable" });
  if (allowed !== true) return json(429, { status: "error", reason: "rate_limited" });

  // 5. Read with a post-read bound (Content-Length may be absent or wrong).
  const raw = await req.text();
  if (new TextEncoder().encode(raw).length > MAX_BODY_BYTES) return reject("body_too_large", 413);
  let body: unknown;
  try {
    body = JSON.parse(raw);
  } catch {
    return reject("malformed_body", 400);
  }

  let request: StartRequest;
  try {
    request = validateStartRequest(body);
  } catch (error) {
    return reject(error instanceof Rejection ? error.reason : "malformed_body");
  }

  // 6. Issue (or reuse) the assignment — the database does all checks.
  const { data, error } = await admin.rpc("issue_ranked_match_assignment", {
    p_user_id: userID,
    p_season_id: request.season_id,
    p_game_number: request.game_number,
    p_difficulty: request.difficulty,
  });
  if (error) {
    const mapped = mapIssueError(error.message ?? "");
    if (mapped.status >= 500) return json(mapped.status, { status: "error", reason: mapped.reason });
    return reject(mapped.reason, mapped.status);
  }
  const row = (Array.isArray(data) ? data[0] : data) as Record<string, unknown> | undefined;
  if (!row) return json(503, { status: "error", reason: "assignment_failed" });
  return json(200, { status: "assigned", assignment: publicAssignment(row) });
});
