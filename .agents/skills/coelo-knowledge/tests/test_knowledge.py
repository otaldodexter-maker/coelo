"""Regression cases using synthetic files only; no production access."""

from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import coelo_knowledge as knowledge
import yaml


class KnowledgeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="coelo-knowledge-unit-")
        self.parent = Path(self.temp.name).resolve()
        self.root = self.parent / "repo"
        self.article = self.root / "docs/knowledge/team/example.md"
        self.article.parent.mkdir(parents=True)
        (self.root / "AGENTS.md").write_text("Fonte sintética.", encoding="utf-8")
        (self.parent / "external.md").write_text("Fonte externa sintética.", encoding="utf-8")
        self.metadata = dict(title="Exemplo", knowledge_id="example", source="AGENTS.md",
                             status="validated", generated_at="2026-09-08", audience="team",
                             surfaces=["documentation"], visibility="internal", review_owner="Equipe")

    def tearDown(self):
        expected_parent = Path(tempfile.gettempdir()).resolve()
        self.assertEqual(self.parent.parent, expected_parent)
        self.assertTrue(self.parent.name.startswith("coelo-knowledge-unit-"))
        self.temp.cleanup()

    def write(self, updates=None, body="Agulha de consulta.", path=None, flow=False):
        path = path or self.article
        path.parent.mkdir(parents=True, exist_ok=True)
        metadata = {**self.metadata, **(updates or {})}
        path.write_text("---\n" + yaml.safe_dump(metadata, allow_unicode=True,
                        default_flow_style=flow) + "---\n\n" + body, encoding="utf-8")

    def test_accepts_inline_and_block_lists_and_real_leap_day(self):
        for flow in (False, None):
            with self.subTest(flow=flow):
                self.write({"generated_at": "2024-02-29"}, flow=flow)
                self.assertEqual(knowledge.scan(self.root)[1], [])

    def test_rejects_source_escape_directory_projection_and_missing_file(self):
        for source in ("../external.md", "docs", "docs/knowledge/team/example.md",
                       "missing.md", str(self.parent / "external.md"), "C:/external.md"):
            with self.subTest(source=source):
                self.write({"source": source})
                self.assertTrue(knowledge.scan(self.root)[1])

    def test_rejects_symlink_source_escape(self):
        link = self.root / "link.md"
        try:
            link.symlink_to(self.parent / "external.md")
        except OSError:
            self.skipTest("O host não permite criar symlink no teste.")
        self.write({"source": "link.md"})
        self.assertTrue(knowledge.scan(self.root)[1])

    def test_rejects_invalid_dates_and_wrong_metadata_types(self):
        updates = [{"generated_at": "2026-99-99"}, {"generated_at": "2025-02-29"},
                   {"updated_at": "2026-13-01"}, {"surfaces": []}, {"surfaces": "superadmin"},
                   {"surfaces": [2]}, {"title": []}, {"source": {}}, {"audience": "user"},
                   {"status": "approved"}, {"review_owner": ""}, {"knowledge_id": "Not valid"}]
        for update in updates:
            with self.subTest(update=update):
                self.write(update)
                self.assertTrue(knowledge.scan(self.root)[1])

    def test_requires_every_metadata_field(self):
        for key in knowledge.REQUIRED:
            with self.subTest(key=key):
                self.write({key: None})
                self.assertTrue(knowledge.scan(self.root)[1])

    def test_rejects_duplicate_yaml_keys(self):
        self.write()
        content = self.article.read_text(encoding="utf-8")
        self.article.write_text(content.replace("status: validated", "status: draft\nstatus: validated"),
                                encoding="utf-8")
        self.assertTrue(knowledge.scan(self.root)[1])

    def test_rejects_malformed_yaml_and_unsafe_tags_without_echoing_value(self):
        for metadata in ("title: [", "title: !!python/object:synthetic.Secret {}"):
            self.article.write_text("---\n" + metadata + "\n---\n", encoding="utf-8")
            errors = knowledge.scan(self.root)[1]
            self.assertTrue(errors)
            self.assertNotIn("synthetic.Secret", str(errors))

    def test_identity_unique_per_audience_but_shared_across_audiences(self):
        self.write()
        other = self.article.with_name("duplicate.md")
        self.write(path=other)
        self.assertTrue(knowledge.scan(self.root)[1])
        other.unlink()
        self.write({"audience": "admin"}, path=self.root / "docs/knowledge/admin/example.md")
        records, errors = knowledge.scan(self.root)
        self.assertEqual(errors, [])
        self.assertEqual(len(records), 2)

    def test_security_guidance_is_not_a_secret(self):
        self.write(body="Nunca colocar service_role no cliente; manter a credencial no servidor.")
        self.assertEqual(knowledge.scan(self.root)[1], [])

    def test_sensitive_values_rejected_without_echoing_them(self):
        for body in ("CPF 12345678909", "CPF 123.456.789-09", "service_role=synthetic-secret",
                     "token: synthetic-token-value", "assistant: conversa sintética"):
            self.write(body=body)
            errors = knowledge.scan(self.root)[1]
            self.assertTrue(errors)
            self.assertNotIn(body, str(errors))

    def test_search_excludes_draft_and_deprecated_by_default(self):
        for status in knowledge.STATUSES:
            self.write({"status": status})
            records, errors = knowledge.scan(self.root)
            self.assertEqual(errors, [])
            self.assertEqual(bool(knowledge.search(records, "agulha")), status == "validated")
            self.assertEqual(len(knowledge.search(records, "AgUlHa", status="all")), 1)

    def test_search_filters_audience_and_accepts_users_alias(self):
        self.write()
        self.write({"audience": "user"}, path=self.root / "docs/knowledge/users/example.md")
        records, errors = knowledge.scan(self.root)
        self.assertEqual(errors, [])
        for audience in ("user", "users"):
            matches = knowledge.search(records, "agulha", audience=audience)
            self.assertEqual(len(matches), 1)
            self.assertEqual(matches[0]["metadata"]["source"], "AGENTS.md")
            self.assertIn("/users/", matches[0]["path"])
        self.assertEqual(knowledge.search(records, "agulha.*"), [])

    def test_missing_knowledge_root_is_an_error(self):
        self.assertTrue(knowledge.scan(self.parent / "missing")[1])


if __name__ == "__main__":
    unittest.main(verbosity=2)
