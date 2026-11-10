-- Fix initial pocket account provisioning while keeping ledger links immutable to clients.
create or replace function public.create_pocket_ledger_account()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_account_id uuid;
begin
  insert into public.ledger_accounts(user_id,pocket_id,account_code,account_name,account_type,currency)
  values (new.user_id,new.id,'pocket:'||new.id::text,new.name,'liability','XAF')
  returning id into v_account_id;

  perform set_config('pusa.creating_pocket_account','on',true);
  update public.pockets set ledger_account_id=v_account_id where id=new.id;
  perform set_config('pusa.creating_pocket_account','off',true);
  return new;
end;
$$;

create or replace function public.guard_pocket_update()
returns trigger language plpgsql set search_path = public as $$
begin
  if new.user_id is distinct from old.user_id then
    raise exception 'Pocket ownership cannot be changed';
  end if;
  if new.ledger_account_id is distinct from old.ledger_account_id
     and not (
       old.ledger_account_id is null
       and new.ledger_account_id is not null
       and current_setting('pusa.creating_pocket_account',true)='on'
     ) then
    raise exception 'Pocket ledger account cannot be changed';
  end if;
  if old.status='active' and new.status='archived' and exists (
    select 1 from public.allocation_rules r
    join public.allocation_plans ap on ap.id=r.plan_id
    where r.pocket_id=old.id and ap.status='active'
  ) then
    raise exception 'Remove this pocket from the active allocation plan before archiving it';
  end if;
  return new;
end;
$$;
