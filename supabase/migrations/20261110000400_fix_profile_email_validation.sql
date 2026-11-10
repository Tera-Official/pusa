alter table public.profiles drop constraint if exists profiles_email_format_check;
alter table public.profiles
  add constraint profiles_email_format_check
  check (
    email is null or (
      email = btrim(email)
      and email ~* '^[A-Z0-9._%+-]+@[A-Z0-9.-]+[.][A-Z]{2,}$'
    )
  );
