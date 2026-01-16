-- 1. Profiles table for user metadata
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  avatar_url text,
  role text default 'USER',
  updated_at timestamp with time zone default now()
);

alter table public.profiles enable row level security;
create policy "Public profiles are viewable by everyone" on public.profiles for select using (true);
create policy "Users can update own profile" on public.profiles for update using (auth.uid() = id);

-- 2. Channels (TV/Streaming)
create table if not exists public.channels (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  stream_url text not null,
  is_premium boolean default false,
  created_at timestamp with time zone default now()
);

alter table public.channels enable row level security;
create policy "Anyone can view channels" on public.channels for select using (true);

-- 3. Shop Products
create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  price numeric not null,
  image_url text,
  stock integer default 0
);

alter table public.products enable row level security;
create policy "Anyone can view products" on public.products for select using (true);

-- 4. Audit Logs
create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id),
  action text not null,
  details jsonb,
  created_at timestamp with time zone default now()
);

alter table public.audit_logs enable row level security;
create policy "Only admins can view audit logs" on public.audit_logs for select using (
  exists (select 1 from public.profiles where id = auth.uid() and role = 'ADMIN')
);

-- 5. Trigger for auto-profile creation
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, display_name, avatar_url)
  values (new.id, new.raw_user_meta_data->>'display_name', new.raw_user_meta_data->>'avatar_url');
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
