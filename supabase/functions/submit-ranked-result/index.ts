// GameScene: Gridiron — Phase 14 ranked result verification.
//
// POST /functions/v1/submit-ranked-result  (Authorization: Bearer <user JWT>)
//
// Trust model:
//   * The user is derived from the JWT ONLY. A body user_id that differs is
//     rejected — it is never an authority.
//   * The client never sends a score. This function validates the raw game
//     facts against the PRIVATE competitive_cases solutions, then calls
//     record_verified_ranked_result (service_role only), which computes the
//     score from the single ranked_scoring_config row and updates career
//     stats. No scoring constants live here.
//   * Idempotent by match_id: a retried submission returns the stored result.
//   * The service-role key comes from the function environment and never
//     leaves the server.
//
// Responses:
//   200 {"status":"verified","result_id","final_score","duplicate"}
//   4xx {"status":"rejected","reason"}       — final; the client never retries
//   401 / 429 / 5xx                          — transient; the client retries
import { createClient } from "jsr:@supabase/supabase-js@2";

const DIFFICULTIES = ["rookie", "pro", "all_pro", "hall_of_famer"] as const;
type Difficulty = (typeof DIFFICULTIES)[number];
const PROFILES = ["rookie", "veteran", "fast", "powerful", "overrated"];
const REGULATION_QUARTERS = 4;
const OVERTIME_INDEX = 4;
const MAX_PLACEMENTS = 8;
const MAX_FUTURE_SKEW_MS = 5 * 60 * 1000;
const MAX_GAME_AGE_MS = 30 * 24 * 60 * 60 * 1000;
const MIN_GAME_DURATION_MS = 20 * 1000;
const MAX_BODY_BYTES = 32 * 1024;
const DEFAULT_SUBMISSIONS_PER_HOUR = 30;

interface Placement {
  player_key: string;
  slot_key: string;
  profile: string;
}

interface CaseResult {
  case_id: string;
  case_version: number;
  quarter_index: number;
  outcome: "solved" | "failed";
  hints_used: number;
  wrong_placements: number;
  placements: Placement[];
}

interface Payload {
  match_id: string;
  user_id: string;
  season_id: string | null;
  game_number: number;
  difficulty: Difficulty;
  started_at: string;
  completed_at: string;
  regulation_quarters_solved: number;
  regulation_quarters_lost: number;
  game_won: boolean;
  overtime_played: boolean;
  overtime_won: boolean;
  wrong_placements: number;
  hints_used: number;
  case_results: CaseResult[];
  game_version: string;
}

class Rejection extends Error {
  constructor(public reason: string) {
    super(reason);
  }
}

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const KEY_RE = /^[A-Za-z0-9_-]{1,64}$/;

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

function require(condition: boolean, reason: string): asserts condition {
  if (!condition) throw new Rejection(reason);
}

// ---------------------------------------------------------------------------
// Structural validation (pure)
// ---------------------------------------------------------------------------

