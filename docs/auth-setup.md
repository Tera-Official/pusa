# Pusa email and password authentication setup

## Implemented Flutter flow

The mobile app uses Supabase email/password authentication:
- Account registration with full name, email and password.
- Required Terms of Service and Privacy Notice consent capture.
- Email confirmation before normal sign-in (when email confirmation is enabled in Supabase).
- Email/password sign-in.
- Email-based password recovery and password update.
- Profile display, name updates and sign-out.
- Phone authentication is not offered in this release; it remains a future option until an SMS provider is configured.

Supabase Auth is the authority for credentials and email verification. The matching `public.profiles` row stores the normalized email and display name for profile display. Do not use user-editable metadata for authorization decisions.

## Required Supabase Auth configuration

In the Pusa Supabase project:

1. Open **Authentication → Providers → Email**.
2. Ensure Email provider is enabled.
3. Enable **Confirm email**. Users must verify their email before normal password sign-in.
4. Leave the Phone provider disabled until an SMS provider and phone-verification workflow are deliberately introduced.
5. Open **Authentication → URL Configuration**.
6. Add this exact value to **Additional Redirect URLs**:

   `com.teraofficial.pusa://login-callback`

7. Configure the email confirmation and password recovery templates to use the redirect URL supplied by the client (Supabase's `{{ .RedirectTo }}` template variable where applicable).
8. Test confirmation and recovery links on a physical Android device with Pusa installed.

The Android manifest registers the callback scheme and host. Supabase Flutter handles the incoming auth deep link and session exchange.

## Email delivery

Supabase's built-in email sender is intended for evaluation and has best-effort delivery and strict rate limits. Before inviting real users, configure a production SMTP provider in **Authentication → SMTP Settings**, verify sender/domain authentication, and test confirmation and recovery messages. Do not put SMTP credentials in Flutter, GitHub, or client-visible environment variables.

## Running the app against Pusa

From `apps/mobile`:

```bash
flutter pub get
flutter run \
  --dart-define=SUPABASE_URL=https://vfmgjrqmwnirbqbdbzdq.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_PUSA_SUPABASE_PUBLISHABLE_KEY
```

Only the Supabase publishable key may be embedded in the client. Never use the service-role key in Flutter, a browser, or a public repository.

## Database profile behaviour

The Auth user creation trigger creates the matching `public.profiles` row and copies the normalized email from `auth.users.email` (falling back to signup metadata only for compatibility). It also captures the display name and onboarding consent metadata. Auth remains the authority for credentials and verification.

Profile row access is restricted by RLS to the owning authenticated user. The client can update only `display_name`; email changes must use a dedicated verified account-change flow.

Consent timestamps and the consent version are captured from registration metadata. The current consent labels are implementation placeholders; approved Terms of Service and Privacy Notice content must be published and reviewed before production onboarding.

## Security and release limitations

- Never request or store Mobile Money PINs.
- No deposits, withdrawals or live-money operations are enabled by this authentication work.
- Email delivery is not production-ready until custom SMTP and sender verification are completed.
- Account deletion/export requests and MFA are not yet implemented.
- Before accepting real customer funds, the operating, custody and regulatory arrangements must be approved.
