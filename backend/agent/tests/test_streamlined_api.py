"""Integration tests for the streamlined AImesis Clinical Decision Support API."""

import unittest
from fastapi.testclient import TestClient
from aimesis_agent.main import app


class TestStreamlinedApi(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.client = TestClient(app)

    def test_health_check(self):
        res = self.client.get("/health")
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertEqual(data["status"], "healthy")
        self.assertEqual(data["service"], "aimesis-clinical-backend")

    def test_recommendation_endpoint(self):
        payload = {
            "patient_id": "PAT-2026-001",
            "patient_age_years": 8.0,
            "patient_weight_kg": 25.0,
            "bsa_m2": 0.95,
            "regimen_agents": ["cisplatin", "doxorubicin"],
            "drug_doses_mg_m2": {"cisplatin": 75.0},
            "indication": "solid_tumor",
            "can_swallow_tablets": True,
            "prior_breakthrough_cinv": False,
            "chemo_duration_days": 1,
        }
        for endpoint in ["/recommendation", "/api/recommendation"]:
            res = self.client.post(endpoint, json=payload)
            self.assertEqual(res.status_code, 200, f"Failed for {endpoint}: {res.text}")
            data = res.json()
            self.assertIn("overall_tier", data)
            self.assertEqual(data["overall_tier"], "High")
            self.assertIn("dosing_lines", data)
            self.assertIn("ondansetron", data["dosing_lines"])
            self.assertIn("aprepitant", data["dosing_lines"])
            self.assertIn("dexamethasone", data["dosing_lines"])

    def test_recommendation_validation_empty_agents(self):
        res = self.client.post("/api/recommendation", json={"regimen_agents": []})
        self.assertEqual(res.status_code, 422)

    def test_episodes_cycle_tracking(self):
        # 1. Create episode
        create_payload = {
            "patient_id": "PAT-TRACK-01",
            "cycle_number": 1,
            "regimen_agents": ["methotrexate", "vincristine"],
            "patient_age_years": 6.0,
            "patient_weight_kg": 21.0,
        }
        res = self.client.post("/episodes", json=create_payload)
        self.assertEqual(res.status_code, 200, res.text)
        ep = res.json()
        self.assertIn("episode_id", ep)
        ep_id = ep["episode_id"]
        self.assertEqual(ep["patient_id"], "PAT-TRACK-01")

        # 2. List episodes
        res = self.client.get("/episodes?patient_id=PAT-TRACK-01")
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertGreaterEqual(data["count"], 1)

        # 3. Log breakthrough event
        bt_payload = {
            "vomiting_episodes_24h": 3,
            "pepsin_nausea_score": 6,
            "rescue_administered": "ondansetron iv",
            "notes": "Experienced nausea 6h post chemo",
        }
        res = self.client.post(f"/episodes/{ep_id}/breakthrough", json=bt_payload)
        self.assertEqual(res.status_code, 200)
        updated = res.json()
        self.assertEqual(len(updated["breakthrough_events"]), 1)
        self.assertEqual(updated["breakthrough_events"][0]["vomiting_episodes_24h"], 3)

        # 4. Dual sign-off
        sign_payload = {
            "oncologist_signed": True,
            "oncologist_name": "Dr. Peeters",
            "pharmacist_signed": True,
            "pharmacist_name": "Pharm. Dubois",
        }
        res = self.client.post(f"/episodes/{ep_id}/sign-off", json=sign_payload)
        self.assertEqual(res.status_code, 200)
        signed = res.json()
        self.assertTrue(signed["sign_off"]["oncologist_signed"])
        self.assertEqual(signed["sign_off"]["oncologist_name"], "Dr. Peeters")
        self.assertTrue(signed["sign_off"]["pharmacist_signed"])

    def test_passport_endpoints(self):
        passport_payload = {
            "patient_label": "Lucas (7y)",
            "regimen_label": "EURAMOS-1",
            "language": "NL",
            "drug_list": ["cisplatin", "doxorubicin"],
            "patient_age_years": 7.0,
            "patient_weight_kg": 23.0,
            "bsa_m2": 0.88,
        }
        for endpoint in ["/passports", "/passport/generate", "/api/passports"]:
            res = self.client.post(endpoint, json=passport_payload)
            self.assertEqual(res.status_code, 200, f"Failed for {endpoint}: {res.text}")
            data = res.json()
            self.assertIn("title", data)
            self.assertIn("printable_html", data)

    def test_disabled_adk_endpoints_are_404(self):
        for route in [
            "/apps",
            "/agents",
            "/sessions",
            "/runs",
            "/dev-ui",
            "/run_sse",
        ]:
            res = self.client.get(route)
            self.assertEqual(res.status_code, 404, f"Route {route} should be disabled/404")

    def test_agui_hidden_from_schema(self):
        openapi_paths = list(app.openapi()["paths"].keys())
        for path in openapi_paths:
            self.assertFalse(path.startswith("/agui"), f"{path} should be hidden from schema")


if __name__ == "__main__":
    unittest.main()
