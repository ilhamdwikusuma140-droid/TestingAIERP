-- 002_accounts_erp_model.sql
-- Menyelaraskan tabel accounts dengan model akun di Ilham ERP:
-- kelompok akun (grp), saldo normal, dan penanda Kas/Bank.
-- Template COA (Jasa, Dagang, Manufaktur, Konstruksi, Lengkap) tetap ada di accounts.html.
-- Jalankan di Supabase: SQL Editor -> New query -> tempel -> Run

-- Bersihkan sisa percobaan template berbasis SQL (aman bila belum pernah dibuat)
drop function if exists public.apply_coa_template(uuid, text);
drop table if exists public.coa_template_accounts;
drop table if exists public.coa_templates;

-- Kolom baru
alter table public.accounts
  add column if not exists grp            text,
  add column if not exists normal_balance text,
  add column if not exists is_cash        boolean not null default false;

-- Kolom "type" lama menjadi turunan otomatis dari grp (dipakai bot AI)
alter table public.accounts alter column type drop not null;

alter table public.accounts
  add constraint accounts_grp_check check (grp is null or grp in (
    'Aset Lancar', 'Aset Tetap', 'Aset Lainnya',
    'Liabilitas Jangka Pendek', 'Liabilitas Jangka Panjang',
    'Ekuitas', 'Pendapatan', 'Beban'
  ));

alter table public.accounts
  add constraint accounts_normal_check check (normal_balance is null or normal_balance in ('Debit', 'Kredit'));

create or replace function public.accounts_set_type()
returns trigger
language plpgsql
as $$
begin
  new.type := case
    when new.grp like 'Aset%'       then 'ASSET'
    when new.grp like 'Liabilitas%' then 'LIABILITY'
    when new.grp = 'Ekuitas'        then 'EQUITY'
    when new.grp = 'Pendapatan'     then 'REVENUE'
    when new.grp = 'Beban'          then 'EXPENSE'
    else new.type
  end;
  return new;
end;
$$;

drop trigger if exists trg_accounts_set_type on public.accounts;
create trigger trg_accounts_set_type
  before insert or update of grp on public.accounts
  for each row execute function public.accounts_set_type();
