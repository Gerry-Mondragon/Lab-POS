# Lab-POS

Point-of-sale system for small Mexican grocery stores (tiendas de abarrotes). The pilot store is Abarrotes Anny in Tultepec, Edo. Méx., running Chrome on a Windows PC at the counter.

## What is here

| Path | What it is |
| --- | --- |
| `docs/plan.md` | Product plan: MVP scope, phases, stack, data model sketch, security. Snapshot of the living plan doc. |
| `docs/ubuntu-db-server-setup.md` | Step-by-step setup of the PostgreSQL server on the store's Ubuntu PC (LAN only). |
| `db/migrations/` | PostgreSQL schema migrations, applied in numeric order. |

## Architecture in one paragraph

An offline-first PWA (React + TypeScript + Vite, Dexie/IndexedDB) runs the checkout on the store PC and never waits for the network. It syncs to a small Node API backed by PostgreSQL, which for the pilot runs on an Ubuntu PC on the store's LAN and later moves to a hosted server. Money is always integer centavos.

## Working together

See [CONTRIBUTING.md](CONTRIBUTING.md).
