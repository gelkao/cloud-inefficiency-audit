# cloud-efficiency-calculator

## Get invoice list as HTML

- Go to: https://accounts.hetzner.com/invoice
- Save the page as HTML into the `data/` directory ![Save page as HTML](img/hetzner-invoice.png)

Then extract the UUIDs from all saved pages:

```
cat data/*.html | ./list_invoices.sh
```

## list_invoices.sh(1)

**NAME**

list_invoices.sh — extract Hetzner invoice UUIDs from saved invoice HTML

**SYNOPSIS**

```
cat data/*.html | ./list_invoices.sh
```

**DESCRIPTION**

Reads Hetzner "Administer invoices" HTML on stdin and prints the UUID of each
invoice, one per line. UUIDs are scraped from the per-invoice detail links of
the form `https://usage.hetzner.com/<uuid>`. By convention the saved invoice
pages are kept in the `data/` directory.

**OUTPUT**

One UUID per line, in page order. Not de-duplicated — pipe through `sort -u`
when concatenating multiple pages (`cat data/*.html | ...`).

**EXIT STATUS**

`0` UUIDs found · `1` none found (prints a warning to stderr — usually means
Hetzner changed the URL scheme).

**LIMITATIONS**

Only post-2024-10-01 invoices are listed. The `usage.hetzner.com/<uuid>` detail
link is the new itemized-invoice format Hetzner rolled out on 1 Oct 2024; older
invoices use numeric IDs (`/invoice/<id>/pdf`) with no UUID and are
intentionally skipped. Expect fewer UUIDs than the page's total row count when
old invoices are present.

**EXAMPLES**

```
cat data/invoice-list.html | ./list_invoices.sh
cat data/*.html | ./list_invoices.sh | sort -u
```

## References

- [Hetzner 2024-10 Billing System Changes](https://docs.hetzner.com/general/billing-and-account-management/billing-at-hetzner/billing-system-hetzner/)