export function validateStructure(body: unknown, now: number): Payload {
  require(typeof body === "object" && body !== null, "malformed_body");
  const p = body as Payload;
  require(typeof p.match_id === "string" && UUID_RE.test(p.match_id), "invalid_match_id");
  require(typeof p.user_id === "string" && UUID_RE.test(p.user_id), "invalid_user_id");
  require(p.season_id === null || p.season_id === undefined ||
    (typeof p.season_id === "string" && UUID_RE.test(p.season_id)), "invalid_season_id");
  require(isInt(p.game_number, 1, 12), "invalid_game_number");
  require(DIFFICULTIES.includes(p.difficulty), "invalid_difficulty");
  require(typeof p.game_version === "string" && p.game_version.length <= 40, "invalid_game_version");
  require(typeof p.game_won === "boolean" && typeof p.overtime_played === "boolean" &&
    typeof p.overtime_won === "boolean", "invalid_flags");
  require(isInt(p.regulation_quarters_solved, 0, 4) && isInt(p.regulation_quarters_lost, 0, 4),
    "invalid_quarters");
  require(isInt(p.hints_used, 0, 500) && isInt(p.wrong_placements, 0, 500), "invalid_totals");

  // Timestamps: real, ordered, plausible.
  const started = Date.parse(p.started_at);
  const completed = Date.parse(p.completed_at);
  require(Number.isFinite(started) && Number.isFinite(completed), "invalid_timestamps");
  require(started < completed, "invalid_timestamps");
  require(completed <= now + MAX_FUTURE_SKEW_MS, "completed_in_future");
  require(started >= now - MAX_GAME_AGE_MS, "result_too_old");
  require(completed - started >= MIN_GAME_DURATION_MS, "implausible_duration");

  // Case results: 4 regulation (+1 overtime), distinct cases, ordered indexes.
  require(Array.isArray(p.case_results), "invalid_case_results");
  require(p.case_results.length === 4 || p.case_results.length === 5, "invalid_case_count");
  const caseIDs = new Set<string>();
  p.case_results.forEach((c, i) => {
    require(typeof c === "object" && c !== null, "invalid_case_results");
    require(typeof c.case_id === "string" && KEY_RE.test(c.case_id), "invalid_case_id");
    require(isInt(c.case_version, 1, 100000), "invalid_case_version");
    require(c.quarter_index === i && isInt(c.quarter_index, 0, OVERTIME_INDEX), "invalid_quarter_index");
    require(c.outcome === "solved" || c.outcome === "failed", "invalid_outcome");
    require(isInt(c.hints_used, 0, 100) && isInt(c.wrong_placements, 0, 100), "invalid_case_totals");
    require(Array.isArray(c.placements) && c.placements.length <= MAX_PLACEMENTS, "invalid_placements");
    const players = new Set<string>();
    const slots = new Set<string>();
    for (const pl of c.placements) {
      require(typeof pl === "object" && pl !== null && typeof pl.player_key === "string" &&
        typeof pl.slot_key === "string" && KEY_RE.test(pl.player_key) && KEY_RE.test(pl.slot_key) &&
        PROFILES.includes(pl.profile), "invalid_placement");
      require(!players.has(pl.player_key) && !slots.has(pl.slot_key), "duplicate_placement");
      players.add(pl.player_key);
      slots.add(pl.slot_key);
    }
    require(!caseIDs.has(c.case_id), "duplicate_case");
    caseIDs.add(c.case_id);
  });

  // The summary must be exactly what the per-case results say.
  const regulation = p.case_results.slice(0, REGULATION_QUARTERS);
  const overtime = p.case_results[OVERTIME_INDEX];
  const solved = regulation.filter((c) => c.outcome === "solved").length;
  const overtimePlayed = solved === 2;
  require((overtime !== undefined) === overtimePlayed, "overtime_mismatch");
  const overtimeWon = overtime?.outcome === "solved";
  require(p.regulation_quarters_solved === solved, "summary_mismatch");
  require(p.regulation_quarters_lost === REGULATION_QUARTERS - solved, "summary_mismatch");
  require(p.overtime_played === overtimePlayed && p.overtime_won === overtimeWon, "summary_mismatch");
  require(p.game_won === (solved >= 3 || overtimeWon), "summary_mismatch");
  const hints = p.case_results.reduce((sum, c) => sum + c.hints_used, 0);
  const wrong = p.case_results.reduce((sum, c) => sum + c.wrong_placements, 0);
  require(p.hints_used === hints && p.wrong_placements === wrong, "summary_mismatch");
  return p;
}

// ---------------------------------------------------------------------------
// Solution validation against the PRIVATE catalog (pure)
// ---------------------------------------------------------------------------

/// Easier tiers may trim one missing player (rookie always; pro in the
/// season's opening weeks) — mirrors CaseDifficultyAdapter.
export function trimAllowed(difficulty: Difficulty, gameNumber: number): boolean {
  return difficulty === "rookie" || (difficulty === "pro" && gameNumber <= 3);
}

function key(p: Placement): string {
  return `${p.player_key}|${p.slot_key}|${p.profile}`;
}

