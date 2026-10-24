-- 003_transactions_business_erp.sql
-- Menyelaraskan tabel companies dan transactions dengan model Ilham ERP:
--  * Data Usaha: alamat, tahun buku, tanggal mulai periode berjalan
--  * Transaksi : satu akun debit + satu akun kredit + nomor invoice
-- Jalankan di Supabase: SQL Editor -> New query -> tempel -> Run

-- =========================================================
-- 1. DATA USAHA
-- =========================================================

alter table public.companies
  add column if not exists alamat       text,
  add column if not exists tahun_buku   integer,
  add column if not exists period_start date;

alter table public.companies
  add constraint companies_tahun_buku_check check (tahun_buku is null or tahun_buku between 2000 and 2100);

-- Owner boleh menghapus usaha (semua data usaha ikut terhapus karena on delete cascade)
create policy companies_delete on public.companies
  for delete to authenticated using (public.is_owner(id));

-- create_company versi baru: bisa membawa alamat, tahun buku, dan tanggal mulai periode.
-- Pemanggilan lama create_company(p_nama) tetap jalan karena parameter lain punya default.
drop function if exists public.create_company(text);

create or replace function public.create_company(
  p_nama         text,
  p_alamat       text    default null,
  p_tahun_buku   integer default null,
  p_period_start date    default null
)
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

  insert into public.companies (nama, alamat, tahun_buku, period_start, kode_usaha)
  values (
    p_nama,
    p_alamat,
    coalesce(p_tahun_buku, extract(year from current_date)::integer),
    p_period_start,
    upper(substr(md5(random()::text || clock_timestamp()::text), 1, 8))
  )
  returning * into v_company;

  insert into public.business_members (business_id, user_id, role)
  values (v_company.id, auth.uid(), 'owner');

  return v_company;
end;
$$;

revoke all on function public.create_company(text, text, integer, date) from public, anon;
grant execute on function public.create_company(text, text, integer, date) to authenticated;

-- =========================================================
-- 2. TRANSAKSI (satu debit + satu kredit)
-- =========================================================

alter table public.transactions
  add column if not exists invoice           text,
  add column if not exists debit_account_id  uuid references public.accounts (id) on delete restrict,
  add column if not exists credit_account_id uuid references public.accounts (id) on delete restrict;

-- Kolom lama dari rancangan awal (INCOME/EXPENSE + metode bayar) tidak dipakai lagi
alter table public.transactions
  drop column if exists type,
  drop column if exists payment_method;

alter table public.transactions
  add constraint transactions_accounts_differ
  check (debit_account_id is null or credit_account_id is null or debit_account_id <> credit_account_id);

create index if not exists transactions_debit_idx  on public.transactions (business_id, debit_account_id);
create index if not exists transactions_credit_idx on public.transactions (business_id, credit_account_id);

-- Catatan:
--  * source        : MANUAL | catatin | catatin-hpp | (nanti) POS_KASIR | TELEGRAM_AI
--  * source_id     : id asal; (business_id, source, source_id) unik -> impor ulang tidak membuat data ganda
--  * Tabel journals dan journal_entries dari 001 belum dipakai; jurnal ERP diturunkan dari transactions.
