#!/bin/sh
# Bootstrap the gateway fork without touching stock Herdr or restarting servers.
set -eu
if [ "$#" -gt 1 ]; then
  printf 'Usage: %s [ssh-target]\n' "$0" >&2
  exit 2
fi
command -v curl >/dev/null
command -v python3 >/dev/null
case "$(uname -s):$(uname -m)" in
  Darwin:arm64|Darwin:aarch64) target=macos-aarch64 ;;
  Linux:x86_64) target=linux-x86_64 ;;
  *) printf 'Unsupported gateway platform\n' >&2; exit 1 ;;
esac
bin_dir="$HOME/.local/bin"
mkdir -p "$bin_dir"
work=$(mktemp -d "$bin_dir/.herdr-gateway-install.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
feed=https://github.com/qazpytre/herdr-gateway/releases/latest/download/latest.json
curl --proto '=https' --tlsv1.2 -fsSL "$feed" -o "$work/latest.json"
python3 - "$work/latest.json" "$target" "$work" <<'PY'
import json, pathlib, re, sys
feed = json.loads(pathlib.Path(sys.argv[1]).read_text())
if feed.get('channel') != 'gateway' or not re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+-gateway\.[0-9]+', feed['version']):
    raise SystemExit('refusing non-gateway release')
asset = feed['assets'][sys.argv[2]]
if not asset['url'].startswith('https://github.com/qazpytre/herdr-gateway/releases/download/'):
    raise SystemExit('refusing an artifact outside the gateway repository')
work = pathlib.Path(sys.argv[3])
(work / 'url').write_text(asset['url'])
(work / 'version').write_text(feed['version'])
PY
url=$(cat "$work/url")
curl --proto '=https' --tlsv1.2 -fsSL "$url" -o "$work/herdr-gateway"
python3 - "$work/latest.json" "$target" "$work/herdr-gateway" <<'PY'
import hashlib, json, pathlib, sys
expected = json.loads(pathlib.Path(sys.argv[1]).read_text())['assets'][sys.argv[2]]['sha256']
actual = hashlib.sha256(pathlib.Path(sys.argv[3]).read_bytes()).hexdigest()
if actual != expected:
    raise SystemExit('gateway binary SHA-256 mismatch')
PY
chmod 755 "$work/herdr-gateway"
expected="herdr $(cat "$work/version")"
actual=$("$work/herdr-gateway" --version)
if [ "$actual" != "$expected" ]; then
  printf 'Gateway artifact identity mismatch: %s\n' "$actual" >&2
  exit 1
fi
mv "$work/herdr-gateway" "$bin_dir/herdr-gateway"
printf 'Installed %s at %s/herdr-gateway\n' "$actual" "$bin_dir"
if [ "$#" -eq 1 ]; then
  "$bin_dir/herdr-gateway" machine setup "$1" --install
fi
if [ "$target" = macos-aarch64 ]; then
  agent="$HOME/Library/LaunchAgents/com.qazpytre.herdr-gateway-update.plist"
  logs="$HOME/Library/Logs/herdr-gateway"
  mkdir -p "$(dirname "$agent")" "$logs"
  python3 - "$agent" "$bin_dir/herdr-gateway" "$logs" <<'PY'
import pathlib, plistlib, sys
agent, binary, logs = map(pathlib.Path, sys.argv[1:])
job = {
    'Label': 'com.qazpytre.herdr-gateway-update',
    'ProgramArguments': [str(binary), 'update', '--machines'],
    'StartInterval': 3600,
    'RunAtLoad': True,
    'EnvironmentVariables': {
        'PATH': f'{binary.parent}:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin',
    },
    'StandardOutPath': str(logs / 'update.log'),
    'StandardErrorPath': str(logs / 'update-error.log'),
}
agent.write_bytes(plistlib.dumps(job))
PY
  domain="gui/$(id -u)"
  label=com.qazpytre.herdr-gateway-update
  if ! launchctl print "$domain/$label" >/dev/null 2>&1; then
    launchctl bootstrap "$domain" "$agent"
  fi
  printf 'Hourly gateway updates enabled; logs: %s\n' "$logs"
fi
