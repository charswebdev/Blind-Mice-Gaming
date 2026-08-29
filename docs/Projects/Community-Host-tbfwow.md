# tbfwow.com community host

| Field | Value |
|-------|--------|
| Status | **Live** (Retail + Classic Era LPTM wired; other flavors reserved) |
| Type | PHP + MySQL community API |
| Folder | `tbfwow-lptm/` |
| Public base | `https://tbfwow.com/lptm/` |
| Config | `config.example.php` → server `config.php` (**never commit secrets**) |

## Description

Blind Mice Gaming’s **community catalog** for talent builds and (Retail) loadouts. Desktop LPTM/LPLM clients GET a build list and POST publish/unshare with an owner token. This is not Wowhead and not a quest database.

## Features / endpoints (locked map)

| URL | Table | Used by |
|-----|--------|---------|
| `/lptm/retail/` | `lptm_retail` | Retail LPTM |
| `/lptm/classic-era/` | `lptm_classic_era` | Classic Era LPTM (**wired**) |
| `/lptm/classic/` | `lptm_classic` | Future MoP/Classic LPTM |
| `/lptm/anniversary/` | `lptm_anniversary` | Future Anniversary LPTM |
| `/lptm/loadouts/` | loadouts tables | Retail LPLM |
| `/lptm/loadouts/classic-era/` | (planned) | Era LPLM |
| roster PHP | roster | related desktop |

Local repo also has WIP `bootstrap.php`, `catalog.php`, `loadouts.php`, `roster.php`, `.htaccess` — treat as host source, not player-facing addons.

## Development plan

1. Retail LPTM community first.
2. Generic table shape (`trees`, `talent_string`, class/spec/hero columns) so Era can stub `spec_id="trees"`, `hero_id="era"`.
3. Wire Era URL when LPTM Classic Era shipped.
4. Loadouts API as a **separate** body-size/rate-limit path (`max_loadout_body` vs talent `max_body`).
5. Reserve classic/anniversary tables in `create-tables.sql` before those apps exist.

Rate limits (example config): `max_shares_per_token`, `max_posts_per_ip_hour`, peppered owner hashes — not plaintext Battle.net IDs.

## Sources and data

- Client-uploaded JSON builds (talent snapshots + strings).
- No Blizzard DB2.
- Do not store Wowhead HTML dumps as the catalog.

## What worked

- One PHP flavor switch instead of four unrelated apps.
- After a failed PDO connect, `community.php` now matches `loadouts.php`: `fail()` is `: never` and `$pdo` is checked with `isset` before GET/POST use, so Intelephense P1116 is gone.
- Owner hash + token so “unshare” does not require a BMG account system.
- Era community going live with GET verified in the LPTM ship session.

## What did not work

- Leaving Era `communityUrl` empty while the host already had `classic-era`.
- Putting MySQL passwords in `create-tables.sql` or committing `config.php`.
- Mixing talent rows and loadout blobs in one size limit (loadouts need a larger max body).

## Open work

- Confirm live loadouts/classic-era routes when Era LPLM is built.
- Deploy `loadouts.php` so Retail LPLM titles may include `>`, `|`, and `<` (was stripping `<>`).
- Deploy `community.php` so Retail and Era LPTM names may include `>`, `|`, and `<` (was stripping `<>`).
- Local uncommitted `tbfwow-lptm/` PHP — do not mix into addon version bumps.
- QA share/unshare against production.
