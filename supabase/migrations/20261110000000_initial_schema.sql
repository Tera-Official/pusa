-- Pusa Smart Saving: initial schema baseline
-- Currency amounts are integer XAF. Client apps cannot post or mutate ledger rows.
create extension if not exists pgcrypto with schema extensions;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  phone_e164 text,
  preferred_currency char(3) not null default 'XAF' check (preferred_currency = 'XAF'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.set_updated_at()
returns trigger language plpgsql set search_path = public as $$
begin new.updated_at = now(); return new; end; $$;

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles(id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'display_name', new.raw_user_meta_data->>'full_name'))
  on conflict (id) do nothing;
  return new;
end; $$;

create trigger on_auth_user_created after insert on auth.users
for each row execute function public.handle_new_user();
create trigger profiles_set_updated_at before update on public.profiles
for each row execute function public.set_updated_at();

create table public.pockets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (length(trim(name)) between 1 and 60),
  description text,
  color_key text not null default 'lime',
  icon_key text not null default 'savings',
  status text not null default 'active' check (status in ('active','archived')),
  is_locked boolean not null default false,
  ledger_account_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, user_id)
);
create trigger pockets_set_updated_at before update on public.pockets
for each row execute function public.set_updated_at();

create table public.ledger_accounts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete restrict,
  pocket_id uuid references public.pockets(id) on delete restrict,
  account_code text not null,
  account_name text not null,
  account_type text not null check (account_type in ('asset','liability','equity','income','expense')),
  currency char(3) not null default 'XAF' check (currency = 'XAF'),
  created_at timestamptz not null default now(),
  unique (account_code, currency),
  unique (pocket_id)
);
alter table public.pockets add constraint pockets_ledger_account_fk
foreign key (ledger_account_id) references public.ledger_accounts(id) on delete restrict;

create or replace function public.create_pocket_ledger_account()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_account_id uuid;
begin
  insert into public.ledger_accounts(user_id,pocket_id,account_code,account_name,account_type,currency)
  values (new.user_id,new.id,'pocket:'||new.id::text,new.name,'liability','XAF')
  returning id into v_account_id;
  update public.pockets set ledger_account_id = v_account_id where id = new.id;
  return new;
end; $$;
create trigger pockets_create_ledger_account after insert on public.pockets
for each row execute function public.create_pocket_ledger_account();

create table public.allocation_plans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (length(trim(name)) between 1 and 80),
  status text not null default 'draft' check (status in ('draft','active','archived')),
  currency char(3) not null default 'XAF' check (currency = 'XAF'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index allocation_plans_one_active_per_user
on public.allocation_plans(user_id) where status = 'active';
create trigger allocation_plans_set_updated_at before update on public.allocation_plans
for each row execute function public.set_updated_at();

create table public.allocation_rules (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.allocation_plans(id) on delete cascade,
  pocket_id uuid not null references public.pockets(id) on delete restrict,
  percentage numeric(5,2) not null check (percentage > 0 and percentage <= 100),
  priority integer not null default 100,
  created_at timestamptz not null default now(),
  unique (plan_id,pocket_id)
);

create table public.payment_intents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete restrict,
  provider text not null,
  amount_xaf bigint not null check (amount_xaf > 0),
  currency char(3) not null default 'XAF' check (currency = 'XAF'),
  status text not null default 'created'
    check (status in ('created','pending','succeeded','failed','cancelled','expired')),
  provider_reference text,
  idempotency_key text not null,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id,idempotency_key),
  unique (provider,provider_reference)
);
create trigger payment_intents_set_updated_at before update on public.payment_intents
for each row execute function public.set_updated_at();

create table public.ledger_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete restrict,
  transaction_type text not null check (transaction_type in ('deposit','allocation','withdrawal','transfer','reversal','adjustment')),
  status text not null default 'posted' check (status in ('posted','reversed')),
  amount_xaf bigint not null check (amount_xaf > 0),
  currency char(3) not null default 'XAF' check (currency = 'XAF'),
  idempotency_key text not null,
  source_provider text,
  source_reference text,
  description text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (user_id,idempotency_key),
  unique (source_provider,source_reference)
);

