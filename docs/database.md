# Pusa database foundation

The dedicated Pusa Supabase project is provisioned in the `pusa` organization.

- Project ref: `vfmgjrqmwnirbqbdbzdq`
- Region: `eu-west-3` (Europe West / Paris)
- PostgreSQL: 17
- Currency in MVP: XAF, stored as integer amounts
- All user-facing tables have Row-Level Security enabled.

## Schema modules

| Table | Purpose |
|---|---|
| `profiles` | User profile metadata linked to Supabase Auth |
| `pockets` | User-owned savings categories |
| `ledger_accounts` | Double-entry accounts for pocket liabilities and provider clearing |
| `allocation_plans` | Draft, active and archived allocation plans |
| `allocation_rules` | Percentage rules and deterministic ordering |
| `payment_intents` | Server-created deposit requests |
| `provider_events` | Verified, idempotent provider callback records |
| `ledger_transactions` | Immutable financial transaction headers |
| `ledger_entries` | Immutable debit/credit journal lines |
| `pocket_allocations` | Immutable amount and percentage snapshots per pocket |
| `notifications` | In-app user notifications |
| `audit_logs` | Security and operational audit history |

The `pocket_balances` view derives balances from ledger entries. Client applications must never write balances directly.

## Financial invariants

1. XAF amounts are integer values; no floating-point currency arithmetic.
2. A deposit may be posted only after the provider event is verified by a trusted server-side integration.
3. Provider event identity and transaction idempotency keys prevent duplicate posting.
4. Allocation plans must total exactly 100.00% and reference active pockets belonging to the same user.
5. Allocation is performed atomically; integer rounding remainder is assigned deterministically to the final priority rule.
6. Every posted ledger transaction must have equal, positive debit and credit totals.
7. Ledger transaction headers, entries and allocation snapshots are append-only. Corrections require reversal or adjustment transactions.
8. User RLS policies isolate profiles, pockets, plans, transactions and notifications.
9. Provider events have an explicit deny policy for browser/mobile roles; only trusted server-side processing may access them.
10. No Mobile Money PIN is requested or stored.

## Server-side deposit posting

The `post_verified_deposit(uuid)` database function is executable only by the Supabase service role. The future webhook handler must:

1. Authenticate the provider callback using the provider's documented signature/secret mechanism.
2. Validate the provider's transaction status, amount, currency, merchant reference and payment intent.
3. Persist the event as verified using server credentials.
4. Call `post_verified_deposit(event_id)`.
5. Reconcile provider settlement independently and alert on mismatches.

Do not expose the service-role key to Next.js browser code, Flutter, GitHub, or any public client.

## Allocation plan activation

Authenticated users can call `activate_allocation_plan(plan_id)`. The function runs with caller privileges and RLS, validates the 100.00% rule total and active pocket ownership, and switches the active plan. Direct client updates to plan status are rejected by a database trigger.

## Local environment

Copy `.env.example` to `.env.local` for the Next.js app. Use the Supabase URL and publishable key only in client apps. The service-role key is server-only and is not currently configured in Vercel because no server-side payment or admin function has been deployed yet.

## Live project migration history

The live project has been provisioned with these Supabase migrations:

- `initial_financial_foundation`
- `tighten_financial_security_and_balances_view`
- `validate_deposit_intent_and_allocation_rules`
- `tighten_privileges_and_add_indexes`
- `make_provider_event_client_access_explicitly_denied`
- `allow_internal_pocket_ledger_link_initialization` (fix discovered by transactional allocation smoke test)

The repository's `supabase/migrations/20261110000000_initial_schema.sql` is the consolidated fresh-environment baseline. Future schema changes must be added as new timestamped SQL migrations and applied to the Pusa project.
