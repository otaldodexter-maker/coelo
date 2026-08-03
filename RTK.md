# RTK - Rust Token Killer (Codex CLI)

**Usage**: Token-optimized CLI proxy for shell commands.

## Rule

Always prefix shell commands with `rtk`.

## Coelo Decision

Use `rtk` when it clearly reduces noisy output or helps inspect large command results.
Do not assume the Codex will transparently rewrite every command through RTK.
In Codex, treat RTK as an explicit optimization tool, not a guaranteed automatic hook.

Examples:

```bash
rtk git status
rtk cargo test
rtk npm run build
rtk pytest -q
```

## Meta Commands

```bash
rtk gain            # Token savings analytics
rtk gain --history  # Recent command savings history
rtk proxy <cmd>     # Run raw command without filtering
```

## Verification

```bash
rtk --version
rtk gain
which rtk
```