export function validateCaseAgainstSolution(
  result: CaseResult,
  solution: Placement[],
  canTrim: boolean,
): void {
  require(Array.isArray(solution) && solution.length > 0, "solution_missing");
  const truth = new Set(solution.map(key));
  // Every submitted placement must be a correct one (wrong ones are never
  // recorded as placements — they count only as wrong_placements).
  for (const placement of result.placements) {
    require(truth.has(key(placement)), "placement_mismatch");
  }
  const count = result.placements.length;
  if (result.outcome === "solved") {
    const full = count === solution.length;
    const trimmed = canTrim && solution.length > 4 && count === solution.length - 1;
    require(full || trimmed, "solved_case_incomplete");
  } else {
    require(count <= solution.length - 1, "failed_case_complete");
  }
}

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== "POST") return json(405, { status: "error", reason: "method_not_allowed" });

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) return json(500, { status: "error", reason: "server_misconfigured" });

  // 1. Authenticate: the user comes from the JWT, never from the body.
  const authHeader = req.headers.get("Authorization") ?? "";
  const token = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : "";
  if (!token) return json(401, { status: "error", reason: "unauthorized" });
  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: userData, error: userError } = await admin.auth.getUser(token);
  const userID = userData?.user?.id;
  if (userError || !userID) return json(401, { status: "error", reason: "unauthorized" });

  const logAttempt = async (matchID: string | null, outcome: string, reason: string | null) => {
    await admin.from("ranked_submission_attempts").insert({
      user_id: userID,
      match_id: matchID,
      outcome,
      reason,
    });
  };

  // 2. Rate limit (per user, rolling hour).
  const { data: config } = await admin
    .from("ranked_scoring_config")
    .select("submissions_per_hour")
    .eq("id", 1)
    .maybeSingle();
  const perHour = config?.submissions_per_hour ?? DEFAULT_SUBMISSIONS_PER_HOUR;
  const since = new Date(Date.now() - 60 * 60 * 1000).toISOString();
  const { count: recent } = await admin
    .from("ranked_submission_attempts")
    .select("id", { count: "exact", head: true })
    .eq("user_id", userID)
    .gte("created_at", since);
  if ((recent ?? 0) >= perHour) return json(429, { status: "error", reason: "rate_limited" });

  // 3. Parse.
  const raw = await req.text();
  if (raw.length > MAX_BODY_BYTES) return reject("body_too_large", 413);
  let body: unknown;
  try {
    body = JSON.parse(raw);
  } catch {
    await logAttempt(null, "rejected", "malformed_body");
    return reject("malformed_body", 400);
  }

  let payload: Payload;
  try {
    payload = validateStructure(body, Date.now());
  } catch (error) {
    const reason = error instanceof Rejection ? error.reason : "malformed_body";
    await logAttempt(null, "rejected", reason);
    return reject(reason);
  }

  // 4. The body's user_id is informational only — a mismatch is rejected.
  if (payload.user_id.toLowerCase() !== userID.toLowerCase()) {
    await logAttempt(payload.match_id, "rejected", "user_mismatch");
    return reject("user_mismatch", 403);
  }

  // 5. Idempotency: an already-recorded match returns its stored result.
  const { data: existing } = await admin
    .from("ranked_game_results")
    .select("id, user_id, final_score")
    .eq("match_id", payload.match_id)
    .maybeSingle();
  if (existing) {
    if (existing.user_id !== userID) {
      await logAttempt(payload.match_id, "rejected", "match_id_conflict");
      return reject("match_id_conflict", 409);
    }
    await logAttempt(payload.match_id, "duplicate", null);
    return json(200, {
      status: "verified",
      result_id: existing.id,
      final_score: existing.final_score,
      duplicate: true,
    });
  }

  // 6. Validate every case against the private catalog.
  const caseIDs = payload.case_results.map((c) => c.case_id);
  const { data: cases, error: casesError } = await admin
    .from("competitive_cases")
    .select("case_id, case_version, active, competitive_eligible, solutions")
    .in("case_id", caseIDs);
  if (casesError) return json(503, { status: "error", reason: "catalog_unavailable" });
  const byID = new Map((cases ?? []).map((c) => [c.case_id as string, c]));
  const canTrim = trimAllowed(payload.difficulty, payload.game_number);
  try {
    for (const result of payload.case_results) {
      const entry = byID.get(result.case_id);
      require(entry !== undefined, "unknown_case");
      require(entry.active === true && entry.competitive_eligible === true, "case_not_eligible");
      require(entry.case_version === result.case_version, "case_version_mismatch");
      const solution = (entry.solutions as Record<string, Placement[]>)?.[payload.difficulty];
      validateCaseAgainstSolution(result, solution, canTrim);
    }
  } catch (error) {
    const reason = error instanceof Rejection ? error.reason : "validation_failed";
    await logAttempt(payload.match_id, "rejected", reason);
    return reject(reason);
  }

  // 7. Record — the database computes the score and updates career stats.
  const { data: recorded, error: recordError } = await admin.rpc("record_verified_ranked_result", {
    p_user_id: userID,
    p_match_id: payload.match_id,
    p_season_id: payload.season_id ?? null,
    p_game_number: payload.game_number,
    p_difficulty: payload.difficulty,
    p_regulation_quarters_solved: payload.regulation_quarters_solved,
    p_game_won: payload.game_won,
    p_overtime_played: payload.overtime_played,
    p_overtime_won: payload.overtime_won,
    p_wrong_placements: payload.wrong_placements,
    p_hints_used: payload.hints_used,
    p_case_results: payload.case_results,
    p_started_at: payload.started_at,
    p_completed_at: payload.completed_at,
    p_game_version: payload.game_version,
  });
  if (recordError) {
    const message = recordError.message ?? "";
    for (const reason of ["MATCH_ID_CONFLICT", "SEASON_DIFFICULTY_MISMATCH", "DUPLICATE_SEASON_GAME", "INVALID_DIFFICULTY"]) {
      if (message.includes(reason)) {
        await logAttempt(payload.match_id, "rejected", reason.toLowerCase());
        return reject(reason.toLowerCase(), 409);
      }
    }
    await logAttempt(payload.match_id, "error", "record_failed");
    return json(503, { status: "error", reason: "record_failed" });
  }
  const row = Array.isArray(recorded) ? recorded[0] : recorded;
  await logAttempt(payload.match_id, row?.duplicate ? "duplicate" : "verified", null);
  return json(200, {
    status: "verified",
    result_id: row?.result_id,
    final_score: row?.final_score,
    duplicate: row?.duplicate ?? false,
  });
});
