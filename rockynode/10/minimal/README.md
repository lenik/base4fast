# Shared pnpm store seed for upper-layer apps (mpss, cicc, …)

## In the image

```
/var/cache/pnpm/store          # content-addressable package bodies (CAFS)
/opt/minimal/package.json      # seed manifest
/opt/minimal/pnpm-lock.yaml    # required for `pnpm install --offline`
/etc/npmrc                     # store-dir=/var/cache/pnpm/store
```

Owned by user `node`. There is **no** long-lived `/opt/minimal/node_modules`.

## Store ≠ metadata

pnpm has two caches:

| Path | Role |
|------|------|
| `store-dir` (`/var/cache/pnpm/store`) | Package **files** (tarball contents) |
| `~/.cache/pnpm/metadata-v1.3/` | Registry **JSON** used to resolve versions |

`pnpm install --offline` **without a lockfile** still needs metadata to resolve `@fastify/jwt@9.1.0` → integrity.  
That is why you saw `ERR_PNPM_NO_OFFLINE_META` even with a full store.

**Fix:** always install with the lockfile present (resolution skipped → store only):

```bash
cd /opt/minimal
pnpm install --prod --offline
# needs package.json + pnpm-lock.yaml + store
# import method: pnpm auto (hardlink/clone when same filesystem)
```

`--prefer-offline` can fall back to the network for missing metadata.

## Upper apps

```bash
pnpm install --prod --prefer-offline   # store first; miss → registry
pnpm install --prod --offline          # needs lockfile + store (no metadata fetch)
```

`PNPM_STORE_DIR` / `store-dir` must be `/var/cache/pnpm/store`.
