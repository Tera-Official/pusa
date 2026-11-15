create or replace function public.save_allocation_plan_draft(
  p_plan_id uuid,
  p_name text,
  p_rules jsonb
)
returns uuid
language plpgsql
security invoker
set search_path = public
as $function$
declare
  v_user_id uuid := auth.uid();
  v_plan_id uuid;
  v_rule jsonb;
  v_pocket_id uuid;
  v_percentage numeric(5,2);
  v_priority integer;
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  if p_name is null or length(btrim(p_name)) < 1 or length(btrim(p_name)) > 80 then
    raise exception 'Plan name must contain between 1 and 80 characters';
  end if;

  if p_rules is null or jsonb_typeof(p_rules) <> 'array' then
    raise exception 'Allocation rules must be a JSON array';
  end if;

  if p_plan_id is null then
    insert into public.allocation_plans (user_id, name, status)
    values (v_user_id, btrim(p_name), 'draft')
    returning id into v_plan_id;
  else
    update public.allocation_plans
       set name = btrim(p_name)
     where id = p_plan_id
       and user_id = v_user_id
       and status = 'draft'
    returning id into v_plan_id;

    if v_plan_id is null then
      raise exception 'Draft allocation plan not found or not editable';
    end if;

    delete from public.allocation_rules where plan_id = v_plan_id;
  end if;

  for v_rule in select value from jsonb_array_elements(p_rules)
  loop
    begin
      v_pocket_id := (v_rule->>'pocket_id')::uuid;
      v_percentage := (v_rule->>'percentage')::numeric(5,2);
      v_priority := coalesce((v_rule->>'priority')::integer, 100);
    exception when others then
      raise exception 'Each allocation rule must contain a valid pocket_id, percentage and priority';
    end;

    if v_percentage <= 0 or v_percentage > 100 then
      raise exception 'Each allocation percentage must be greater than 0 and no more than 100';
    end if;

    if not exists (
      select 1 from public.pockets
       where id = v_pocket_id
         and user_id = v_user_id
         and status = 'active'
    ) then
      raise exception 'Allocation rules may only use your active pockets';
    end if;

    insert into public.allocation_rules (plan_id, pocket_id, percentage, priority)
    values (v_plan_id, v_pocket_id, v_percentage, v_priority);
  end loop;

  return v_plan_id;
end;
$function$;

revoke all on function public.save_allocation_plan_draft(uuid, text, jsonb) from public, anon;
grant execute on function public.save_allocation_plan_draft(uuid, text, jsonb) to authenticated;

revoke all on function public.activate_allocation_plan(uuid) from public, anon;
grant execute on function public.activate_allocation_plan(uuid) to authenticated;