create table public.provider_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete restrict,
  payment_intent_id uuid references public.payment_intents(id) on delete restrict,
  provider_name text not null,
  external_event_id text not null,
  event_type text not null,
  verification_status text not null check (verification_status in ('received','verified','rejected')),
  processing_status text not null default 'pending' check (processing_status in ('pending','processing','processed','failed')),
  amount_xaf bigint not null check (amount_xaf > 0),
  currency char(3) not null default 'XAF' check (currency = 'XAF'),
  payload jsonb not null default '{}'::jsonb,
  processed_transaction_id uuid references public.ledger_transactions(id) on delete restrict,
  received_at timestamptz not null default now(),
  processed_at timestamptz,
  unique (provider_name,external_event_id)
);

create table public.ledger_entries (
  id uuid primary key default gen_random_uuid(),
  transaction_id uuid not null references public.ledger_transactions(id) on delete restrict,
  account_id uuid not null references public.ledger_accounts(id) on delete restrict,
  entry_side text not null check (entry_side in ('debit','credit')),
  amount_xaf bigint not null check (amount_xaf > 0),
  created_at timestamptz not null default now()
);

create table public.pocket_allocations (
  id uuid primary key default gen_random_uuid(),
  transaction_id uuid not null references public.ledger_transactions(id) on delete restrict,
  pocket_id uuid not null references public.pockets(id) on delete restrict,
  amount_xaf bigint not null check (amount_xaf > 0),
  percentage_snapshot numeric(5,2) not null check (percentage_snapshot > 0 and percentage_snapshot <= 100),
  created_at timestamptz not null default now(),
  unique (transaction_id,pocket_id)
);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  category text not null,
  title text not null,
  body text not null,
  data jsonb not null default '{}'::jsonb,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  actor_id uuid,
  action text not null,
  resource_type text not null,
  resource_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index allocation_rules_plan_idx on public.allocation_rules(plan_id,priority,id);
create index allocation_rules_pocket_idx on public.allocation_rules(pocket_id);
create index ledger_transactions_user_created_idx on public.ledger_transactions(user_id,created_at desc);
create index ledger_entries_transaction_idx on public.ledger_entries(transaction_id);
create index ledger_entries_account_idx on public.ledger_entries(account_id,created_at desc);
create index notifications_user_created_idx on public.notifications(user_id,created_at desc);
create index audit_logs_user_idx on public.audit_logs(user_id);
create index ledger_accounts_user_idx on public.ledger_accounts(user_id);
create index pocket_allocations_pocket_idx on public.pocket_allocations(pocket_id);
create index pockets_ledger_account_idx on public.pockets(ledger_account_id);
create index pockets_user_idx on public.pockets(user_id);
create index provider_events_intent_idx on public.provider_events(payment_intent_id);
create index provider_events_processed_transaction_idx on public.provider_events(processed_transaction_id);
create index provider_events_user_idx on public.provider_events(user_id);
create index ledger_transactions_user_created_idx2 on public.ledger_transactions(user_id,created_at desc);

create or replace function public.reject_financial_row_mutation()
returns trigger language plpgsql set search_path = public as $$
begin raise exception 'Financial records are immutable; post a reversal or adjustment instead'; end; $$;
create trigger ledger_transactions_immutable before update or delete on public.ledger_transactions
for each row execute function public.reject_financial_row_mutation();
create trigger ledger_entries_immutable before update or delete on public.ledger_entries
for each row execute function public.reject_financial_row_mutation();
create trigger pocket_allocations_immutable before update or delete on public.pocket_allocations
for each row execute function public.reject_financial_row_mutation();

create or replace function public.assert_ledger_transaction_balanced()
returns trigger language plpgsql set search_path = public as $$
declare v_tx uuid; v_debits numeric; v_credits numeric;
begin
  v_tx := coalesce(new.transaction_id,old.transaction_id);
  select coalesce(sum(amount_xaf) filter(where entry_side='debit'),0),
         coalesce(sum(amount_xaf) filter(where entry_side='credit'),0)
  into v_debits,v_credits from public.ledger_entries where transaction_id=v_tx;
  if v_debits <= 0 or v_debits <> v_credits then
    raise exception 'Unbalanced ledger transaction %: debits %, credits %',v_tx,v_debits,v_credits;
  end if;
  return null;
