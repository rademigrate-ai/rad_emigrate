import json
import tempfile
import unittest
from pathlib import Path

from scripts.production_forward_package import build_package


def function(name, definition, identity="", result="jsonb"):
    return {
        "schema": "private" if name.startswith("rad_") else "public",
        "name": name,
        "identity": identity,
        "arguments": identity,
        "result": result,
        "definition": definition,
        "body_md5": "a" * 32,
        "owner": "postgres",
        "settings": ['search_path=""'],
        "security_definer": True,
        "grants": [],
    }


def table(name, columns, indexes=None):
    return {
        "schema": "public",
        "name": name,
        "columns": columns,
        "constraints": [],
        "indexes": indexes or [],
        "triggers": [],
        "policies": [],
        "grants": [],
        "rls": True,
        "force_rls": False,
    }


def column(name, generated="", default=None, not_null=False):
    return {
        "name": name,
        "type": "text",
        "identity": "",
        "generated": generated,
        "default": default,
        "not_null": not_null,
    }


class ForwardPackageTest(unittest.TestCase):
    def package(self, production, candidate):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        root = Path(temporary.name)
        inputs, output = root / "inputs", root / "out"
        inputs.mkdir()
        values = {
            "production_catalog.json": production,
            "candidate_catalog.json": candidate,
            "candidate_contract_schemas.json": [],
            "production_contract_schemas.json": [],
            "production_preconditions.json": {"heads": 0},
        }
        for name, value in values.items():
            (inputs / name).write_text(json.dumps(value), encoding="utf8")
        manifest = build_package(inputs, output, "a" * 40, roots=("reader",))
        return manifest, (output / "forward_body.sql").read_text(), output

    def test_generated_column_dependency_precedes_table_and_trigram_extension(self):
        empty = {"tables": [], "functions": [], "extensions": []}
        helper = function(
            "rad_search_normalize",
            "CREATE OR REPLACE FUNCTION private.rad_search_normalize(p_text text) RETURNS text LANGUAGE sql AS $$select p_text$$",
            "p_text text",
            "text",
        )
        reader = function(
            "reader",
            "CREATE OR REPLACE FUNCTION public.reader() RETURNS jsonb LANGUAGE sql AS $$select to_jsonb(t) from public.reader_rows t$$",
        )
        rows = table(
            "reader_rows",
            [
                column("title"),
                column("normalized", "s", "private.rad_search_normalize(title)"),
            ],
            [
                {
                    "name": "reader_search",
                    "constraint": False,
                    "definition": "CREATE INDEX reader_search ON public.reader_rows USING gin (title extensions.gin_trgm_ops)",
                }
            ],
        )
        manifest, body, output = self.package(
            empty, {"tables": [rows], "functions": [helper, reader], "extensions": []}
        )
        self.assertLess(
            body.index("FUNCTION private.rad_search_normalize"),
            body.index('create table "public"."reader_rows"'),
        )
        self.assertIn("create extension if not exists pg_trgm", body)
        self.assertEqual(manifest["changes"]["extensions"], ["pg_trgm"])
        self.assertIn(
            'revoke all on table "public"."reader_rows" from PUBLIC,anon,authenticated,service_role;',
            body,
        )
        self.assertIn(
            "REVIEW_ONLY_RECOVERY_AND_OWNER_AUTHORIZATION_REQUIRED",
            (output / "FORWARD_REVIEW_ONLY.sql").read_text(),
        )
        self.assertFalse(manifest["execution_allowed"])

    def test_existing_null_validation_is_not_reclassified_or_tightened(self):
        reader = function(
            "reader",
            "CREATE OR REPLACE FUNCTION public.reader() RETURNS jsonb LANGUAGE sql AS $$select to_jsonb(s) from public.source_documents s$$",
        )
        old = table("source_documents", [column("validation_status")])
        new = table(
            "source_documents",
            [column("validation_status", default="'candidate'::text", not_null=True)],
        )
        manifest, body, _ = self.package(
            {"tables": [old], "functions": [], "extensions": []},
            {"tables": [new], "functions": [reader], "extensions": []},
        )
        self.assertEqual(len(manifest["changes"]["retained_drift"]), 1)
        self.assertNotIn("set not null", body.lower())
        self.assertNotIn("set default 'candidate'", body.lower())
        self.assertNotIn("update public.source_documents", body.lower())
        self.assertTrue(manifest["constraint_gates"][0]["preserve_existing_nulls"])

    def test_unknown_root_fails_instead_of_emitting_partial_forward(self):
        empty = {"tables": [], "functions": [], "extensions": []}
        with self.assertRaisesRegex(ValueError, "Missing candidate roots"):
            self.package(empty, empty)

    def test_unqualified_composite_argument_waits_for_new_table(self):
        empty = {"tables": [], "functions": [], "extensions": []}
        rows = table("reader_rows", [column("title")])
        helper = function(
            "rad_row_json",
            "CREATE OR REPLACE FUNCTION private.rad_row_json(o reader_rows) RETURNS jsonb LANGUAGE sql AS $$select to_jsonb(o)$$",
            "o reader_rows",
        )
        reader = function(
            "reader",
            "CREATE OR REPLACE FUNCTION public.reader() RETURNS jsonb LANGUAGE sql AS $$select private.rad_row_json(t) from public.reader_rows t$$",
        )
        _, body, _ = self.package(
            empty, {"tables": [rows], "functions": [helper, reader], "extensions": []}
        )
        self.assertLess(
            body.index('create table "public"."reader_rows"'),
            body.index("FUNCTION private.rad_row_json"),
        )

    def test_function_acl_is_deny_by_default_without_implicit_public_grant(self):
        empty = {"tables": [], "functions": [], "extensions": []}
        reader = function(
            "reader",
            "CREATE OR REPLACE FUNCTION public.reader() RETURNS jsonb LANGUAGE sql AS $$select '{}'::jsonb$$",
        )
        _, body, _ = self.package(
            empty, {"tables": [], "functions": [reader], "extensions": []}
        )
        self.assertIn(
            'revoke all on function "public"."reader"() from PUBLIC,anon,authenticated,service_role;',
            body,
        )
        self.assertNotIn("grant execute", body)

    def test_existing_body_with_changed_acl_is_reconciled(self):
        reader = function(
            "reader",
            "CREATE OR REPLACE FUNCTION public.reader() RETURNS jsonb LANGUAGE sql AS $$select '{}'::jsonb$$",
        )
        old = dict(
            reader,
            grants=[{"role": "PUBLIC", "privilege": "EXECUTE", "grantable": False}],
        )
        manifest, body, _ = self.package(
            {"tables": [], "functions": [old], "extensions": []},
            {"tables": [], "functions": [reader], "extensions": []},
        )
        self.assertEqual(len(manifest["changes"]["replaced_functions"]), 1)
        self.assertIn('revoke all on function "public"."reader"()', body)
        self.assertNotIn("CREATE OR REPLACE FUNCTION", body)

    def test_target_and_baseline_guards_precede_any_ddl(self):
        empty = {"tables": [], "functions": [], "extensions": []}
        reader = function(
            "reader",
            "CREATE OR REPLACE FUNCTION public.reader() RETURNS jsonb LANGUAGE sql AS $$select '{}'::jsonb$$",
        )
        _, body, _ = self.package(
            empty, {"tables": [], "functions": [reader], "extensions": []}
        )
        self.assertLess(
            body.index("FORWARD_TARGET_ASSERTION_REQUIRED"), body.index("create schema")
        )
        self.assertIn("inshddthftkhcdosoqcn", body)
        self.assertIn("FORWARD_BASELINE_MISMATCH: public.reader()", body)


if __name__ == "__main__":
    unittest.main()
