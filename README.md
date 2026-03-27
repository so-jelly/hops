# hops

macOS URL router — routes clicked links to the right browser profile or app based on rules in `~/.hops.toml`.

## Why

macOS only supports one default browser. hops sits as your default browser and routes each URL to the right Chrome profile or native app.

## How it works

- When you click a URL, macOS sends an Apple Event to hops
- hops reads `~/.hops.toml`, matches the URL against handlers (first match wins)
- Strips tracking params (utm_*, fbclid, gclid)
- Resolves Chrome profile display name to directory
- Opens the URL in the matched browser/app and brings it to the foreground
- When opened from Finder/Dock (no URL), shows a config window

## Install

From source (requires Swift 5.9+ and Xcode CLT):

```bash
git clone https://github.com/so-jelly/hops.git
cd hops
make install
```

Then set hops as default browser in System Settings → Desktop & Dock.

## Configuration

Example `~/.hops.toml`:

```toml
[default]
app = "Google Chrome"
profile = "Personal"

[[handlers]]
hostnames = ["localhost"]
hostname_regexps = ['.*\.local$']
app = "Google Chrome"
profile = "Dev"

[[handlers]]
match = ["teams.microsoft.com/l/meetup-join*"]
app = "/Applications/Microsoft Teams.app"

[[handlers]]
match = ["github.com/my-org/*"]
app = "Google Chrome"
profile = "Work"

[[handlers]]
match = [
  "*.atlassian.net/*",
  "console.cloud.google.com/*",
]
app = "Google Chrome"
profile = "Work"
```

### Matching rules

- `match` — glob patterns against host + path. `*` matches any characters.
- `hostnames` — exact hostname match.
- `hostname_regexps` — regex patterns against hostname.
- `profile` — Chrome profile display name. hops resolves to the actual profile directory.
- `app` — app name or full path to `.app` bundle.

Handlers are evaluated top-to-bottom; first match wins.

### URL cleaning

Tracking params stripped automatically: `utm_*`, `uta_*`, `fbclid`, `gclid`.

## Development

```bash
make test      # run tests
make build     # build release binary into app bundle
make install   # build + copy Info.plist + register with Launch Services
make clean     # remove app bundle
```

## License

MIT — see [LICENSE](LICENSE).
