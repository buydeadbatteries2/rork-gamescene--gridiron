#!/usr/bin/env python3
"""
Phase 14B — generator-side tests for the competitive catalog.

  python3 scripts/test_competitive_catalog.py

Covers: version history (fingerprint change without bump fails, version
regression fails, reverts get a NEW version), checksum scope (client_bundled
only), and the exact adapter variants (no arbitrary trimmed subsets).
"""

import os, sys, unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import export_competitive_catalog as ex  # noqa: E402
import case_adapter_port as adapter  # noqa: E402
import case_difficulty_features as cdf  # noqa: E402


def entry(version, fp, history=None):
    return {"version": version, "fingerprint": fp,
            "history": history or [{"version": version, "fingerprint": fp}]}


class VersionHistoryTests(unittest.TestCase):
    def test_new_case_starts_at_1(self):
        st = ex.compute_versions({"a": "f1"}, {})
        self.assertEqual(st["a"]["version"], 1)
        self.assertEqual(st["a"]["history"], [{"version": 1, "fingerprint": "f1"}])

    def test_unchanged_keeps_version(self):
        st = ex.compute_versions({"a": "f1"}, {"a": entry(3, "f1", [{"version": 1, "fingerprint": "f0"}, {"version": 3, "fingerprint": "f1"}])})
        self.assertEqual(st["a"]["version"], 3)

    def test_changed_fingerprint_bumps(self):
        st = ex.compute_versions({"a": "f2"}, {"a": entry(1, "f1")})
        self.assertEqual(st["a"]["version"], 2)
        self.assertEqual([h["version"] for h in st["a"]["history"]], [1, 2])

    def test_revert_to_old_content_gets_new_version(self):
        old = {"a": entry(2, "f2", [{"version": 1, "fingerprint": "f1"}, {"version": 2, "fingerprint": "f2"}])}
        st = ex.compute_versions({"a": "f1"}, old)
        self.assertEqual(st["a"]["version"], 3)

    def test_legacy_manifest_shape_accepted(self):
        st = ex.compute_versions({"a": "f1"}, {"a": {"version": 4, "fingerprint": "f1"}})
        self.assertEqual(st["a"]["version"], 4)
        self.assertEqual(st["a"]["history"], [{"version": 4, "fingerprint": "f1"}])

    def test_fingerprint_change_without_bump_fails(self):
        with self.assertRaisesRegex(ex.ManifestError, "CHANGED_WITHOUT_VERSION_BUMP"):
            ex.verify_transition({"a": entry(1, "f1")}, {"a": entry(1, "f2")})

    def test_history_rewrite_without_bump_fails(self):
        old = {"a": entry(2, "f2", [{"version": 1, "fingerprint": "f1"}, {"version": 2, "fingerprint": "f2"}])}
        new = {"a": entry(3, "f3", [{"version": 1, "fingerprint": "fX"}, {"version": 2, "fingerprint": "f2"}, {"version": 3, "fingerprint": "f3"}])}
        with self.assertRaisesRegex(ex.ManifestError, "CHANGED_WITHOUT_VERSION_BUMP"):
            ex.verify_transition(old, new)

    def test_version_regression_fails(self):
        with self.assertRaisesRegex(ex.ManifestError, "CASE_VERSION_REGRESSION"):
            ex.verify_transition({"a": entry(3, "f3")}, {"a": entry(2, "f3")})

    def test_manifest_history_regression_fails(self):
        bad = {"a": entry(2, "f2", [{"version": 2, "fingerprint": "f1"}, {"version": 2, "fingerprint": "f2"}])}
        with self.assertRaisesRegex(ex.ManifestError, "CASE_VERSION_REGRESSION"):
            ex.verify_manifest(bad)

    def test_manifest_current_must_be_last_history(self):
        bad = {"a": entry(2, "f2", [{"version": 1, "fingerprint": "f1"}])}
        with self.assertRaises(ex.ManifestError):
            ex.verify_manifest(bad)

    def test_retired_case_keeps_history(self):
        st = ex.compute_versions({}, {"a": entry(2, "f2", [{"version": 1, "fingerprint": "f1"}, {"version": 2, "fingerprint": "f2"}])})
        self.assertTrue(st["a"]["retired"])
        st2 = ex.compute_versions({"a": "f9"}, st)
        self.assertEqual(st2["a"]["version"], 3)

    def test_committed_manifest_is_valid(self):
        import json
        state = json.load(open(ex.VERSIONS_PATH))
        self.assertTrue(ex.verify_manifest(state))


class CatalogScopeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.cases = ex.parse_cases()
        state = __import__("json").load(open(ex.VERSIONS_PATH))
        for c in cls.cases:
            c["fingerprint"] = state[c["id"]]["fingerprint"]
            c["version"] = state[c["id"]]["version"]

    def test_checksum_lines_are_client_bundled_only(self):
        for c in self.cases:
            self.assertIn("|client_bundled|", ex.canonical_line(c))

    def test_generated_sql_scopes_retirement_and_meta(self):
        sql = open(os.path.join(ex.SUPABASE, "competitive_catalog.sql")).read()
        self.assertIn("where distribution = 'client_bundled'\n  and case_id not in (", sql)
        self.assertIn("competitive_catalog_meta (distribution, case_count", sql)
        self.assertIn("on conflict (distribution) do update", sql)
        self.assertIn("competitive_catalog_checksum('client_bundled')", sql)

    def test_checksum_matches_swift_constant(self):
        swift = open(os.path.join(ex.DATA, "CompetitiveCaseCatalog.swift")).read()
        self.assertIn(f'catalogChecksum = "{ex.catalog_checksum(self.cases)}"', swift)


class AdapterVariantTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.lib = cdf.parse_library()

    def test_variant_mapping(self):
        self.assertEqual([adapter.variant_for("rookie", w) for w in range(1, 13)], ["rookie"] * 12)
        self.assertEqual([adapter.variant_for("pro", w) for w in range(1, 13)], ["pro_early"] * 3 + ["pro"] * 9)
        self.assertEqual({adapter.variant_for("allPro", w) for w in range(1, 13)}, {"all_pro"})
        self.assertEqual({adapter.variant_for("hallOfFamer", w) for w in range(1, 13)}, {"hall_of_famer"})

    def test_trim_is_exact_single_player(self):
        for c in self.lib:
            full = len(c["solution"])
            for v, sol in adapter.variant_solutions(c).items():
                if v in ("rookie", "pro_early") and full > 4:
                    self.assertEqual(len(sol), full - 1, (c["id"], v))
                else:
                    self.assertEqual(len(sol), full, (c["id"], v))

    def test_other_trimmed_subsets_are_not_the_adapted_solution(self):
        """Exactly one trimmed subset is THE adapted solution; the others differ."""
        checked = 0
        for c in self.lib:
            if len(c["solution"]) <= 4:
                continue
            exact = adapter.adapted_solution(c, "rookie")
            exact_players = {p for p, _, _ in exact}
            others = [p for p, _, _ in c["solution"] if p in exact_players]
            self.assertEqual(len(others), len(c["solution"]) - 1)
            checked += 1
        self.assertEqual(checked, 45)

    def test_full_pool_variants_are_authored(self):
        for c in self.lib:
            authored = [tuple(s) for s in c["solution"]]
            self.assertEqual([tuple(s) for s in adapter.adapted_solution(c, "hall_of_famer")], authored)
            self.assertEqual([tuple(s) for s in adapter.adapted_solution(c, "all_pro")], authored)


if __name__ == "__main__":
    unittest.main(verbosity=1)
