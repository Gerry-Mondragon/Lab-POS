# Contributing

## Flow

1. Pick or open an Issue. Issues are labeled by phase (`phase-1-mvp`, `phase-2`, ...) and tracked on the project board.
2. Branch from `main`: `feature/<short-name>`, `fix/<short-name>` or `docs/<short-name>`.
3. Open a pull request early. Every change to `main` goes through a PR with at least one review from the other maintainer.
4. Squash-merge when approved and checks pass.

## Rules that are not negotiable

- **Money is integer centavos.** No floats for prices, totals, taxes or change.
- **Offline first.** A sale must complete with no network. Client-generated UUIDs for every record.
- **Append-only money and stock.** Sales, payments and stock movements are never edited or deleted; fix mistakes with a void or adjustment row.
- **No secrets in the repo.** Passwords and keys go in `.env` files that are git-ignored.

## Database changes

- Add a new numbered file in `db/migrations/` (`0002_<what>.sql`). Never edit a migration that has already run on the store server.
- Wrap each migration in `BEGIN; ... COMMIT;`.
- Apply it as `pos_owner` on the Docker database:
  ```bash
  docker exec -i pos-db psql -U pos_owner -d abarrotes_pos -v ON_ERROR_STOP=1 < db/migrations/0002_<what>.sql
  ```
- Local development uses the same `compose.yaml`: copy `.env.example` to `.env`, set `DB_BIND_IP=127.0.0.1`, then `docker compose up -d`.

## Language

UI text is Spanish (es-MX). Code, identifiers, commits and PRs are in English.
