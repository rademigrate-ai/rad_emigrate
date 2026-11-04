"""Real owned-loopback PostgreSQL regressions; synthetic evidence is never approval."""

import hashlib
import json
import subprocess
import time
import unittest
from pathlib import Path

from scripts.tests import test_production_reconciliation_sql as native

PACKAGE = "4beb6ba711c5b0243d69be29b32a76c13f5ebcc47ce131e7ca406bcd67e6c282"
ADMIN = "b5100000-0000-4000-8000-000000000001"
OTHER = "b5100000-0000-4000-8000-000000000002"
USER = "b5100000-0000-4000-8000-000000000003"
NOTE = "SYNTHETIC local inverse authorization; never Production approval."
FRAME = "private.rad_release_function_frame(private.rad_reviewed_function_signatures())"
FRAME_HASH = f"encode(extensions.digest({FRAME}::text,'sha256'),'hex')"
CHANGE = """create or replace function private.rad_page_position(body jsonb,version text)
returns jsonb language plpgsql set search_path='' as $changed$begin return null;end$changed$;"""


def claims(actor=ADMIN, role="authenticated"):
    return "set request.jwt.claims='" + json.dumps({"role": role, "sub": actor}) + "';"


class NoRestoreSafetyOpsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.repo = Path(__file__).resolve().parents[2]
        repo = cls.repo

        class OwnedFixture(native.ReconciliationSQLTest):
            @classmethod
            def sql(inner, sql, error=None):
                if "do $rad_forward_guard$" in sql:
                    super().sql(
                        (
                            repo
                            / "supabase/migrations/20261103120000_rad_no_restore_safety_ops.sql"
                        ).read_text("utf8")
                    )
                    super().sql(
                        claims(role="service_role")
                        + f"""
                    insert into auth.users(id,email) values
                     ('{ADMIN}','safety-admin@example.invalid'),
                     ('{OTHER}','safety-other-admin@example.invalid'),
                     ('{USER}','safety-user@example.invalid');
                    insert into public.profiles(id,role)values('{ADMIN}','admin'),('{OTHER}','admin'),('{USER}','user')
                    on conflict(id)do update set role=excluded.role;"""
                    )
                    # Capture on the actual pre-forward synthetic catalog, not on
                    # an already upgraded fixture posing as a preimage.
                    super().sql(
                        claims()
                        + f"""select public.capture_release_function_state(
                     '{PACKAGE}',{FRAME_HASH},'Synthetic pre-forward capture for seven-function regression.');"""
                    )
                return super().sql(sql, error)

        cls.fixture = OwnedFixture
        cls.fixture.setUpClass()
        try:
            for name in (
                "20261102192642_rad_source_faithful_editorial_release.sql",
                "20261103114340_rad_corrected_source_editorial_admission.sql",
                "20261103180754_rad_source_unpublish_safety.sql",
            ):
                cls.fixture.sql((repo / "supabase/migrations" / name).read_text("utf8"))
        except BaseException:
            cls.fixture.tearDownClass()
            raise

    @classmethod
    def tearDownClass(cls):
        cls.fixture.tearDownClass()

    @staticmethod
    def claims(actor=None, role="authenticated"):
        return json.dumps({"role": role, **({"sub": actor} if actor else {})})

    def capture_sql(self):
        package = hashlib.sha256(self.id().encode()).hexdigest()
        return f"""rid:=private.rad_capture_function_state('{package}','manual_review',
         private.rad_reviewed_function_signatures(),{FRAME_HASH},'{NOTE}');"""

    @staticmethod
    def authorize_sql(
        expiry="clock_timestamp()+interval '10 minutes'", request_note=NOTE
    ):
        return f"""expected:={FRAME_HASH};
         insert into private.rad_function_reversal_authorizations(source_receipt_id,actor_id,
          expected_current_state_sha256,request_sha256,independent_reviewer_ref,approval_evidence_sha256,expires_at)
         values(rid,'{ADMIN}',expected,encode(extensions.digest(jsonb_build_object(
          'source_receipt_id',rid,'actor_id','{ADMIN}'::uuid,'expected_current_state_sha256',expected,
          'note','{request_note}')::text,'sha256'),'hex'),
          'SYNTHETIC-LOCAL-REVIEWER',repeat('a',64),{expiry});"""

    def function_case(self, body, error=None, prefix=""):
        return self.fixture.sql(
            "begin;"
            + claims()
            + prefix
            + """
         do $case$declare rid bigint;expected text;before_frame jsonb;result jsonb;retry jsonb;
         begin """
            + body
            + " end $case$;rollback;",
            error=error,
        )

    def test_postgres17_maintain_allows_lock_without_catalog_write_grants(self):
        # Owned native fixture only. No hosted privilege is changed, and the
        # capability check never grants a privilege to its caller.
        self.fixture.sql("""begin;create role rad_maintain_fixture;
         grant usage on schema private to rad_maintain_fixture;
         grant execute on function private.rad_catalog_lock_executor_available()to rad_maintain_fixture;
         set local role rad_maintain_fixture;
         do $$begin if private.rad_catalog_lock_executor_available()then raise exception 'FAIL unprivileged capability';end if;end$$;
         reset role;grant maintain on table pg_catalog.pg_proc to rad_maintain_fixture;
         set local role rad_maintain_fixture;
         do $$begin
          if not private.rad_catalog_lock_executor_available()
           or has_table_privilege(current_user,'pg_catalog.pg_proc','UPDATE')
           or has_table_privilege(current_user,'pg_catalog.pg_proc','DELETE')
           or has_table_privilege(current_user,'pg_catalog.pg_proc','TRUNCATE')then raise exception 'FAIL MAINTAIN capability';end if;
         end$$;
         lock table pg_catalog.pg_proc in share mode;
         rollback;""")

    def test_capture_is_idempotent_across_transactions(self):
        # The original bug included a new timestamp in each retry comparison.
        package = hashlib.sha256(self.id().encode()).hexdigest()
        sql = (
            claims()
            + f"""select private.rad_capture_function_state('{package}','manual_review',
         private.rad_reviewed_function_signatures(),{FRAME_HASH},'{NOTE}');"""
        )
        first = self.fixture.sql(sql)
        second = self.fixture.sql(sql)
        self.assertEqual(first, second)
        self.assertEqual(
            self.fixture.sql(
                f"select count(*)from private.rad_function_state_members where receipt_id={first};"
            ),
            "7",
        )

    def test_pre_forward_capture_and_late_capture_refusal(self):
        self.assertEqual(
            self.fixture.sql(
                f"select count(*)from private.rad_function_state_members m join private.rad_function_state_receipts r on r.id=m.receipt_id where r.package_sha256='{PACKAGE}';"
            ),
            "7",
        )
        self.function_case(
            f"""perform private.rad_capture_function_state(repeat('b',64),'reviewed_forward',
         private.rad_reviewed_function_signatures(),{FRAME_HASH},'{NOTE}');""",
            "pre_forward_function_baseline_required",
        )

    def test_capture_scope_and_expected_state_are_exact(self):
        cases = [
            (
                "array['private.rad_page_position(jsonb,text)']",
                FRAME_HASH,
                "'manual_review'",
                "exact_seven_function_scope_required",
            ),
            (
                "private.rad_reviewed_function_signatures()||array['private.rad_page_position(jsonb,text)']",
                FRAME_HASH,
                "'manual_review'",
                "exact_seven_function_scope_required",
            ),
            (
                "private.rad_reviewed_function_signatures()",
                "repeat('0',64)",
                "'manual_review'",
                "function_capture_state_changed",
            ),
            (
                "private.rad_reviewed_function_signatures()",
                FRAME_HASH,
                "null",
                "function_state_scope_required",
            ),
        ]
        for signatures, expected, scope, error in cases:
            with self.subTest(error=error):
                self.function_case(
                    f"perform private.rad_capture_function_state(repeat('c',64),{scope},{signatures},{expected},'{NOTE}');",
                    error,
                )

    def test_inverse_requires_separate_authorization(self):
        self.function_case(
            self.capture_sql()
            + CHANGE
            + f"perform public.reverse_release_function_state(rid,{FRAME_HASH},'{NOTE}');",
            "independent_function_reversal_authorization_required",
        )

    def test_inverse_preserves_all_seven_and_exact_retry(self):
        self.function_case(
            f"before_frame:={FRAME};"
            + self.capture_sql()
            + CHANGE
            + self.authorize_sql()
            + f"""
         result:=public.reverse_release_function_state(rid,expected,'{NOTE}');
         retry:=public.reverse_release_function_state(rid,expected,'{NOTE}');
         if result is distinct from retry or result->>'restored_count'<>'7' or result->>'definition_changes'<>'1'
          or {FRAME} is distinct from before_frame then raise exception 'FAIL exact seven-function inverse';end if;
         if(select count(*)from private.rad_function_reversal_receipts where source_receipt_id=rid)<>1 then raise exception 'FAIL inverse retry duplicated audit';end if;
         begin perform public.reverse_release_function_state(rid,expected,'Changed request must require new independent authorization.');
          raise exception 'FAIL changed request retry';exception when sqlstate 'PT403'then null;end;
         """
            + CHANGE
            + f"""begin perform public.reverse_release_function_state(rid,expected,'{NOTE}');
          raise exception 'FAIL drift after inverse accepted';exception when sqlstate 'PT409'then null;end;"""
        )

    def test_expired_wrong_note_and_other_admin_authorizations_refused(self):
        cases = [
            (
                self.authorize_sql(expiry="clock_timestamp()-interval '1 second'"),
                "",
                "independent_function_reversal_authorization_required",
            ),
            (
                self.authorize_sql(
                    request_note="A different synthetic authorization note."
                ),
                "",
                "independent_function_reversal_authorization_required",
            ),
            (
                self.authorize_sql(),
                f"perform set_config('request.jwt.claims','{self.claims(OTHER)}',true);",
                "function_state_actor_conflict",
            ),
        ]
        for auth, change_actor, error in cases:
            with self.subTest(error=error):
                self.function_case(
                    self.capture_sql()
                    + CHANGE
                    + auth
                    + change_actor
                    + f"perform public.reverse_release_function_state(rid,expected,'{NOTE}');",
                    error,
                )

    def test_stale_expected_state_and_member_injection_refused(self):
        self.function_case(
            self.capture_sql()
            + CHANGE
            + self.authorize_sql()
            + "alter function private.rad_claim_eligible(uuid) volatile;"
            + f"perform public.reverse_release_function_state(rid,expected,'{NOTE}');",
            "function_current_state_changed",
        )
        # An immutable table still permits trusted-owner INSERT. Bind the exact
        # member set to the root receipt so an extra row cannot become executable.
        injection = """insert into private.rad_function_state_members
         select receipt_id,'private.unreviewed()',function_oid,definition,owner_name,language_name,
          security_definer,volatile_code,config,grants,dependencies,definition_sha256
         from private.rad_function_state_members where receipt_id=rid limit 1;"""
        self.function_case(
            self.capture_sql()
            + injection
            + self.authorize_sql()
            + f"perform public.reverse_release_function_state(rid,expected,'{NOTE}');",
            "function_state_member_integrity_failed",
        )

    def test_owner_acl_dependency_and_oid_drift_refused(self):
        cases = [
            (
                "alter function private.rad_page_position(jsonb,text) owner to safety_fixture_owner;",
                "function_acl_or_owner_drift",
            ),
            (
                "grant execute on function private.rad_page_position(jsonb,text)to safety_fixture_owner;",
                "function_acl_or_owner_drift",
            ),
            (
                "create view public.safety_dependency as select private.rad_page_position('{}'::jsonb,'x');",
                "function_dependent_catalog_drift",
            ),
            (
                "drop function private.rad_page_position(jsonb,text);" + CHANGE,
                "function_identity_oid_drift",
            ),
        ]
        for change, error in cases:
            with self.subTest(error=error):
                self.function_case(
                    self.capture_sql()
                    + change
                    + self.authorize_sql()
                    + f"perform public.reverse_release_function_state(rid,expected,'{NOTE}');",
                    error,
                    prefix="create role safety_fixture_owner;",
                )

    def test_language_security_volatility_and_quoted_gucs_round_trip(self):
        initial = """create or replace function private.rad_page_position(body jsonb,version text)
         returns jsonb language sql immutable security definer
         set search_path='quoted schema',public set temp_tablespaces='pg_default'
         set statement_timeout='11s' as $quoted$select null::jsonb$quoted$;"""
        self.function_case(
            initial
            + f"before_frame:={FRAME};"
            + self.capture_sql()
            + CHANGE
            + "alter function private.rad_page_position(jsonb,text) reset all;"
            + self.authorize_sql()
            + f"""
         perform public.reverse_release_function_state(rid,expected,'{NOTE}');
         if {FRAME} is distinct from before_frame then raise exception 'FAIL quoted GUC or function attributes lost';end if;"""
        )

    def test_mid_inverse_failure_is_atomic(self):
        self.function_case(
            self.capture_sql()
            + CHANGE
            + "alter function private.rad_evidence(jsonb,uuid) stable;"
            + self.authorize_sql()
            + """
         create function public.safety_injected_ddl_failure()returns event_trigger language plpgsql as $trigger$
          begin if exists(select 1 from pg_event_trigger_ddl_commands()where objid='private.rad_page_position(jsonb,text)'::regprocedure)
          then raise exception 'synthetic_second_inverse_failure';end if;end$trigger$;
         create event trigger safety_injected_ddl_failure on ddl_command_end execute function public.safety_injected_ddl_failure();
         before_frame:="""
            + FRAME
            + f""";
         begin perform public.reverse_release_function_state(rid,expected,'{NOTE}');raise exception 'FAIL injected DDL did not abort';
          exception when raise_exception then if sqlerrm<>'synthetic_second_inverse_failure'then raise;end if;end;
         if {FRAME} is distinct from before_frame or exists(select 1 from private.rad_function_reversal_receipts where source_receipt_id=rid)
          then raise exception 'FAIL partial inverse leaked';end if;"""
        )

    def test_admin_api_does_not_allow_self_authorization_or_other_roles(self):
        for actor, role in (
            (USER, "authenticated"),
            (ADMIN, "service_role"),
            (ADMIN, "anon"),
        ):
            with self.subTest(role=role):
                self.fixture.sql(
                    "begin;"
                    + claims(actor, role)
                    + f"set local role {role};select public.get_release_function_state('{PACKAGE}');rollback;",
                    error="forbidden"
                    if role == "authenticated"
                    else "permission denied",
                )
        self.fixture.sql(
            "begin;"
            + claims()
            + "set local role authenticated;insert into private.rad_function_reversal_authorizations default values;rollback;",
            error="permission denied",
        )
        result = json.loads(
            self.fixture.sql(
                claims()
                + f"set role authenticated;select public.get_release_function_state('{PACKAGE}');"
            )
        )
        self.assertEqual(result["actor_id"], ADMIN)
        self.assertEqual(len(result["members"]), 7)
        self.assertTrue(all("definition" not in member for member in result["members"]))

    def test_catalog_lock_refuses_concurrent_ddl(self):
        args = [
            str(self.fixture.bin / "psql.exe"),
            "-XAtqw",
            "-h",
            "127.0.0.1",
            "-p",
            "64938",
            "-U",
            "postgres",
            "-d",
            "postgres",
            "-v",
            "ON_ERROR_STOP=1",
        ]
        proc = subprocess.Popen(
            args,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            encoding="utf8",
            env=self.fixture.env,
            creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
        )
        try:
            proc.stdin.write(
                "begin;set application_name='rad_safety_lock_fixture';lock table pg_catalog.pg_proc in row exclusive mode;\n"
            )
            proc.stdin.flush()
            for _ in range(50):
                locked = self.fixture.sql(
                    "select count(*)from pg_locks l join pg_stat_activity a on a.pid=l.pid where a.application_name='rad_safety_lock_fixture'and l.relation='pg_proc'::regclass and l.granted;"
                )
                if int(locked):
                    break
                time.sleep(0.05)
            else:
                self.fail("owned fixture did not acquire catalog lock")
            self.function_case(self.capture_sql(), "lock timeout")
        finally:
            proc.communicate("rollback;\n", timeout=10)
            self.assertEqual(proc.returncode, 0)

    def test_portable_unpublish_guards_two_locales_and_exact_retry(self):
        path = (self.repo / "supabase/tests/no_restore_safety_ops.sql").as_posix()
        self.fixture.sql(f"\\i '{path}'")

    def published_fixture(self, multiple_articles=False):
        source = (self.repo / "supabase/tests/source_editorial_release.sql").read_text(
            "utf8"
        )
        if not multiple_articles:
            return source[
                : source.index(
                    "select set_config('request.jwt.claims','{\"role\":\"anon\"}',true);"
                )
            ]
        marker = 'select set_config(\'request.jwt.claims\',\'{"role":"authenticated","sub":"a4100000-0000-4000-8000-000000000002"}\',true);'
        setup = source[: source.index(marker)]
        first = setup[
            setup.index("do $$declare actor") : setup.index(
                "-- Two original-language revisions"
            )
        ]
        second = (
            first.replace("a410", "a420")
            .replace(
                "a4200000-0000-4000-8000-000000000001",
                "a4100000-0000-4000-8000-000000000001",
            )
            .replace("source-fixture", "second-source-fixture")
            .replace("synthetic-source-release/", "second-synthetic-source-release/")
            .replace("repeat('e',64)", "repeat('d',64)")
        )
        return (
            setup
            + second
            + """
         update source_release_fixture set manifest=(select jsonb_agg(e order by e->>'revision_id')::text
          from source_release_fixture f cross join lateral jsonb_array_elements(f.manifest::jsonb)e)
         where batch='a4100000-0000-4000-8000-000000000040';
         delete from source_release_fixture where batch='a4200000-0000-4000-8000-000000000040';
         select set_config('request.jwt.claims','{"role":"authenticated","sub":"a4100000-0000-4000-8000-000000000001"}',true);
         do $$declare f record;begin select * into f from source_release_fixture;
          perform public.approve_source_editorial_batch(f.batch,f.manifest,encode(extensions.digest(f.manifest,'sha256'),'hex'),
           '2d90e50f73d48902bda291c12068f705ff0ee2f198f59ab261415186cc32fa77','Synthetic multiple-article source review.');
          perform public.publish_source_editorial_batch(f.batch,encode(extensions.digest(f.manifest,'sha256'),'hex'));
         end $$;"""
        )

    @staticmethod
    def unpublish_call():
        return "public.unpublish_source_editorial_batch(f.batch,encode(extensions.digest(f.manifest,'sha256'),'hex'),'Synthetic atomic withdrawal review.');"

    def test_multiple_articles_and_locales_withdraw_atomically(self):
        self.fixture.sql(
            self.published_fixture(True)
            + """
         do $$declare f record;r jsonb;begin select * into f from source_release_fixture;
          r:="""
            + self.unpublish_call()
            + """
          if r->'data'->>'unpublished_count'<>'3'or exists(select 1 from public.visa_article_heads where published_id is not null)
           or(select count(*)from private.rad_source_unpublish_members where batch_id=f.batch)<>3
           then raise exception 'FAIL multi-article atomic withdrawal';end if;
         end $$;rollback;"""
        )

    def test_late_member_failure_rolls_back_all_prior_withdrawals(self):
        self.fixture.sql(
            self.published_fixture(True)
            + """
         insert into public.visa_article_revisions(id,article_id,locale,revision,title,summary,content_hash,body,created_by)
          select 'a4200000-0000-4000-8000-000000000099',article_id,locale,3,title,summary,content_hash,body,created_by
          from public.visa_article_revisions where id='a4200000-0000-4000-8000-000000000011';
         update public.visa_article_heads set head_id='a4200000-0000-4000-8000-000000000099'where article_id='a4200000-0000-4000-8000-000000000010';
         do $$declare f record;begin select * into f from source_release_fixture;
          begin perform """
            + self.unpublish_call()
            + """
           raise exception 'FAIL late drift accepted';exception when sqlstate 'PT409'then null;end;
          if(select count(*)from public.visa_article_heads where published_id is not null)<>3
           or exists(select 1 from private.rad_source_unpublish_members where batch_id=f.batch)
           or exists(select 1 from private.rad_source_unpublish_receipts where batch_id=f.batch)
           or exists(select 1 from public.visa_article_revision_events where source_batch_id=f.batch and state='unpublished')
           then raise exception 'FAIL partial withdrawal escaped failed call';end if;
         end $$;rollback;"""
        )

    def test_source_withdrawal_actor_and_later_head_conflicts(self):
        self.fixture.sql(
            self.published_fixture()
            + """
         do $$declare f record;begin select * into f from source_release_fixture;
          perform set_config('request.jwt.claims','"""
            + self.claims(OTHER)
            + """',true);
          begin perform """
            + self.unpublish_call()
            + """
           raise exception 'FAIL unrelated Admin withdrew batch';exception when sqlstate 'PT409'then null;end;
          perform set_config('request.jwt.claims','{"role":"authenticated","sub":"a4100000-0000-4000-8000-000000000001"}',true);
          perform """
            + self.unpublish_call()
            + """
         end $$;
         insert into public.visa_article_revisions(id,article_id,locale,revision,title,summary,content_hash,body,created_by)
          select 'a4100000-0000-4000-8000-000000000099',article_id,locale,3,title,summary,content_hash,body,created_by
          from public.visa_article_revisions where id='a4100000-0000-4000-8000-000000000011';
         update public.visa_article_heads set head_id='a4100000-0000-4000-8000-000000000099'where article_id='a4100000-0000-4000-8000-000000000010'and locale='en';
         do $$declare f record;begin select * into f from source_release_fixture;
          begin perform """
            + self.unpublish_call()
            + """
           raise exception 'FAIL stale withdrawal retry';exception when sqlstate 'PT409'then null;end;
         end $$;rollback;"""
        )

    def test_pg_trgm_transaction_and_callback_inverse_limit(self):
        # This is an empty owned local database, never a recovery project or
        # restored database. Synthetic callbacks explicitly do not model Supabase.
        self.fixture.sql("create database rad_local_callback_regression;")
        sql = """
         create schema extensions;create schema callback_visible;
         create table public.callback_log(event text,tag text);
         create function public.local_ddl_callback()returns event_trigger language plpgsql as $$begin
          insert into public.callback_log values(tg_event,tg_tag);
          if tg_tag='CREATE EXTENSION'then grant usage on schema callback_visible to anon;end if;
          perform pg_notify('rad_local_schema_cache','synthetic only');end$$;
         create function public.local_drop_callback()returns event_trigger language plpgsql as $$begin
          insert into public.callback_log values(tg_event,tg_tag);end$$;
         create event trigger local_ddl_callback on ddl_command_end execute function public.local_ddl_callback();
         create event trigger local_drop_callback on sql_drop execute function public.local_drop_callback();
         do $$begin begin
          create extension pg_trgm with schema extensions;
          raise exception 'synthetic_precommit_failure';
          exception when raise_exception then if sqlerrm<>'synthetic_precommit_failure'then raise;end if;end;
          if exists(select 1 from pg_extension where extname='pg_trgm')
           or exists(select 1 from public.callback_log where tag='CREATE EXTENSION')
           or has_schema_privilege('anon','callback_visible','USAGE')then raise exception 'FAIL precommit extension effects escaped';end if;
         end$$;
         create extension pg_trgm with schema extensions;
         create table public.local_search(body text);
         create index local_trgm on public.local_search using gin(body extensions.gin_trgm_ops);
         do $$begin begin drop extension pg_trgm;
          raise exception 'FAIL dependent extension removed';exception when dependent_objects_still_exist then null;end;
          if not exists(select 1 from pg_extension where extname='pg_trgm')then raise exception 'FAIL dependency refusal lost extension';end if;
         end$$;
         drop index public.local_trgm;
         drop extension pg_trgm;
         do $$begin
          if exists(select 1 from pg_extension where extname='pg_trgm')then raise exception 'FAIL extension survived drop';end if;
          if not has_schema_privilege('anon','callback_visible','USAGE')then raise exception 'FAIL callback limitation fixture missing';end if;
          if not exists(select 1 from public.callback_log where event='sql_drop'and tag='DROP EXTENSION')then raise exception 'FAIL sql_drop callback not observed';end if;
         end$$;
        """
        self.fixture.command(
            "psql.exe",
            [
                "-XAtqw",
                "-h",
                "127.0.0.1",
                "-p",
                "64938",
                "-U",
                "postgres",
                "-d",
                "rad_local_callback_regression",
                "-v",
                "ON_ERROR_STOP=1",
            ],
            sql,
        )

    def test_z_concurrent_withdrawal_and_cross_transaction_replay(self):
        setup = (
            self.published_fixture()
            .replace("a410", "a430")
            .replace("source-fixture", "concurrent-source-fixture")
            .replace("synthetic-source-release", "concurrent-source-release")
            .replace("repeat('e',64)", "repeat('1',64)")
            .replace("repeat('f',64)", "repeat('2',64)")
        )
        self.fixture.sql(setup + "commit;")
        actor = "a4300000-0000-4000-8000-000000000001"
        batch = "a4300000-0000-4000-8000-000000000040"
        manifest = self.fixture.sql(
            f"select manifest_sha256 from private.rad_source_editorial_batches where id='{batch}';"
        )
        call = (
            claims(actor)
            + f"select public.unpublish_source_editorial_batch('{batch}','{manifest}','Synthetic concurrent source withdrawal.');"
        )
        args = [
            str(self.fixture.bin / "psql.exe"),
            "-XAtqw",
            "-h",
            "127.0.0.1",
            "-p",
            "64938",
            "-U",
            "postgres",
            "-d",
            "postgres",
            "-v",
            "ON_ERROR_STOP=1",
        ]
        proc = subprocess.Popen(
            args,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            encoding="utf8",
            env=self.fixture.env,
            creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
        )
        try:
            proc.stdin.write(
                "begin;set application_name='rad_withdrawal_concurrency';" + call + "\n"
            )
            proc.stdin.flush()
            for _ in range(50):
                if (
                    self.fixture.sql(
                        "select count(*)from pg_locks l join pg_stat_activity a on a.pid=l.pid where a.application_name='rad_withdrawal_concurrency'and l.locktype='advisory'and l.granted;"
                    )
                    != "0"
                ):
                    break
                time.sleep(0.05)
            else:
                self.fail("first withdrawal did not acquire its batch lock")
            # First transaction commits after a short delay while the second
            # actually contends on the same batch. Both must return one receipt.
            proc.stdin.write("select pg_sleep(0.5);commit;\n")
            proc.stdin.flush()
            second = json.loads(self.fixture.sql(call))
            output, error = proc.communicate(timeout=10)
            self.assertEqual(proc.returncode, 0, error)
            first = json.loads(
                next(line for line in output.splitlines() if line.startswith("{"))
            )
            self.assertEqual(first["data"], second["data"])
        finally:
            if proc.poll() is None:
                proc.communicate("rollback;\n", timeout=10)
        self.assertEqual(
            self.fixture.sql(
                f"select count(*)from private.rad_source_unpublish_receipts where batch_id='{batch}';"
            ),
            "1",
        )
        self.assertEqual(
            self.fixture.sql(
                f"select count(*)from public.visa_article_revision_events where source_batch_id='{batch}'and state='unpublished';"
            ),
            "2",
        )
        self.fixture.sql(
            claims(actor)
            + "update public.visa_article_heads set published_id='a4300000-0000-4000-8000-000000000012'where article_id='a4300000-0000-4000-8000-000000000010'and locale='en';",
            error="explicit_source_publication_operation_required",
        )

    def test_standard_editorial_pointer_revocation_remains_supported(self):
        # The source-specific pointer guard must not change existing standard
        # editorial semantics. This disposable fixture rolls back entirely.
        self.fixture.sql(
            "begin;"
            "select set_config('request.jwt.claims','{\"role\":\"service_role\"}',true);"
            "insert into auth.users(id,email) values("
            "'b6200000-0000-4000-8000-000000000001','standard-pointer@example.invalid');"
            "insert into public.visa_articles(id,kind,country_code,pathway_slug,slug,created_by)"
            " values('b6200000-0000-4000-8000-000000000010','related','ZZ',"
            "'synthetic-standard','synthetic-standard',"
            "'b6200000-0000-4000-8000-000000000001');"
            "insert into public.visa_article_revisions(id,article_id,locale,revision,title,"
            "summary,content_hash,body,created_by) values("
            "'b6200000-0000-4000-8000-000000000011',"
            "'b6200000-0000-4000-8000-000000000010','en',1,"
            "'SYNTHETIC standard editorial','No immigration facts.',repeat('0',64),"
            '\'{"sections":[],"related_article_ids":[]}\','
            "'b6200000-0000-4000-8000-000000000001');"
            "insert into public.visa_article_heads(article_id,locale,head_id,published_id)"
            " values('b6200000-0000-4000-8000-000000000010','en',"
            "'b6200000-0000-4000-8000-000000000011',"
            "'b6200000-0000-4000-8000-000000000011');"
            "update public.visa_article_heads set published_id=null"
            " where article_id='b6200000-0000-4000-8000-000000000010';"
            "do $$ begin if exists(select 1 from public.visa_article_heads where"
            " article_id='b6200000-0000-4000-8000-000000000010' and published_id is not null)"
            " then raise exception 'standard pointer was not revoked'; end if; end $$;"
            "rollback;"
        )


if __name__ == "__main__":
    unittest.main()
