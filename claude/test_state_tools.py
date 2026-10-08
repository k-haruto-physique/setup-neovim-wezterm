# -*- coding: utf-8 -*-
"""lock.py・claims.py・board.py・drive_identity.py の確かめ（ADR-HAR-002 段2の「確かめ方」）。

  python claude/test_state_tools.py
本物の ~/.claude/state には触らない（CLAUDE_STATE_DIR を一時フォルダに向ける）。
2つのプロセスが同時に同じ札・同じ返事を取りに来たら、片方だけが取れることを見る。
"""
from __future__ import annotations

import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent


def run(tmp, *args):
    env = {**os.environ, "CLAUDE_STATE_DIR": str(tmp), "PYTHONIOENCODING": "utf-8"}
    return subprocess.run([sys.executable, *args], cwd=HERE, env=env, capture_output=True, text=True, encoding="utf-8")


def race(tmp, argv_a, argv_b):
    env = {**os.environ, "CLAUDE_STATE_DIR": str(tmp), "PYTHONIOENCODING": "utf-8"}
    pa = subprocess.Popen([sys.executable, *argv_a], cwd=HERE, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    pb = subprocess.Popen([sys.executable, *argv_b], cwd=HERE, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    return pa.wait(), pb.wait()


class T(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())

    def test_lock_race_one_wins(self):
        for _ in range(5):
            run(self.tmp, "lock.py", "release", "chrome", "A")
            run(self.tmp, "lock.py", "release", "chrome", "B")
            a, b = race(self.tmp, ["lock.py", "take", "chrome", "A", "x", "10"], ["lock.py", "take", "chrome", "B", "y", "10"])
            self.assertEqual(sorted([a, b]), [0, 3])

    def test_lock_release_only_own(self):
        self.assertEqual(run(self.tmp, "lock.py", "take", "studio", "A", "切替", "5").returncode, 0)
        self.assertEqual(run(self.tmp, "lock.py", "release", "studio", "B").returncode, 3)
        self.assertEqual(run(self.tmp, "lock.py", "release", "studio", "A").returncode, 0)

    def test_chrome_lock_alias(self):
        self.assertEqual(run(self.tmp, "chrome_lock.py", "take", "A", "Studio", "10").returncode, 0)
        self.assertEqual(run(self.tmp, "lock.py", "status", "chrome").returncode, 3)
        self.assertEqual(run(self.tmp, "chrome_lock.py", "release", "A").returncode, 0)

    def test_claims_race_one_wins_and_reply_recorded(self):
        for i in range(5):
            ts = f"17914{i}.000"
            a, b = race(self.tmp, ["claims.py", "take", "private", "C1", ts, "IG", "--reply", "reaction:+1:U1"],
                        ["claims.py", "take", "private", "C1", ts, "listen:IG", "--reply", "chat:IG"])
            self.assertEqual(sorted([a, b]), [0, 3])
        out = run(self.tmp, "claims.py", "list").stdout
        self.assertIn("[working]", out)

    def test_claims_failed_listing(self):
        run(self.tmp, "claims.py", "take", "private", "C2", "1.0", "listen:IG")
        run(self.tmp, "claims.py", "failed", "private", "C2", "1.0", "listen:IG", "--note", "安全装置")
        out = run(self.tmp, "claims.py", "list", "--state", "failed", "--ch", "C2").stdout
        self.assertIn("安全装置", out)
        self.assertEqual(run(self.tmp, "claims.py", "done", "private", "C2", "1.0", "IG").returncode, 3)

    def test_board_set_get(self):
        self.assertEqual(run(self.tmp, "board.py", "set", "chrome.front_tab", "本人のタブ", "--by", "IG").returncode, 0)
        r = run(self.tmp, "board.py", "get", "chrome.front_tab")
        self.assertEqual(r.stdout.strip(), "本人のタブ")
        self.assertEqual(run(self.tmp, "board.py", "set", "x", "y").returncode, 2)   # --by が無い

    def test_drive_identity_home_and_unknown(self):
        sys.path.insert(0, str(HERE))
        os.environ["CLAUDE_STATE_DIR"] = str(self.tmp)
        import importlib
        import _state
        importlib.reload(_state)
        import drive_identity
        importlib.reload(drive_identity)
        root = Path(tempfile.mkdtemp())
        self.assertEqual(drive_identity.identify(str(root)), "unknown")
        (root / "YouTube").mkdir()
        self.assertEqual(drive_identity.identify(str(root)), "unknown")      # 片方だけでは家と決めない
        (root / "Videos").mkdir()
        self.assertEqual(drive_identity.identify(str(root)), "home_ssd")
        self.assertEqual(drive_identity.identify(str(root / "nope")), "absent")


if __name__ == "__main__":
    unittest.main(verbosity=1)
