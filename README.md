# Pusa — Smart Saving

**Receive. Allocate. Protect. Grow.**

Pusa is a Cameroon-first personal money management platform. Its MVP helps users organize money into purpose-based pockets and apply percentage-based allocation rules to verified deposits.

## MVP scope

- Secure account registration and profile management
- Personal financial dashboard
- Create and manage financial pockets
- Percentage-based allocation plans (must total 100%)
- Verified deposit ingestion through one supported provider
- Atomic allocation processing
- Auditable double-entry ledger
- Transaction history and essential notifications
- Administrative reconciliation and audit tools

Business accounting, Social Pots, Swift Credit, WhatsApp assistant, gamification, and advanced AI are deferred beyond the first MVP.

## Initial technology direction

- **Web/PWA:** Next.js + TypeScript (repository root)
- **Mobile:** Flutter + Dart (Android-first, under `apps/mobile`)
- **Mobile:** Flutter + Dart (Android-first, under `apps/mobile`)
- **Database and authentication:** Supabase (PostgreSQL, Auth, Row Level Security)
- **Hosting:** Vercel
- **Payments:** One provider integration first, subject to commercial access and legal review
- **Currency:** XAF

The implementation should begin as a modular monolith. Financial posting and allocation must be enforced by trusted server-side/database operations, never by client-side balance updates.

## Financial safety rules

1. A payment initiation is not proof of receipt.
2. Only verified provider events may credit a deposit.
3. Every event must be idempotent.
4. Ledger entries are immutable; corrections use reversals.
5. Allocation must be atomic and exactly reconcile to the verified deposit.
6. Monetary calculations use integer XAF minor units (XAF has no decimal subunit in this MVP).
7. Pusa must not collect or store Mobile Money PINs.
8. No real customer funds or withdrawals are enabled until the custody, licensed-partner and regulatory operating model is approved.

## Repository structure (target)

```
apps/
  mobile/              # Flutter Android/iOS client
packages/
  domain/              # Financial domain types and allocation rules
supabase/
  migrations/          # Version-controlled SQL migrations
  tests/               # Database and RLS tests
docs/
  architecture.md
  database.md
  mobile-development.md
  decisions/
.env.example
```

## Local development

For web setup, copy `.env.example` to `.env.local` and use development-only credentials. For Android device testing, hot reload and APK builds, see [apps/mobile/README.md](apps/mobile/README.md). Never commit secrets.

## Supabase database

The dedicated Pusa Supabase project is provisioned in the `pusa` organization. Its schema, RLS controls and financial invariants are documented in [docs/database.md](docs/database.md). The consolidated SQL baseline is in `supabase/migrations/`.

## Project documents

The product SRS and MVP specification are the baseline. Any implementation change must preserve the MVP acceptance criteria and be documented.
