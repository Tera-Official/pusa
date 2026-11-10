-- Store signup email and the authenticated phone number on the user's profile.
alter table public.profiles add column if not exists email text;

update public.profiles p
set email = u.email
from auth.users u
where u.id = p.id and p.email is null and u.email is not null;

create unique index if not exists profiles_email_unique_idx
on public.profiles (lower(email))
where email is not null;

alter table public.profiles
  add constraint profiles_email_format_check
  check (email is null or (email = btrim(email) and email ~* '^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$'));

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles(id, display_name, email, phone_e164)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'display_name', new.raw_user_meta_data->>'full_name'),
    nullif(lower(btrim(new.raw_user_meta_data->>'email')), ''),
    nullif(new.phone, '')
  )
  on conflict (id) do update
    set display_name = coalesce(public.profiles.display_name, excluded.display_name),
        email = coalesce(public.profiles.email, excluded.email),
        phone_e164 = coalesce(public.profiles.phone_e164, excluded.phone_e164);
  return new;
end;
$$;

revoke update(display_name, phone_e164) on public.profiles from authenticated;
grant update(display_name) on public.profiles to authenticated;
