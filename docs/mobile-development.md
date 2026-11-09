# Pusa mobile development plan

## Architecture

- `apps/mobile`: Flutter Android/iOS client (Android is the first testing target).
- Repository root: Next.js web application.
- Shared backend: dedicated Pusa Supabase project, subject to project-capacity resolution.
- Financial authority: server-side verified payment events and immutable ledger operations.

## Mobile delivery stages

1. Flutter project scaffold and device setup.
2. Authentication and onboarding.
3. Personal profile and pocket management.
4. Allocation plan editor with exact 100% validation.
5. Dashboard and transaction history backed by Supabase.
6. Simulated deposits and allocation engine integration tests.
7. Approved payment provider sandbox integration and webhook reconciliation.
8. In-app and push notifications.
9. Device security, accessibility, low-bandwidth and Android compatibility testing.

## Current implementation boundary

The first mobile commit is a visual and navigation preview. Demo balances are static and explicitly labelled. It is not yet connected to production user data and must not be used to represent real stored value.

## Backend provisioning blocker

The existing Supabase organization has reached its maximum of two active free projects. The existing projects are unrelated and must remain isolated. Options are to pause an unused project, delete an unused project, or upgrade the Supabase organization plan. Do not select or alter an existing project without explicit direction.
