-- HOME BUILD MANAGER: AUTHENTICATION + USER PROFILE + PRIVATE DATA
-- Run this complete file in Supabase SQL Editor.

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  full_name text,
  role text not null default 'owner' check (role in ('owner','member','viewer')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles(id,email,full_name)
  values(new.id,new.email,coalesce(new.raw_user_meta_data->>'full_name',''))
  on conflict(id) do update set email=excluded.email;
  return new;
end; $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
for each row execute procedure public.handle_new_user();

create table if not exists public.shops(id text primary key,name text not null,type text,created_at timestamptz default now());
create table if not exists public.materials(id text primary key,name text not null,group_name text,rate numeric default 0,unit text not null,shop_id text references public.shops(id) on delete restrict,active boolean default true,created_at timestamptz default now());
create table if not exists public.purchases(id text primary key,purchase_date date not null,shop_id text references public.shops(id) on delete restrict,material_id text references public.materials(id) on delete restrict,quantity numeric not null,rate numeric not null,fare numeric default 0,reference text,notes text,created_at timestamptz default now());
create table if not exists public.ledger_entries(id text primary key,entry_date date not null,shop_id text references public.shops(id) on delete restrict,entry_type text check(entry_type in('credit','debit')),amount numeric not null,category text,notes text,created_at timestamptz default now());

alter table public.shops add column if not exists owner_id uuid references auth.users(id) on delete cascade;
alter table public.materials add column if not exists owner_id uuid references auth.users(id) on delete cascade;
alter table public.purchases add column if not exists owner_id uuid references auth.users(id) on delete cascade;
alter table public.ledger_entries add column if not exists owner_id uuid references auth.users(id) on delete cascade;
alter table public.materials add column if not exists created_at timestamptz default now();
alter table public.purchases add column if not exists created_at timestamptz default now();
alter table public.ledger_entries add column if not exists created_at timestamptz default now();

alter table public.profiles enable row level security;
alter table public.shops enable row level security;
alter table public.materials enable row level security;
alter table public.purchases enable row level security;
alter table public.ledger_entries enable row level security;

drop policy if exists "own profile select" on public.profiles;
drop policy if exists "own profile update" on public.profiles;
create policy "own profile select" on public.profiles for select to authenticated using(id=auth.uid());
create policy "own profile update" on public.profiles for update to authenticated using(id=auth.uid()) with check(id=auth.uid());

drop policy if exists "anon shops" on public.shops; drop policy if exists "anon materials" on public.materials; drop policy if exists "anon purchases" on public.purchases; drop policy if exists "anon ledger" on public.ledger_entries;
drop policy if exists "owner shops" on public.shops; drop policy if exists "owner materials" on public.materials; drop policy if exists "owner purchases" on public.purchases; drop policy if exists "owner ledger" on public.ledger_entries;
create policy "owner shops" on public.shops for all to authenticated using(owner_id=auth.uid()) with check(owner_id=auth.uid());
create policy "owner materials" on public.materials for all to authenticated using(owner_id=auth.uid()) with check(owner_id=auth.uid());
create policy "owner purchases" on public.purchases for all to authenticated using(owner_id=auth.uid()) with check(owner_id=auth.uid());
create policy "owner ledger" on public.ledger_entries for all to authenticated using(owner_id=auth.uid()) with check(owner_id=auth.uid());

grant select,update on public.profiles to authenticated;
grant select,insert,update,delete on public.shops,public.materials,public.purchases,public.ledger_entries to authenticated;

do $$ begin alter publication supabase_realtime add table public.shops; exception when duplicate_object then null; end $$;
do $$ begin alter publication supabase_realtime add table public.materials; exception when duplicate_object then null; end $$;
do $$ begin alter publication supabase_realtime add table public.purchases; exception when duplicate_object then null; end $$;
do $$ begin alter publication supabase_realtime add table public.ledger_entries; exception when duplicate_object then null; end $$;

-- Existing rows from the older anonymous version have owner_id=NULL and will be hidden.
-- After creating your first Auth user, copy its UUID from Authentication > Users and run:
-- update public.shops set owner_id='YOUR-USER-UUID' where owner_id is null;
-- update public.materials set owner_id='YOUR-USER-UUID' where owner_id is null;
-- update public.purchases set owner_id='YOUR-USER-UUID' where owner_id is null;
-- update public.ledger_entries set owner_id='YOUR-USER-UUID' where owner_id is null;
