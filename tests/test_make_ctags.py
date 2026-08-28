"""make-ctags.sh indexes the project and skips the junk directories."""

import subprocess

from conftest import REPO, require


def test_tags_skip_dependency_and_build_dirs(tmp_path):
    require("ctags")
    (tmp_path / "src").mkdir()
    (tmp_path / "src" / "app.py").write_text("def wanted_symbol():\n    pass\n")
    for junk in ("node_modules", "venv/lib", "static", ".tox"):
        d = tmp_path / junk
        d.mkdir(parents=True)
        (d / "mod.py").write_text(f"def junk_symbol_{junk.replace('/', '_').strip('.')}():\n    pass\n")
    r = subprocess.run([str(REPO / "make-ctags.sh")], cwd=tmp_path, capture_output=True, text=True)
    assert r.returncode == 0, r.stderr
    tags = (tmp_path / "tags").read_text()
    assert "wanted_symbol" in tags
    assert "junk_symbol" not in tags
