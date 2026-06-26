# Security Policy

## Reporting a vulnerability

Please report security issues **privately** — do not open a public issue.

Two private channels, either is fine:

- **GitHub:** the **Report a vulnerability** button under this repository's **Security** tab. It opens a private advisory visible only to the maintainers.
- **Email:** security@gelkao.com

We aim to acknowledge a report within a few business days and will keep you updated on the fix and disclosure timeline.

## Supported versions

| Version | Supported |
|---|---|
| latest `master` | ✅ |

Until the first tagged release (`v0.1.0`), only the latest `master` is supported. This table becomes a versioned list once releases are tagged.

## What the tool does with your data

`gelkao` runs entirely on your machine, and every request it makes is a plain HTTP **GET** — it only ever *downloads*. It never sends a request body, so nothing of yours is uploaded anywhere. The full data model is in the README under **"Your data stays on your disk."**

These properties are verifiable from the source — you do not have to take our word for it:

- **Two outbound destinations, both GETs.** `gelkao` issues `curl` requests to exactly two hosts:
  1. `https://usage.hetzner.com/...` — downloads *your own* invoices.
  2. `https://gelkao.com/...` — downloads the current Hetzner **price tables** (public `prices.csv`, `server_types.csv`). This is the **optional price refresh**: an interactive `gelkao audit` asks `[Y/n]` first, you can decline with `n`, and `-q` (or any non-interactive run — a pipe, CI) skips it.

  Verify both — and that each only reads:
  ```
  grep -nE 'curl -' lib.sh
  grep -noE 'https?://[^ )"]+' lib.sh gelkao | sort -u
  ```
  Both `curl` calls use only `-sSfL -o` — no `--data`, `--upload-file`, or `-X POST` — so they can only GET.
- **The only telemetry is the price-pull request itself.** If you accept the refresh, `gelkao.com` sees a download request — a count of refreshes, nothing more: no invoice data, no analytics, no identifiers. Decline the prompt or pass `-q` and no request is made at all.
- **Billing data stays in `data/`**, which is gitignored.

## Dependencies (supply-chain surface)

Deliberately minimal: `bash`, `curl`, and `sqlite3`, plus standard text utilities (`grep`, `sed`). **No package manager, no build step, no third-party libraries, and no Python in the run path.** The whole tool is two readable shell files (`gelkao`, `lib.sh`) plus the SQL in `schema.sql` / `audit.sql` — auditable in one sitting.

## A note on the customer number

Fetching an invoice requires **two** secrets together: the per-invoice capability URL (`usage.hetzner.com/<uuid>`, supplied on stdin) and your account customer number (`K…`). Either one alone is insufficient.

When you pass the customer number as a command-line argument (`./gelkao K…`), it can appear in your shell history and in `ps` output. The customer number alone is not a complete credential (it still needs the per-invoice UUID, which is never placed on the command line), but to keep it out of your interactive history you can supply it through the `HETZNER_CN` environment variable set in your shell environment — for example from your secrets manager — rather than typing it inline.
