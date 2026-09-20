-- Shared Tasks App (2 users) - Supabase / PostgreSQL
-- Run in Supabase SQL editor. Step 1: DB + Auth + Workspace + Tasks

create extension if not exists pgcrypto;

-- ========== ENUMS ==========
create type task_status as enum ('pending', 'completed');
create type task_priority as enum ('low', 'medium', 'high');
create type member_role as enum ('owner', 'member');

-- ========== PROFILES (linked to auth.users) ==========
create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null default '',
  email text,
  photo_url text,
  is_online boolean not null default false,
  last_seen timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create function handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into profiles (id, name, email, photo_url)
  values (new.id,
          coalesce(new.raw_user_meta_data->>'name', split_part(new.email,'@',1)),
          new.email,
          new.raw_user_meta_data->>'avatar_url');
  return new;
end $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

-- ========== WORKSPACES ==========
create table workspaces (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  invite_code text not null unique
    default upper(substr(encode(gen_random_bytes(6), 'hex'), 1, 6)),
  created_by uuid not null references profiles(id),
  created_at timestamptz not null default now()
);

create table workspace_members (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  role member_role not null default 'member',
  joined_at timestamptz not null default now(),
  unique (workspace_id, user_id)
);
create index on workspace_members (user_id);

-- ========== TASKS ==========
create table tasks (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  title text not null check (length(trim(title)) > 0),
  description text,
  notes text,
  created_by uuid not null references profiles(id),
  assigned_to uuid references profiles(id),      -- null = anyone
  status task_status not null default 'pending',
  priority task_priority not null default 'medium',
  due_date date,
  due_time time,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  completed_at timestamptz,
  completed_by uuid references profiles(id)
);
create index on tasks (workspace_id, status);

-- ========== NOTIFICATIONS / ACTIVITY / DEVICES ==========
create table notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  workspace_id uuid not null references workspaces(id) on delete cascade,
  type text not null,          -- task_created | task_updated | task_completed | task_deleted | task_due_soon
  title text not null,
  body text not null,
  task_id uuid,                -- no FK: task may be deleted
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);
create index on notifications (user_id, created_at desc);

create table activity_logs (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces(id) on delete cascade,
  user_id uuid not null references profiles(id),
  action text not null,        -- created | updated | completed | deleted
  task_id uuid,
  metadata jsonb not null default '{}',
  created_at timestamptz not null default now()
);
create index on activity_logs (workspace_id, created_at desc);

create table device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  token text not null unique,
  platform text,
  created_at timestamptz not null default now()
);

-- ========== HELPERS ==========
create function is_member(ws uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from workspace_members
                 where workspace_id = ws and user_id = auth.uid());
$$;

-- Create workspace + add creator as owner (atomic)
create function create_workspace(p_name text) returns workspaces
language plpgsql security definer set search_path = public as $$
declare w workspaces;
begin
  insert into workspaces (name, created_by) values (p_name, auth.uid()) returning * into w;
  insert into workspace_members (workspace_id, user_id, role) values (w.id, auth.uid(), 'owner');
  return w;
end $$;

-- Join by invite code; workspace limited to 2 members
create function join_workspace(p_code text) returns uuid
language plpgsql security definer set search_path = public as $$
declare w workspaces; cnt int;
begin
  select * into w from workspaces where invite_code = upper(trim(p_code)) for update;
  if not found then raise exception 'invalid_code'; end if;
  if exists (select 1 from workspace_members where workspace_id = w.id and user_id = auth.uid())
    then return w.id; end if;
  select count(*) into cnt from workspace_members where workspace_id = w.id;
  if cnt >= 2 then raise exception 'workspace_full'; end if;
  insert into workspace_members (workspace_id, user_id) values (w.id, auth.uid());
  return w.id;
end $$;

-- ========== TRIGGERS: updated_at, completion, activity + notifications ==========
create function tasks_before_write() returns trigger
language plpgsql as $$
begin
  new.updated_at := now();
  if tg_op = 'UPDATE' then
    if new.status = 'completed' and old.status <> 'completed' then
      new.completed_at := now();
      new.completed_by := auth.uid();
    elsif new.status = 'pending' and old.status = 'completed' then
      new.completed_at := null;
      new.completed_by := null;
    end if;
  end if;
  return new;
end $$;

create trigger trg_tasks_before_write
  before insert or update on tasks
  for each row execute function tasks_before_write();

create function tasks_after_write() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  t tasks; actor_name text; act text; ntype text; verb text; other uuid;
begin
  if tg_op = 'DELETE' then t := old; else t := new; end if;
  select name into actor_name from profiles where id = auth.uid();

  if tg_op = 'INSERT' then act := 'created';   ntype := 'task_created';   verb := 'أضاف % مهمة جديدة: %';
  elsif tg_op = 'DELETE' then act := 'deleted'; ntype := 'task_deleted';   verb := 'حذف % المهمة: %';
  elsif new.status = 'completed' and old.status <> 'completed'
                          then act := 'completed'; ntype := 'task_completed'; verb := 'أنجز % المهمة: %';
  else                         act := 'updated';   ntype := 'task_updated';   verb := 'عدّل % المهمة: %';
  end if;

  insert into activity_logs (workspace_id, user_id, action, task_id, metadata)
  values (t.workspace_id, auth.uid(), act, t.id, jsonb_build_object('title', t.title));

  -- notify the other member only (never the actor)
  select user_id into other from workspace_members
   where workspace_id = t.workspace_id and user_id <> auth.uid() limit 1;
  if other is not null then
    insert into notifications (user_id, workspace_id, type, title, body, task_id)
    values (other, t.workspace_id, ntype, 'مهامنا', format(verb, actor_name, t.title), t.id);
  end if;

  return coalesce(new, old);
end $$;

create trigger trg_tasks_after_write
  after insert or update or delete on tasks
  for each row execute function tasks_after_write();

-- ========== ROW LEVEL SECURITY ==========
alter table profiles          enable row level security;
alter table workspaces        enable row level security;
alter table workspace_members enable row level security;
alter table tasks             enable row level security;
alter table notifications     enable row level security;
alter table activity_logs     enable row level security;
alter table device_tokens     enable row level security;

-- profiles: own profile + workspace partner
create policy profiles_select on profiles for select using (
  id = auth.uid() or exists (
    select 1 from workspace_members a join workspace_members b
      on a.workspace_id = b.workspace_id
    where a.user_id = auth.uid() and b.user_id = profiles.id));
create policy profiles_update on profiles for update
  using (id = auth.uid()) with check (id = auth.uid());

-- workspaces / members (writes go through RPCs only)
create policy ws_select on workspaces for select using (is_member(id));
create policy ws_update on workspaces for update using (created_by = auth.uid());
create policy wm_select on workspace_members for select using (is_member(workspace_id));

-- tasks
create policy tasks_select on tasks for select using (is_member(workspace_id));
create policy tasks_insert on tasks for insert
  with check (is_member(workspace_id) and created_by = auth.uid());
create policy tasks_update on tasks for update
  using (is_member(workspace_id)) with check (is_member(workspace_id));
create policy tasks_delete on tasks for delete using (is_member(workspace_id));

-- notifications: only own
create policy notif_select on notifications for select using (user_id = auth.uid());
create policy notif_update on notifications for update
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- activity: members read-only (written by trigger)
create policy activity_select on activity_logs for select using (is_member(workspace_id));

-- device tokens: own only
create policy tokens_all on device_tokens for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ========== REALTIME ==========
alter publication supabase_realtime add table tasks, notifications, activity_logs;
