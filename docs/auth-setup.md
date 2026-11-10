# Pusa phone authentication setup

## Implemented client flow

The Flutter app now includes:
- Phone-number and password sign-in.
- Account registration with full name, email, E.164 phone number and password.
- SMS OTP verification after registration.
- SMS OTP-based password recovery.
- Password update after a successful recovery OTP.
- Profile display, name updates and sign-out.
- Signup consent capture metadata and server-created profile records.

The phone number is the authentication identifier. Email is stored as profile contact information and is not yet used as a login identifier.

## Required Supabase configuration

The app uses Supabase Auth phone authentication. SMS delivery will not work until a supported SMS provider is configured for the dedicated Pusa Supabase project.

1. Open the Pusa Supabase project.
2. Go to Authentication settings and open the Phone provider configuration.
3. Enable phone sign-ups and phone confirmations.
4. Configure a supported SMS provider and its credentials.
5. Configure the OTP message template and sensible expiry/rate limits.
6. Keep production credentials in Supabase's provider settings; never put SMS-provider secrets in Flutter or GitHub.
7. Test with an approved test phone number before inviting users.

Do not treat an account as phone-verified until Supabase confirms the OTP. Do not request or store Mobile Money PINs.

## Running the app against Pusa

From `apps/mobile`:

```bash
flutter pub get
flutter run \\
  --dart-define=SUPABASE_URL=https://vfmgjrqmwnirbqbdbzdq.supabase.co \\
  --dart-define=SUPABASE_ANON_KEY=YOUR_PUSA_SUPABASE_PUBLISHABLE_KEY
```

Only the Supabase publishable key may be embedded in the client. Never use the service-role key in Flutter, a browser, or a public repository.

## Database profile behaviour

The Auth user creation trigger creates the matching `public.profiles` row and records the display name, signup email, and phone number. The database stores the phone and email on the profile, while Auth remains the authority for credentials and phone verification.

Profile row access is restricted by RLS to the owning authenticated user. The client can update only `display_name`; phone and email changes must use a dedicated verified account-change flow.

Consent timestamps and the consent version are captured from the registration flow. The current consent labels are implementation placeholders; approved Terms of Service and Privacy Notice content must be published and reviewed before production onboarding.

## Current limitations

- SMS provider setup is an external prerequisite and has not been confirmed.
- Email verification and verified email-change flows are not included.
- Account deletion/export requests and MFA are not yet implemented.
- This release does not enable deposits, withdrawals or live balances.
