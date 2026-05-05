# AGENTS.md

## Cursor Cloud specific instructions

This is a pure bash-script project (no build step, no package manager lockfile in the repo). Development requires:

- **Node.js 20.x** and **npm** (needed by the install script to fetch `@anthropic-ai/claude-code`)
- **shellcheck** for linting bash scripts

### Lint

```bash
shellcheck install-deepseek-claude.sh uninstall-deepseek-claude.sh tests/profile_detection.sh
```

Only warnings are expected (SC2034 unused variable in install script, SC2016 single-quote info in test). No errors.

### Test

```bash
bash tests/profile_detection.sh
```

This test stubs `npm` and `uname`, creates temp `$HOME` dirs, and verifies the installer writes the correct PATH export to the expected shell profile (`.bashrc`, `.bash_profile`, or `.zshrc`).

### Run (hello-world)

```bash
export DEEPSEEK_API_KEY=your_key_here
./install-deepseek-claude.sh
export PATH="$HOME/.deepseek-claude:$PATH"
deepseek-claude --version
```

The wrapper requires a real `DEEPSEEK_API_KEY` for interactive use. With any non-empty value set, `--version` and `--help` work without network access.

### Uninstall

```bash
./uninstall-deepseek-claude.sh
```