end; $$;
create constraint trigger ledger_entries_balance_check
after insert or update or delete on public.ledger_entries
deferrable initially deferred for each row execute function public.assert_ledger_transaction_balanced();

create or replace function public.guard_allocation_plan_status()
returns trigger language plpgsql set search_path = public as $$
begin
  if new.status is distinct from old.status
     and current_setting('pusa.activating_plan',true) is distinct from 'on' then
    raise exception 'Use activate_allocation_plan() to change allocation plan status';
  end if;
  if new.user_id is distinct from old.user_id then raise exception 'Allocation plan ownership cannot be changed'; end if;
  return new;
end; $$;
create trigger allocation_plan_status_guard before update on public.allocation_plans
for each row execute function public.guard_allocation_plan_status();

create or replace function public.guard_pocket_update()
returns trigger language plpgsql set search_path = public as $$
begin
  if new.user_id is distinct from old.user_id or new.ledger_account_id is distinct from old.ledger_account_id then
    raise exception 'Pocket ownership and ledger account cannot be changed';
  end if;
  if old.status='active' and new.status='archived' and exists (
    select 1 from public.allocation_rules r join public.allocation_plans ap on ap.id=r.plan_id
    where r.pocket_id=old.id and ap.status='active'
  ) then raise exception 'Remove this pocket from the active allocation plan before archiving it'; end if;
  return new;
end; $$;
create trigger pocket_update_guard before update on public.pockets
for each row execute function public.guard_pocket_update();

create or replace function public.activate_allocation_plan(p_plan_id uuid)
returns void language plpgsql security invoker set search_path = public as $$
declare v_user_id uuid; v_total numeric(7,2); v_count integer;
begin
  select user_id into v_user_id from public.allocation_plans where id=p_plan_id for update;
  if v_user_id is null then raise exception 'Allocation plan not found'; end if;
  if auth.uid() is not null and auth.uid()<>v_user_id then raise exception 'Not authorized'; end if;
  select coalesce(sum(r.percentage),0),count(*) into v_total,v_count
  from public.allocation_rules r join public.pockets p on p.id=r.pocket_id and p.user_id=v_user_id
  where r.plan_id=p_plan_id and p.status='active';
  if v_count=0 or v_total<>100.00 then
    raise exception 'Allocation rules must reference active pockets and total exactly 100.00%%';
  end if;
  perform set_config('pusa.activating_plan','on',true);
  update public.allocation_plans set status='archived'
    where user_id=v_user_id and status='active' and id<>p_plan_id;
  update public.allocation_plans set status='active' where id=p_plan_id;
  perform set_config('pusa.activating_plan','off',true);
end; $$;

