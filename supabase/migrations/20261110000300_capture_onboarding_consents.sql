-- Capture required onboarding consents for new Pusa accounts.
alter table public.profiles
  add column if not exists terms_accepted_at timestamptz,
  add column if not exists privacy_accepted_at timestamptz,
  add column if not exists consent_version text;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles(
    id, display_name, email, phone_e164,
    terms_accepted_at, privacy_accepted_at, consent_version
  )
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'display_name', new.raw_user_meta_data->>'full_name'),
    nullif(lower(btrim(new.raw_user_meta_data->>'email')), ''),
    nullif(new.phone, ''),
    case when new.raw_user_meta_data->>'terms_accepted' = 'true' then now() else null end,
    case when new.raw_user_meta_data->>'privacy_accepted' = 'true' then now() else null end,
    nullif(new.raw_user_meta_data->>'consent_version', '')
  )
  on conflict (id) do update
    set display_name = coalesce(public.profiles.display_name, excluded.display_name),
        email = coalesce(public.profiles.email, excluded.email),
        phone_e164 = coalesce(public.profiles.phone_e164, excluded.phone_e164),
        terms_accepted_at = coalesce(public.profiles.terms_accepted_at, excluded.terms_accepted_at),
        privacy_accepted_at = coalesce(public.profiles.privacy_accepted_at, excluded.privacy_accepted_at),
        consent_version = coalesce(public.profiles.consent_version, excluded.consent_version);
  return new;
end;
$$;
