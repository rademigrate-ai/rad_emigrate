"""Prevent a repeat of Flutter calling names/arguments not installed by SQL."""

import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class AppointmentRegistryTest(unittest.TestCase):
    def test_registry_names_match_the_installed_adapter_and_flutter(self):
        contract = json.loads(
            (ROOT / "supabase/contracts/appointments_v1.json").read_text()
        )
        sql = (
            ROOT
            / "supabase/migrations/20261025095914_pr82_appointment_contract_adapter.sql"
        ).read_text()
        dart = (
            ROOT / "lib/features/interviews/data/appointment_repository.dart"
        ).read_text()
        installed = {}
        for name, args in re.findall(
            r"create function public[.](\w+)\((.*?)\)", sql, re.S
        ):
            installed[name] = [
                arg.strip().split()[0] for arg in args.split(",") if arg.strip()
            ]
        self.assertEqual(set(installed), set(contract["rpcs"]))
        for name, args in contract["rpcs"].items():
            self.assertEqual(installed[name], list(args))
            self.assertIn("'" + name + "'", dart)
        # Existing closed-envelope canonical registry remains independently valid.
        canonical = json.loads((ROOT / "supabase/contracts/rad_v1.json").read_text())
        self.assertIn("UUID", canonical["$defs"])


if __name__ == "__main__":
    unittest.main()
