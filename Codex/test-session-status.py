"""Headless regression checks: no GUI windows or paid Codex turns."""
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import time
import unittest

SCRIPT = Path(__file__).with_name("statusline.ps1").resolve()
A = "11111111-2222-3333-4444-555555555555"
B = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"


class SessionStatusTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="codex-status-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "sessions").mkdir()
        self.env = dict(os.environ, CODEX_HOME=str(self.root))

    def rollout(self, session, model, tokens, cwd=None, cumulative=999999):
        events = [
            {"type": "session_meta", "payload": {"id": session, "cwd": cwd or str(self.root)}},
            {"type": "turn_context", "payload": {"model": model, "effort": "high", "cwd": cwd or str(self.root)}},
            {"type": "event_msg", "payload": {"type": "token_count", "info": {"last_token_usage": {"total_tokens": tokens}, "total_token_usage": {"total_tokens": cumulative}, "model_context_window": 10000}}},
        ]
        path = self.root / "sessions" / f"rollout-test-{session}.jsonl"
        path.write_text("\n".join(json.dumps(e, separators=(",", ":")) for e in events), encoding="utf-8")
        return path

    def render(self, session):
        result = subprocess.run(["pwsh", "-NoProfile", "-File", str(SCRIPT), "-Path", str(self.root), "-SessionId", session], env=self.env, capture_output=True, encoding="utf-8", timeout=15, check=True)
        return re.sub(r"\x1b\[[0-9;]*m", "", result.stdout)

    def test_same_cwd_sessions_do_not_cross(self):
        self.rollout(A, "model-A", 1000)
        self.rollout(B, "model-B", 8000)
        a, b = self.render(A), self.render(B)
        self.assertIn("model-A", a)
        self.assertIn("ctx:10%", a)
        self.assertNotIn("model-B", a)
        self.assertIn("model-B", b)
        self.assertIn("ctx:80%", b)

    def test_missing_session_never_falls_back(self):
        self.rollout(B, "wrong-model", 8000)
        text = self.render(A)
        self.assertIn("unavailable", text)
        self.assertNotIn("wrong-model", text)

    def test_unique_truncated_title_resolves(self):
        self.rollout(A, "unique-model", 1000)
        self.assertIn("unique-model", self.render(A[:29]))

    def test_prefix_collision_stays_unavailable(self):
        self.rollout(A, "wrong-one", 1000)
        self.rollout(A[:29] + "6666666", "wrong-two", 8000)
        text = self.render(A[:29])
        self.assertIn("unavailable", text)
        self.assertNotIn("wrong-", text)

    def test_zero_context_does_not_use_cumulative_usage(self):
        self.rollout(A, "zero-model", 0)
        self.assertIn("ctx:0%", self.render(A))

    def test_transcript_cwd_is_session_specific(self):
        child = self.root / "session-directory"
        child.mkdir()
        self.rollout(A, "cwd-model", 1000, str(child))
        self.assertIn("session-directory", self.render(A))

    def test_live_title_overrides_previous_turn_model(self):
        self.rollout(A, "old-model", 1000)
        quoted = str(SCRIPT).replace("'", "''")
        cwd = str(self.root).replace("'", "''")
        command = f". '{quoted}' -Path '{cwd}' -SessionId '{A}'; $State.LiveModel='new-model'; $State.LiveEffort='low'; Render-Status '{cwd}'"
        result = subprocess.run(["pwsh", "-NoProfile", "-Command", command], env=self.env, capture_output=True, encoding="utf-8", timeout=15, check=True)
        text = re.sub(r"\x1b\[[0-9;]*m", "", result.stdout).splitlines()[-4:]
        self.assertIn("new-model", text[0])
        self.assertIn("eff:low", text[0])

    def test_binding_switch_and_end_without_gui(self):
        self.rollout(A, "first-session", 1000)
        self.rollout(B, "second-session", 8000)
        started = subprocess.check_output(["pwsh", "-NoProfile", "-Command", f"(Get-Process -Id {os.getpid()}).StartTime.ToUniversalTime().ToString('o')"], encoding="utf-8").strip()
        binding = {"sessionId": A, "cwd": str(self.root), "ownerPid": os.getpid(), "ownerPaneId": 901, "ownerStartedAt": started, "ended": False}
        path = self.root / "binding.json"
        def save():
            temp = path.with_suffix(".tmp")
            temp.write_text(json.dumps(binding), encoding="utf-8")
            os.replace(temp, path)
        save()
        script = str(SCRIPT).replace("'", "''")
        target = str(path).replace("'", "''")
        command = f"function wezterm {{ '[{{\"pane_id\":901,\"title\":\"test-owner\"}}]'; $global:LASTEXITCODE=0 }}; & '{script}' -Watch -IntervalSeconds 1 -BindingPath '{target}'"
        output = self.root / "frames.txt"
        with output.open("w", encoding="utf-8") as stream:
            process = subprocess.Popen(["pwsh", "-NoProfile", "-Command", command], env=self.env, stdout=stream, stderr=subprocess.PIPE)
            try:
                def wait_for(value):
                    deadline = time.monotonic() + 12
                    while time.monotonic() < deadline:
                        if value in output.read_text(encoding="utf-8"):
                            return
                        if process.poll() is not None:
                            self.fail(process.stderr.read().decode("utf-8"))
                        time.sleep(0.1)
                    self.fail(f"Missing frame: {value}")
                wait_for("first-session")
                binding["sessionId"] = B
                save()
                wait_for("second-session")
                binding["ended"] = True
                save()
                self.assertEqual(process.wait(timeout=5), 0)
            finally:
                if process.poll() is None:
                    process.kill()
                    process.wait()
                process.stderr.close()


if __name__ == "__main__":
    unittest.main()
