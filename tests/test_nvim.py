"""The neovim config: init.vim, the lua/carver modules, and the go ftplugin, in an isolated
XDG tree with the real plugins installed."""

import shutil

import pytest

from conftest import path_without, require


def test_starts_without_errors_or_messages(nvim):
    r = nvim.run("+qa")
    assert r.stderr == ""
    assert nvim.lua("vim.fn.execute('messages')").strip() == ""


def test_editing_options(nvim):
    got = nvim.lua("""{
        expandtab = vim.o.expandtab, tabstop = vim.o.tabstop, shiftwidth = vim.o.shiftwidth,
        softtabstop = vim.o.softtabstop, textwidth = vim.o.textwidth, scrolloff = vim.o.scrolloff,
        ignorecase = vim.o.ignorecase, smartcase = vim.o.smartcase, clipboard = vim.o.clipboard,
        title = vim.o.title, background = vim.o.background, wildignore = vim.o.wildignore,
    }""")
    assert got == {
        "expandtab": True, "tabstop": 2, "shiftwidth": 2, "softtabstop": 2, "textwidth": 100,
        "scrolloff": 7, "ignorecase": True, "smartcase": True, "clipboard": "unnamed",
        "title": True, "background": "dark", "wildignore": "*/target/*,*.pyc",
    }


def test_key_maps(nvim):
    got = nvim.lua("""{
        jk = vim.fn.maparg('jk', 'i'), dot = vim.fn.maparg('.', 'v'),
        m = vim.fn.maparg('<leader>m', 'n'), M = vim.fn.maparg('<leader>M', 'n'),
    }""")
    assert got == {"jk": "<Esc>", "dot": ":norm.<CR>",
                   "m": ":RenderMarkdown toggle<CR>", "M": ":RenderMarkdown preview<CR>"}


def test_overlength_highlight_applies_per_window(nvim, tmp_path):
    f = tmp_path / "a.txt"
    f.write_text("x\n")
    groups = nvim.lua("vim.tbl_map(function(m) return m.group end, vim.fn.getmatches())", file=f)
    assert groups == ["OverLength"]


def test_trailing_whitespace_is_stripped_from_python_on_save(nvim, tmp_path):
    py = tmp_path / "a.py"
    py.write_text("x = 1   \ny = 2\t\n")
    nvim.run("+w", "+qa!", str(py))
    assert py.read_text() == "x = 1\ny = 2\n"
    txt = tmp_path / "a.txt"
    txt.write_text("keep   \n")
    nvim.run("+w", "+qa!", str(txt))
    assert txt.read_text() == "keep   \n"


def test_writing_init_vim_reloads_it_without_piling_up_state(nvim):
    """Every write re-sources init.vim. Module state must survive that unchanged: the
    flake8 argument list used to gain another --ignore=E501 per write."""
    count = "(function() local n = 0 for _, a in ipairs(require('lint').linters.flake8.args) do if a == '--ignore=E501' then n = n + 1 end end return n end)()"
    assert nvim.lua(count, file=nvim.config / "init.vim", after=["w", "w"]) == 1


def test_diagnostics_use_virtual_text(nvim):
    assert nvim.lua("vim.diagnostic.config().virtual_text") is True


def test_errors_command_exists(nvim):
    assert nvim.lua("vim.fn.exists(':Errors')") == 2


def test_flake8_lints_python_but_ignores_line_length(nvim, tmp_path):
    require("flake8")
    f = tmp_path / "bad.py"
    f.write_text("import os\nx = " + "1" * 120 + "\n")
    messages = nvim.lua("""(function()
        vim.wait(15000, function() return #vim.diagnostic.get(0) > 0 end)
        return vim.tbl_map(function(d) return d.message end, vim.diagnostic.get(0))
    end)()""", file=f)
    assert any("'os' imported but unused" in m for m in messages), messages
    assert not any("E501" in m or "line too long" in m for m in messages), messages


def test_ctrlp_uses_a_fast_file_lister_when_available(nvim):
    if not (shutil.which("ag") or shutil.which("rg")):
        pytest.skip("neither ag nor rg installed")
    got = nvim.lua("{ cmd = vim.g.ctrlp_user_command, caching = vim.g.ctrlp_use_caching, grepprg = vim.o.grepprg }")
    tool = "ag" if shutil.which("ag") else "rg"
    assert got["cmd"].startswith(tool) and got["caching"] == 0 and got["grepprg"].startswith(tool)


