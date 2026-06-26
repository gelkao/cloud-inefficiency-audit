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

`gelkao` runs entirely on your machine and only ever **pulls** — it never uploads your invoices anywhere. The full data model is in the README under **"Your data stays on your disk."**

These properties are verifiable from the source — you do not have to take our word for it:

- **One network destination.** The only outbound request is a `curl` to `https://usage.hetzner.com/...`, which downloads *your own* invoices. Verify:
  ```
  grep -n curl lib.sh          # one call, line 47
  grep -noE 'https?://[^ )"]+' lib.sh gelkao | sort -u
  ```
  The `https://gelkao.com` string is a printed banner (stderr), not a request.
- **No telemetry, no analytics, no third-party endpoints.**
- **Billing data stays in `data/`**, which is gitignored.

## Dependencies (supply-chain surface)

Deliberately minimal: `bash`, `curl`, and `sqlite3`, plus standard text utilities (`grep`, `sed`). **No package manager, no build step, no third-party libraries, and no Python in the run path.** The whole tool is two readable shell files (`gelkao`, `lib.sh`) plus the SQL in `schema.sql` / `audit.sql` — auditable in one sitting.

## A note on the customer number

Fetching an invoice requires **two** secrets together: the per-invoice capability URL (`usage.hetzner.com/<uuid>`, supplied on stdin) and your account customer number (`K…`). Either one alone is insufficient.

When you pass the customer number as a command-line argument (`./gelkao K…`), it can appear in your shell history and in `ps` output. The customer number alone is not a complete credential (it still needs the per-invoice UUID, which is never placed on the command line), but to keep it out of your interactive history you can supply it through the `HETZNER_CN` environment variable set in your shell environment — for example from your secrets manager — rather than typing it inline.
