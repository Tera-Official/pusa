# Pusa MVP — Initial Architecture

## 1. Product boundary

The first release is a personal financial management and allocation platform for Cameroon, denominated in XAF. It is not a bank, unrestricted wallet, lender, or custodian of customer funds.

The UI must distinguish:
- **External money:** funds confirmed by an authorized payment provider.
- **Pusa ledger allocation:** accounting partitions of a verified amount.
- **Actual money movement:** a separate provider-backed transfer or withdrawal.

A pocket balance is an accounting view unless and until an approved custody and funds-flow arrangement makes it a claim on safeguarded funds.

## 2. Runtime architecture

- Next.js + TypeScript responsive web application/PWA.
- Supabase PostgreSQL as the source of truth.
- Supabase Auth for identity and sessions.
- PostgreSQL Row Level Security for tenant/user isolation.
- Server-side route handlers or trusted database functions for financial commands.
- Vercel for web deployment and preview environments.
- One payment provider adapter initially; provider choice depends on verified Cameroon coverage, merchant onboarding, callbacks, settlement and commercial terms.

Start with a modular monolith. Do not introduce Redis, BullMQ, a separate NestJS service, Flutter, WhatsApp or AI services until demonstrated MVP needs justify them.

## 3. Core financial flow

1. User creates pockets and an allocation plan.
2. Allocation plan is validated to total exactly 100%.
3. User initiates a deposit through the selected provider.
4. Provider callback is authenticated and independently verified.
5. A unique provider transaction reference is stored under a unique constraint.
6. A single database transaction posts the deposit and balanced journal entries.
7. The same transaction snapshots the active allocation plan and posts pocket allocations.
8. The event is marked processed only after all postings succeed.
9. Duplicate callbacks return the original result and do not create another credit.
10. Reversals are new compensating journal transactions, never edits to posted entries.

## 4. Ledger invariants

- Monetary values are integer XAF amounts; do not use floating-point arithmetic.
- Every posted journal transaction balances: total debits equal total credits.
- Posted journal entries are immutable.
- Every financial command has a unique idempotency key.
- Allocation totals equal the verified deposit amount exactly.
- Rounding/remainder handling is deterministic and tested.
- Balances are derived from ledger postings or maintained only through transactionally consistent database procedures.
- Client applications cannot directly update financial balances or journal rows.

## 5. Initial data domains

- profiles
- financial_accounts
- pockets
- allocation_plans
- allocation_rules
- payment_intents
- provider_events
- ledger_transactions
- journal_entries
- pocket_allocations
- withdrawals (disabled until operating model approval)
- notifications
- audit_logs

All user-owned records require explicit ownership constraints and RLS policies. Service-role credentials must remain server-side.

## 6. Security and operational controls

- RLS enabled and tested for every user-owned table.
- Least-privilege database roles.
- Server-side validation for all financial commands.
- Webhook signature/authentication and provider-side status verification.
- Replay protection, idempotency, rate limiting and audit trails.
- No Mobile Money PIN collection or storage.
- Secrets held in Vercel/Supabase secret stores, never committed.
- Database migrations version-controlled in this repository.
- Automated tests for allocation arithmetic, ledger balance, idempotency, rollback, RLS and reversals.
- Backups and restore drills before pilot.

## 7. Explicit release gates

Real-money collection, customer balances represented as withdrawable funds, and withdrawals remain disabled until:
- the legal operating model and applicable BEAC/COBAC/Cameroon requirements are reviewed;
- the custody/safeguarding arrangement is documented;
- the payment provider confirms merchant eligibility, supported operations and settlement;
- reconciliation, reversals, support and incident processes are tested.

## 8. Deferred features

Business Mode workflows, dividends, Social Pots, Swift Credit, WhatsApp assistant, SMS/notification scraping, gamification, behavioral nudges, multi-country support and AI are not first-MVP blockers.