def test_rust_warns_once_when_rust_analyzer_is_missing(nvim, tmp_path):
    f = tmp_path / "main.rs"
    f.write_text("fn main() {}\n")
    n = nvim.with_env(PATH=path_without("rust-analyzer"))
    got = n.lua("{ warned = vim.g.warned_rust_analyzer, clients = #vim.lsp.get_clients() }", file=f)
    assert got == {"warned": True, "clients": 0}


def test_rust_analyzer_attaches_at_the_cargo_root(nvim, tmp_path):
    if not shutil.which("rust-analyzer"):
        pytest.skip("rust-analyzer not installed")
    (tmp_path / "Cargo.toml").write_text('[package]\nname = "t"\nversion = "0.1.0"\nedition = "2021"\n')
    (tmp_path / "src").mkdir()
    main = tmp_path / "src" / "main.rs"
    main.write_text("fn main() {}\n")
    got = nvim.lua("""(function()
        vim.wait(20000, function() return #vim.lsp.get_clients({ bufnr = 0 }) > 0 end)
        local c = vim.lsp.get_clients({ bufnr = 0 })[1]
        return c and { name = c.name, root = c.root_dir } or {}
    end)()""", file=main)
    assert got == {"name": "rust-analyzer", "root": str(tmp_path)}


def test_lsp_keys_are_registered_on_attach(nvim):
    got = nvim.lua("""{
        rust = #vim.api.nvim_get_autocmds({ group = 'vimrc_rust_lsp', event = 'FileType' }),
        keys = #vim.api.nvim_get_autocmds({ group = 'vimrc_lsp_keys', event = 'LspAttach' }),
    }""")
    assert got == {"rust": 1, "keys": 1}


def test_render_markdown_is_configured(nvim, tmp_path):
    f = tmp_path / "a.md"
    f.write_text("# hi\n")
    got = nvim.lua("""{
        loaded = package.loaded['render-markdown'] ~= nil,
        command = vim.fn.exists(':RenderMarkdown'),
        icons = require('render-markdown.state').get(0).heading.icons,
    }""", file=f)
    assert got["loaded"] is True and got["command"] == 2
    assert got["icons"] == ["# ", "## ", "### ", "#### ", "##### ", "###### "]


TMP_FILETYPES = [
    ("/var/tmp/sshd_config.Ab3dE9fG", "Port 22\n", "sshdconfig"),
    ("/var/tmp/nginxAb3dE9fG.conf", "server {}\n", "nginx"),
    ("/tmp/fstab.Qq1Ww2Ee", "# /etc/fstab\n", "fstab"),
    ("/tmp/setup.py", "x = 1\n", "python"),
    ("/tmp/Makefile.py", "x = 1\n", "python"),
    ("/tmp/plain.txt", "x\n", "text"),
    ("/tmp/noext", "x\n", ""),
    ("/var/tmp/hook.Zz9Yy8Xx", "#!/bin/sh\necho\n", "sh"),
]


@pytest.mark.parametrize("first", [False, True], ids=["module-after-config", "module-before-config"])
@pytest.mark.parametrize("path,content,expected", TMP_FILETYPES, ids=[t[0] for t in TMP_FILETYPES])
def test_sudoedit_temp_files_get_their_filetype(nvim, path, content, expected, first):
    """sudo -e copies /etc/ssh/sshd_config to /var/tmp/sshd_config.XXXXXXXX. The result must
    not depend on whether the module loads before or after neovim's own detection."""
    p = pytest_tmp(path)
    p.write_text(content)
    try:
        before = ["lua require('carver.detect-tmp-filetype')"] if first else []
        assert nvim.lua("vim.bo.filetype", file=p, before=before) == expected
    finally:
        p.unlink()


def pytest_tmp(path):
    from pathlib import Path
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    return p


def test_go_uses_real_tabs_four_wide(nvim, tmp_path):
    f = tmp_path / "main.go"
    f.write_text("package main\n")
    got = nvim.lua("{ et = vim.bo.expandtab, ts = vim.bo.tabstop, sw = vim.bo.shiftwidth, sts = vim.bo.softtabstop }", file=f)
    assert got == {"et": False, "ts": 4, "sw": 4, "sts": 4}
