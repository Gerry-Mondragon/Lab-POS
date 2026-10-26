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
- Apply it as `pos_owner`:
  ```bash
  psql -h <server-ip> -U pos_owner -d abarrotes_pos -v ON_ERROR_STOP=1 -f db/migrations/0002_<what>.sql
  ```

## Language

UI text is Spanish (es-MX). Code, identifiers, commits and PRs are in English.