create or replace function public.post_verified_deposit(p_provider_event_id uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  e public.provider_events%rowtype; pi public.payment_intents%rowtype;
  v_plan uuid; v_tx uuid; v_clearing uuid; r record;
  v_remaining bigint; v_piece bigint; v_rule_count integer; v_valid_count integer;
  v_index integer:=0; v_total numeric(7,2);
begin
  select * into e from public.provider_events where id=p_provider_event_id for update;
  if not found then raise exception 'Provider event not found'; end if;
  if e.verification_status<>'verified' then raise exception 'Provider event has not been verified'; end if;
  if e.processed_transaction_id is not null then return e.processed_transaction_id; end if;

  if e.payment_intent_id is not null then
    select * into pi from public.payment_intents where id=e.payment_intent_id for update;
    if not found or pi.user_id<>e.user_id or pi.amount_xaf<>e.amount_xaf
       or pi.currency<>e.currency or pi.provider<>e.provider_name
       or pi.status not in ('created','pending') then
      raise exception 'Provider event does not match an eligible payment intent';
    end if;
  end if;

  select id into v_plan from public.allocation_plans
  where user_id=e.user_id and status='active' order by created_at desc limit 1;
  if v_plan is null then raise exception 'No active allocation plan'; end if;

  select coalesce(sum(percentage),0),count(*) into v_total,v_rule_count
  from public.allocation_rules where plan_id=v_plan;
  select count(*) into v_valid_count from public.allocation_rules ar
  join public.pockets p on p.id=ar.pocket_id
  where ar.plan_id=v_plan and p.user_id=e.user_id and p.status='active';
  if v_rule_count=0 or v_total<>100.00 or v_valid_count<>v_rule_count then
    raise exception 'Active allocation plan is invalid or references inactive pockets';
  end if;

  insert into public.ledger_accounts(user_id,account_code,account_name,account_type,currency)
  values(null,'provider-clearing:'||e.currency,'Verified provider clearing','asset',e.currency)
  on conflict(account_code,currency) do update set account_name=excluded.account_name
  returning id into v_clearing;

  insert into public.ledger_transactions(
    user_id,transaction_type,amount_xaf,currency,idempotency_key,source_provider,source_reference,description,metadata
  ) values(
    e.user_id,'deposit',e.amount_xaf,e.currency,'provider-event:'||e.id::text,
    e.provider_name,e.external_event_id,'Verified deposit allocated to savings pockets',
    jsonb_build_object('provider_event_id',e.id,'payment_intent_id',e.payment_intent_id)
  ) on conflict(user_id,idempotency_key) do nothing returning id into v_tx;

  if v_tx is null then
    select id into v_tx from public.ledger_transactions
    where user_id=e.user_id and idempotency_key='provider-event:'||e.id::text;
    update public.provider_events set processed_transaction_id=v_tx,processing_status='processed',processed_at=now()
    where id=e.id;
    return v_tx;
  end if;

  insert into public.ledger_entries(transaction_id,account_id,entry_side,amount_xaf)
  values(v_tx,v_clearing,'debit',e.amount_xaf);
  v_remaining:=e.amount_xaf;

  for r in
    select ar.percentage,ar.pocket_id,p.ledger_account_id
    from public.allocation_rules ar join public.pockets p on p.id=ar.pocket_id
    where ar.plan_id=v_plan and p.user_id=e.user_id and p.status='active'
    order by ar.priority,ar.id
  loop
    v_index:=v_index+1;
    if v_index=v_rule_count then v_piece:=v_remaining;
    else v_piece:=floor(e.amount_xaf*r.percentage/100.0)::bigint; end if;
    if v_piece>0 then
      insert into public.ledger_entries(transaction_id,account_id,entry_side,amount_xaf)
      values(v_tx,r.ledger_account_id,'credit',v_piece);
      insert into public.pocket_allocations(transaction_id,pocket_id,amount_xaf,percentage_snapshot)
      values(v_tx,r.pocket_id,v_piece,r.percentage);
      v_remaining:=v_remaining-v_piece;
    end if;
  end loop;

  if v_remaining<>0 or v_index<>v_rule_count then raise exception 'Allocation did not distribute the full verified deposit'; end if;
  update public.provider_events set processed_transaction_id=v_tx,processing_status='processed',processed_at=now()
  where id=e.id;
  if e.payment_intent_id is not null then
    update public.payment_intents set status='succeeded',provider_reference=e.external_event_id where id=e.payment_intent_id;
  end if;
  insert into public.notifications(user_id,category,title,body,data)
  values(e.user_id,'deposit','Deposit received','Your verified deposit has been allocated to your pockets.',
    jsonb_build_object('transaction_id',v_tx,'amount_xaf',e.amount_xaf));
  return v_tx;
end; $$;

revoke all on function public.post_verified_deposit(uuid) from public,anon,authenticated;
grant execute on function public.post_verified_deposit(uuid) to service_role;
revoke all on function public.create_pocket_ledger_account() from public,anon,authenticated;
revoke all on function public.handle_new_user() from public,anon,authenticated;
grant execute on function public.activate_allocation_plan(uuid) to authenticated,service_role;

alter table public.profiles enable row level security;
alter table public.pockets enable row level security;
alter table public.ledger_accounts enable row level security;
alter table public.allocation_plans enable row level security;
alter table public.allocation_rules enable row level security;
alter table public.payment_intents enable row level security;
alter table public.ledger_transactions enable row level security;
alter table public.provider_events enable row level security;
alter table public.ledger_entries enable row level security;
alter table public.pocket_allocations enable row level security;
alter table public.notifications enable row level security;
alter table public.audit_logs enable row level security;

create policy profiles_select_own on public.profiles for select to authenticated using(id=(select auth.uid()));
create policy profiles_update_own on public.profiles for update to authenticated using(id=(select auth.uid())) with check(id=(select auth.uid()));
create policy pockets_select_own on public.pockets for select to authenticated using(user_id=(select auth.uid()));
create policy pockets_insert_own on public.pockets for insert to authenticated with check(user_id=(select auth.uid()));
create policy pockets_update_own on public.pockets for update to authenticated using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
create policy ledger_accounts_select_own on public.ledger_accounts for select to authenticated using(user_id=(select auth.uid()));
create policy allocation_plans_select_own on public.allocation_plans for select to authenticated using(user_id=(select auth.uid()));
create policy allocation_plans_insert_own on public.allocation_plans for insert to authenticated with check(user_id=(select auth.uid()));
create policy allocation_plans_update_own on public.allocation_plans for update to authenticated using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
create policy allocation_rules_select_own on public.allocation_rules for select to authenticated using(
  exists(select 1 from public.allocation_plans p where p.id=plan_id and p.user_id=(select auth.uid()))
);
create policy allocation_rules_insert_own on public.allocation_rules for insert to authenticated with check(
  exists(select 1 from public.allocation_plans ap where ap.id=plan_id and ap.user_id=(select auth.uid()) and ap.status='draft')
  and exists(select 1 from public.pockets p where p.id=pocket_id and p.user_id=(select auth.uid()) and p.status='active')
);
create policy allocation_rules_update_own on public.allocation_rules for update to authenticated using(
  exists(select 1 from public.allocation_plans ap where ap.id=plan_id and ap.user_id=(select auth.uid()) and ap.status='draft')
) with check(
  exists(select 1 from public.allocation_plans ap where ap.id=plan_id and ap.user_id=(select auth.uid()) and ap.status='draft')
  and exists(select 1 from public.pockets p where p.id=pocket_id and p.user_id=(select auth.uid()) and p.status='active')
);
create policy allocation_rules_delete_own on public.allocation_rules for delete to authenticated using(
  exists(select 1 from public.allocation_plans p where p.id=plan_id and p.user_id=(select auth.uid()) and p.status='draft')
);
create policy payment_intents_select_own on public.payment_intents for select to authenticated using(user_id=(select auth.uid()));
create policy ledger_transactions_select_own on public.ledger_transactions for select to authenticated using(user_id=(select auth.uid()));
create policy ledger_entries_select_own on public.ledger_entries for select to authenticated using(
  exists(select 1 from public.ledger_accounts a where a.id=account_id and a.user_id=(select auth.uid()))
);
create policy pocket_allocations_select_own on public.pocket_allocations for select to authenticated using(
  exists(select 1 from public.pockets p where p.id=pocket_id and p.user_id=(select auth.uid()))
);
create policy notifications_select_own on public.notifications for select to authenticated using(user_id=(select auth.uid()));
create policy notifications_update_own on public.notifications for update to authenticated using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
create policy audit_logs_select_own on public.audit_logs for select to authenticated using(user_id=(select auth.uid()));
create policy provider_events_no_client_access on public.provider_events for all to anon,authenticated using(false) with check(false);

revoke update on public.profiles from authenticated;
grant update(display_name,phone_e164) on public.profiles to authenticated;
revoke update on public.pockets from authenticated;
grant update(name,description,color_key,icon_key,status,is_locked) on public.pockets to authenticated;
revoke update on public.allocation_plans from authenticated;
grant update(name,status) on public.allocation_plans to authenticated;
revoke update on public.allocation_rules from authenticated;
grant update(pocket_id,percentage,priority) on public.allocation_rules to authenticated;
revoke update on public.notifications from authenticated;
grant update(read_at) on public.notifications to authenticated;

create view public.pocket_balances with(security_invoker=true) as
select p.id pocket_id,p.user_id,p.name,p.description,p.color_key,p.icon_key,p.status,p.is_locked,p.created_at,
  coalesce(sum(case when le.entry_side='credit' then le.amount_xaf when le.entry_side='debit' then -le.amount_xaf else 0 end),0)::bigint balance_xaf
from public.pockets p left join public.ledger_entries le on le.account_id=p.ledger_account_id
group by p.id;
grant select on public.pocket_balances to authenticated;
