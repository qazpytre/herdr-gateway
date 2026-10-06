# herdr-gateway


Gateway-compatible fork of [Herdr](https://github.com/herdrdev/herdr), maintained in
[qazpytre/herdr-gateway](https://github.com/qazpytre/herdr-gateway).

Separate binary, configuration, saved machines, and update feed; stock Herdr is
not replaced. Published platforms: macOS Apple Silicon and Linux x86_64. Linux
artifacts are static MUSL builds, including support for older glibc hosts.

[Gateway releases](https://github.com/qazpytre/herdr-gateway/releases) ·
[Upstream documentation](https://herdr.dev/docs/) · [Apache 2.0 license](LICENSE)

---

https://github.com/user-attachments/assets/043ec09f-4bdd-41d5-aee0-8fda6b83e267

**the runtime your coding agents live on.**

- **detach without stopping work** — herdr keeps terminals running in a background server when you close the client or lose your SSH connection. after a server or machine restart, herdr restores the saved layout and can resume supported agent sessions; the original processes do not survive. [session state →](https://herdr.dev/docs/session-state/)
- **several machines, one window** — keep local work and saved ssh machines together, with a combined agent list and independent reconnects. [remote machines →](https://herdr.dev/docs/connecting-machines/)
- **never hunt for the stuck one** — every pane is marked working, blocked, or idle. when an agent stops and needs an answer, herdr says so.
- **agent-native** — agents drive herdr through the cli and socket api: they can spawn panes, prompt each other, and wait until another agent is genuinely blocked. [agent skill →](https://herdr.dev/docs/agent-skill/)
- **runs what you already run** — claude code, codex, cursor, opencode, grok and the rest. herdr doesn't wrap or replace them; it owns their terminals.
- **keyboard and mouse, both first-class** — tmux-style prefix keys *and* click, drag, split. pick per moment, not per tool.
- **plugins** — extend panes and workflows. [browse the marketplace →](https://herdr.dev/plugins/)
- **one rust binary, no electron** — runs in whatever terminal you already use.

---

## install

```bash
installer=$(mktemp)
curl -fsSL https://github.com/qazpytre/herdr-gateway/releases/latest/download/install-gateway.sh -o "$installer" \
  && sh "$installer"
rm -f "$installer"
```

The installer verifies the binary's SHA-256 and exact gateway identity before
replacing `~/.local/bin/herdr-gateway`. Ensure `~/.local/bin` is on `PATH`.
Start with `herdr-gateway`. Gateway files live under `herdr-gateway` rather than
`herdr`; existing stock configuration and saved profiles are not imported.

On macOS, bootstrap also enables an hourly user LaunchAgent running
`herdr-gateway update --machines`, including a check when the job loads at login.
The Mac must be awake and SSH targets reachable. Failures are logged and the next
scheduled run attempts the update again:

- Job: `~/Library/LaunchAgents/com.qazpytre.herdr-gateway-update.plist`
- Logs: `~/Library/Logs/herdr-gateway/update.log` and `update-error.log`

To disable automatic checks:

```bash
launchctl bootout "gui/$(id -u)/com.qazpytre.herdr-gateway-update"
rm ~/Library/LaunchAgents/com.qazpytre.herdr-gateway-update.plist
```

### gateway SSH policy

For an alias whose host-key policy is intentionally configured in `~/.ssh/config`,
add only that exact alias to `~/.config/herdr-gateway/config.toml`:

```toml
[remote]
ssh_config_host_key_targets = ["omarchy-workstation"]
```

Listed aliases retain their OpenSSH host-key policy during saved-machine and
unattended connections. All other targets retain strict checking. This does not
configure Cloudflare, bypass SSH authentication, or change other aliases.

### install and update remote machines

```bash
# Install the same release as the local gateway; do not change saved profiles.
herdr-gateway machine setup omarchy-workstation --install

# Save a profile if it is not already present in the gateway catalog.
herdr-gateway machine add omarchy-workstation --label Omarchy

# Update the Mac and synchronize all enabled saved SSH profiles.
herdr-gateway update --machines

# Operate on the saved machine without opening a TUI.
herdr-gateway --machine Omarchy agent list
```

Bootstrap accepts an optional SSH target: `sh "$installer" omarchy-workstation`.
`machine setup` also accepts `--remote-session NAME`. Unattended/background
connections never install binaries unless installation is explicitly approved.

`--install` approves binary installation, **never stopping remote panes**.
Compatible running servers are kept; their runtime version may remain older than
the installed binary. An incompatible server that needs a destructive restart
blocks unattended installation. `--handoff` explicitly opts into live handoff,
without an unattended destructive-restart fallback:

```bash
herdr-gateway machine setup omarchy-workstation --install --handoff
herdr-gateway update --machines --handoff
```

### release automation

Pushes to the `gateway` branch run contract checks and build both platforms.
Successful builds publish immutable binaries, checksums, bootstrap, and
`latest.json` under this fork's GitHub Releases. Gateway binaries consume only
that feed, never the upstream stable or preview feeds. Versions such as
`0.9.1-gateway.3` preserve full identity and compare gateway revisions numerically;
the manifest retains prior releases for exact-version remote installs.

The daily upstream workflow checks the latest stable Herdr release. Clean merges
are tested and proposed as pull requests in this fork; merge conflicts open an
issue here. Failed checks block the proposal. Upstream upgrades require review
and merging into `gateway` before release; they are not automatically merged or
deployed. No upstream PRs are opened.

## docs

General Herdr usage is documented at [herdr.dev/docs](https://herdr.dev/docs/).
Those guides describe upstream Herdr; use the gateway binary, paths, installer,
and update commands above for this fork.

## thanks

every past sponsor and backer is listed in [SPONSORS.md](./SPONSORS.md) — thank you 🐑

enterprise / partnership: hey@herdr.dev

## agent instructions

if you are an ai agent helping with this repository, read [`AGENTS.md`](./AGENTS.md) before making changes and read [`CONTRIBUTING.md`](./CONTRIBUTING.md) before opening issues or PRs.

## development

```bash
git clone -b gateway https://github.com/qazpytre/herdr-gateway
cd herdr-gateway
# Requires Rust 1.96.1 and Zig 0.16.0 available to the build.
HERDR_BUILD_CHANNEL=gateway HERDR_BUILD_ID=0 cargo build --release --locked

just test        # unit tests
just check       # formatting, tests, and maintenance checks
```

## license

Herdr is licensed under the [Apache License 2.0](LICENSE).
