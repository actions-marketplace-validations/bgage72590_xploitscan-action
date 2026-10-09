# XploitScan Security Scanner — GitHub Action

Scan your code for security vulnerabilities on every pull request. Built for AI-generated code from Cursor, Lovable, Bolt, Replit, and other vibe-coding tools.

- **223 security rules** (30 in the free tier, full set with an API key from any paid plan)
- **SARIF output** piped into the GitHub Security tab
- **PR comments** with a security grade and findings summary
- **Configurable fail thresholds** to block merges on critical/high findings
- **Optional AI false-positive filter** (Claude Haiku, ~$0.01 / scan) to reduce noise on CI runs

## See it in action

- **[Live demo PR →](https://github.com/bgage72590/xploitscan-demo/pull/1)** — real pull request in a deliberately-vulnerable repo. Scroll to the bottom for the `XploitScan Security Report` comment.
- **[Live Security tab →](https://github.com/bgage72590/xploitscan-demo/security/code-scanning)** — the same findings surfaced as GitHub code-scanning alerts, with one-click navigation to the offending lines.
- **[Live file-level annotations →](https://github.com/bgage72590/xploitscan-demo/pull/1/files)** — in the "Files changed" tab each finding appears inline next to the vulnerable code, powered by GitHub Advanced Security's SARIF integration.

Every new PR on the [demo repo](https://github.com/bgage72590/xploitscan-demo) is a fresh, self-refreshing example — no stale screenshot to maintain.

## Usage

Add this to `.github/workflows/xploitscan.yml`:

```yaml
name: Security Scan
on: [push, pull_request]

permissions:
  contents: read
  security-events: write
  pull-requests: write

jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: bgage72590/xploitscan-action@v1
        with:
          fail-on: critical
```

### With an API key from any paid plan (full 223-rule set)

```yaml
      - uses: bgage72590/xploitscan-action@v1
        with:
          fail-on: high
          api-key: ${{ secrets.XPLOITSCAN_API_KEY }}
          anthropic-api-key: ${{ secrets.ANTHROPIC_API_KEY }}
```

Generate an API key from any paid plan at **xploitscan.com → Settings → API Keys**. The optional AI false-positive filter needs `anthropic-api-key`; `api-key` alone unlocks the full rule set.

## Inputs

| Input | Description | Default |
|-------|-------------|---------|
| `path` | Path to scan (default: current directory) | `.` |
| `fail-on` | Fail the action if graded findings (critical, high, medium, low — not info) of this severity or higher are found: critical, high, medium, low, none (default: none) | `none` |
| `sarif-file` | Path to write SARIF output (default: xploitscan-results.sarif) | `xploitscan-results.sarif` |
| `comment` | Post a summary comment on pull requests (default: true) | `true` |
| `api-key` | XploitScan API key (xpls_...) — generate one in Settings → API Keys. Required to unlock the full 223-rule Pro set; without it the action runs the 30 free rules. | `''` |
| `fail-on-quality` | Also fail the action on high-severity code-quality findings (QA…). Off by default: quality findings are reported either way, and the exit code is a contract with pipelines that were passing before they existed. See https://xploitscan.com/quality | `false` |
| `grade-vendored` | Count findings in vendored, generated, and documentation files (components/ui, __generated__, *.md) toward the grade and the failure threshold. Off by default — those findings are reported and uploaded to the Security tab either way. Set to true if you treat vendored code as yours to maintain. NOTE: this input is what the action grades by; `scan.gradeVendored` in .xploitscanrc does not apply here, because the action recomputes the grade from the scan JSON rather than using the CLI's. | `false` |
| `anthropic-api-key` | Optional Anthropic API key. When set, findings are run through XploitScan's AI false-positive filter (uses Claude Haiku, ~$0.01 per scan). Reduces noise on CI runs. Get one at https://console.anthropic.com. | `''` |

## Outputs

| Output | Description |
|--------|-------------|
| `grade` | Security grade (A+ to F) |
| `score` | Security score (0-100) |
| `findings-count` | Total number of findings, including ones not counted toward the grade |
| `graded-findings-count` | Findings that count toward the grade (excludes vendored/generated/documentation files). Includes info findings, which never fail the build. |
| `ungraded-count` | Findings in vendored, generated, or documentation files. Reported and uploaded in the SARIF, but not counted toward the grade or the failure threshold. |
| `quality-count` | Code-quality findings (QA…). Never counted toward the grade or the severity counts; see fail-on-quality. |
| `quality-high-count` | Code-quality findings at high severity or above. |
| `critical-count` | Number of critical findings |
| `high-count` | Number of high findings |
| `medium-count` | Number of medium findings |
| `low-count` | Number of low findings |
| `sarif-file` | Path to the SARIF output file |

## What it does

1. Installs and runs `xploitscan` against your codebase.
2. Uploads SARIF results to the GitHub Security tab (findings appear as annotations on changed files in the PR).
3. Posts a security summary comment on pull requests — updates in place on subsequent pushes so you never get comment spam.
4. Optionally fails the check if findings exceed your `fail-on` threshold.

## Example PR Comment

When code changes are detected:

> ## 🔴 XploitScan Security Report
>
> **Grade: D** | Score: 65/100 | 5 findings
>
> | Severity | Count |
> |----------|-------|
> | 🔴 Critical | 1 |
> | 🟠 High | 2 |
> | 🟡 Medium | 2 |
> | 🔵 Low | 0 |

When no scannable code is found (config/docs-only PRs), the comment self-reports instead of falsely green-lighting the PR:

> ## ⚪ XploitScan Security Report
>
> **No scannable code found in this PR.** This PR may only contain config, docs, or text changes.

## Supported languages

XploitScan's 223-rule set primarily targets **JavaScript, TypeScript, and Node.js** codebases — that's where the rules are deepest (secrets, SQL injection, XSS, SSRF, prototype pollution, crypto misuse, unsafe deserialization, and more). Additional rule coverage extends to Python, Go, and a handful of configuration surfaces (Dockerfile, Terraform, Kubernetes manifests, CI workflows, `.env` files, package manifests) where patterns are transferable.

If you run a polyglot repo, the action will still scan and skip files it doesn't have rules for — you get signal on the supported surfaces without noise elsewhere.

## Pinning the action version

Pin to a major (`@v1`) to get non-breaking updates automatically, or pin to a specific tag (`@v1.5.0`) if your security policy requires exact-version pinning:

```yaml
- uses: bgage72590/xploitscan-action@v1       # latest v1.x
- uses: bgage72590/xploitscan-action@v1.5.0   # exact pin
```

## Links

- **[XploitScan website](https://xploitscan.com)**
- [Documentation](https://xploitscan.com/docs)
- [CLI on npm](https://www.npmjs.com/package/xploitscan)
- [Pricing](https://xploitscan.com/pricing)
- [Changelog](https://xploitscan.com/changelog)

## License

MIT — see [LICENSE](./LICENSE).

---

Built by [Cipherline LLC](https://xploitscan.com) — [admin@xploitscan.com](mailto:admin@xploitscan.com)
