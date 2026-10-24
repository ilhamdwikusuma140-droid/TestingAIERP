-- 001_schema.sql
-- Skema inti IlhamERP + Kasir Catat.in (satu akun bisa mengelola banyak usaha)
-- Jalankan di Supabase: SQL Editor -> New query -> tempel -> Run

-- =========================================================
-- 1. TABEL
-- =========================================================

create table public.companies (
  id          uuid primary key default gen_random_uuid(),
  nama        text not null,
  kode_usaha  text not null unique,
  created_by  uuid references auth.users (id) default auth.uid(),
  created_at  timestamptz not null default now()
);

create table public.business_members (
  business_id uuid not null references public.companies (id) on delete cascade,
  user_id     uuid not null references auth.users (id) on delete cascade,
  role        text not null default 'staff' check (role in ('owner', 'staff')),
  created_at  timestamptz not null default now(),
  primary key (business_id, user_id)
);
create index on public.business_members (user_id);

create table public.accounts (
  id          uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.companies (id) on delete cascade,
  code        text not null,
  name        text not null,
  type        text not null check (type in ('ASSET', 'LIABILITY', 'EQUITY', 'REVENUE', 'EXPENSE')),
  created_at  timestamptz not null default now(),
  unique (business_id, code)
);

create table public.transactions (
  id             uuid primary key default gen_random_uuid(),
  business_id    uuid not null references public.companies (id) on delete cascade,
  tanggal        date not null default current_date,
  description    text not null,
  amount         numeric(18,2) not null check (amount > 0),
  type           text not null check (type in ('INCOME', 'EXPENSE')),
  payment_method text not null default 'CASH',
  source         text not null default 'MANUAL',   -- MANUAL | POS_KASIR | TELEGRAM
  source_id      text,                             -- id asal (mencegah jurnal ganda)
  created_at     timestamptz not null default now(),
  unique (business_id, source, source_id)
);
create index on public.transactions (business_id, tanggal);

create table public.journals (
  id          uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.companies (id) on delete cascade,
  tanggal     date not null default current_date,
  description text not null,
  source      text not null default 'MANUAL',      -- MANUAL | POS_KASIR | TELEGRAM_AI
  source_id   text,
  created_by  uuid references auth.users (id) default auth.uid(),
  created_at  timestamptz not null default now(),
  unique (business_id, source, source_id)
);
create index on public.journals (business_id, tanggal);

create table public.journal_entries (
  id          uuid primary key default gen_random_uuid(),
  journal_id  uuid not null references public.journals (id) on delete cascade,
  business_id uuid not null references public.companies (id) on delete cascade,
  account_id  uuid not null references public.accounts (id),
  debit       numeric(18,2) not null default 0,
  credit      numeric(18,2) not null default 0,
  check (debit >= 0 and credit >= 0 and (debit = 0 or credit = 0))
);
create index on public.journal_entries (journal_id);
create index on public.journal_entries (business_id, account_id);

-- Hanya diakses Edge Function (service role). Tanpa policy = tertutup untuk klien.
create table public.telegram_sessions (
  telegram_chat_id bigint primary key,
  business_id      uuid not null references public.companies (id) on delete cascade,
  created_at       timestamptz not null default now()
);

-- =========================================================
-- 2. FUNGSI PEMBANTU
-- =========================================================

-- Apakah pengguna yang login anggota usaha ini?
create or replace function public.is_member(p_business_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.business_members
    where business_id = p_business_id
      and user_id = auth.uid()
  );
$$;

-- Apakah pengguna yang login owner usaha ini?
create or replace function public.is_owner(p_business_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.business_members
    where business_id = p_business_id
      and user_id = auth.uid()
      and role = 'owner'
  );
$$;

-- Buat usaha baru + jadikan pembuatnya owner (satu langkah, lolos RLS)
create or replace function public.create_company(p_nama text)
returns public.companies
language plpgsql
security definer
set search_path = public
as $$
declare
  v_company public.companies;
begin
  if auth.uid() is null then
    raise exception 'Harus login terlebih dahulu';
  end if;

  insert into public.companies (nama, kode_usaha)
  values (p_nama, upper(substr(md5(random()::text || clock_timestamp()::text), 1, 8)))
  returning * into v_company;

  insert into public.business_members (business_id, user_id, role)
  values (v_company.id, auth.uid(), 'owner');

  return v_company;
end;
$$;

revoke all on function public.is_member(uuid)    from public, anon;
revoke all on function public.is_owner(uuid)     from public, anon;
revoke all on function public.create_company(text) from public, anon;
grant execute on function public.is_member(uuid)    to authenticated;
grant execute on function public.is_owner(uuid)     to authenticated;
grant execute on function public.create_company(text) to authenticated;

-- =========================================================
-- 3. ROW LEVEL SECURITY
-- =========================================================

alter table public.companies         enable row level security;
alter table public.business_members  enable row level security;
alter table public.accounts          enable row level security;
alter table public.transactions      enable row level security;
alter table public.journals          enable row level security;
alter table public.journal_entries   enable row level security;
alter table public.telegram_sessions enable row level security;

-- companies: anggota boleh lihat, owner boleh ubah. Pembuatan lewat create_company().
create policy companies_select on public.companies
  for select to authenticated using (public.is_member(id));
create policy companies_update on public.companies
  for update to authenticated using (public.is_owner(id)) with check (public.is_owner(id));

-- business_members: lihat keanggotaan sendiri / sesama usaha; owner kelola anggota
create policy members_select on public.business_members
  for select to authenticated
  using (user_id = auth.uid() or public.is_member(business_id));
create policy members_insert on public.business_members
  for insert to authenticated with check (public.is_owner(business_id));
create policy members_delete on public.business_members
  for delete to authenticated using (public.is_owner(business_id));

-- Tabel data: anggota usaha boleh baca/tulis baris usahanya sendiri
create policy accounts_all on public.accounts
  for all to authenticated
  using (public.is_member(business_id)) with check (public.is_member(business_id));

create policy transactions_all on public.transactions
  for all to authenticated
  using (public.is_member(business_id)) with check (public.is_member(business_id));

create policy journals_all on public.journals
  for all to authenticated
  using (public.is_member(business_id)) with check (public.is_member(business_id));

create policy journal_entries_all on public.journal_entries
  for all to authenticated
  using (public.is_member(business_id)) with check (public.is_member(business_id));

-- telegram_sessions: sengaja tanpa policy (hanya service role dari Edge Function)
