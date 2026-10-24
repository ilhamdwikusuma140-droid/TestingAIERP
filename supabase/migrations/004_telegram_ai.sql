-- 004_telegram_ai.sql
-- Pondasi bot Telegram + AI:
--  1. Kode pairing sekali pakai (dibuat dari ERP setelah login, berlaku 10 menit)
--  2. consume_telegram_pairing_code : dipanggil Edge Function saat pengguna kirim /pair KODE
--  3. post_ai_transactions          : mencatat transaksi hasil AI ke tabel transactions,
--                                     dengan validasi ketat dan anti-duplikat
-- Jalankan di Supabase: SQL Editor -> New query -> tempel -> Run

-- =========================================================
-- 1. KODE PAIRING
-- =========================================================

alter table public.telegram_sessions
  add column if not exists paired_by uuid references auth.users (id);

create table public.telegram_pairing_codes (
  code        text primary key,
  business_id uuid not null references public.companies (id) on delete cascade,
  created_by  uuid references auth.users (id) default auth.uid(),
  expires_at  timestamptz not null,
  used_at     timestamptz,
  created_at  timestamptz not null default now()
);

-- Tanpa policy: hanya bisa diakses lewat fungsi di bawah
alter table public.telegram_pairing_codes enable row level security;

-- Dipanggil dari ERP oleh owner usaha. Hanya satu kode aktif per usaha.
create or replace function public.create_telegram_pairing_code(p_business_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code    text;
  v_expires timestamptz := now() + interval '10 minutes';
begin
  if not public.is_owner(p_business_id) then
    raise exception 'Hanya owner usaha yang boleh membuat kode pairing';
  end if;

  delete from public.telegram_pairing_codes
  where business_id = p_business_id and used_at is null;

  v_code := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10));

  insert into public.telegram_pairing_codes (code, business_id, expires_at)
  values (v_code, p_business_id, v_expires);

  return jsonb_build_object('code', v_code, 'expires_at', v_expires);
end;
$$;

revoke all on function public.create_telegram_pairing_code(uuid) from public, anon;
grant execute on function public.create_telegram_pairing_code(uuid) to authenticated;

-- Dipanggil Edge Function (service role). Tidak bisa dipanggil dari browser.
create or replace function public.consume_telegram_pairing_code(p_code text, p_chat_id bigint)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row  public.telegram_pairing_codes;
  v_nama text;
begin
  select * into v_row
  from public.telegram_pairing_codes
  where code = upper(trim(p_code))
  for update;

  if not found or v_row.used_at is not null or v_row.expires_at < now() then
    return jsonb_build_object('ok', false, 'reason', 'Kode tidak valid atau sudah kedaluwarsa');
  end if;

  update public.telegram_pairing_codes set used_at = now() where code = v_row.code;

  -- Satu chat terhubung ke satu usaha aktif; pairing ulang = pindah usaha
  insert into public.telegram_sessions (telegram_chat_id, business_id, paired_by)
  values (p_chat_id, v_row.business_id, v_row.created_by)
  on conflict (telegram_chat_id)
  do update set business_id = excluded.business_id, paired_by = excluded.paired_by;

  select nama into v_nama from public.companies where id = v_row.business_id;

  return jsonb_build_object('ok', true, 'business_id', v_row.business_id, 'nama', v_nama);
end;
$$;

revoke all on function public.consume_telegram_pairing_code(text, bigint) from public, anon, authenticated;
grant execute on function public.consume_telegram_pairing_code(text, bigint) to service_role;

-- =========================================================
-- 2. PENCATAT TRANSAKSI HASIL AI
-- =========================================================
-- p_items: array JSON, maksimal 10 item, tiap item:
--   { "tanggal": "2026-10-25", "description": "...", "debit_code": "1101",
--     "credit_code": "4101", "amount": 150000 }
-- Satu pesan Telegram bisa menghasilkan beberapa transaksi (mis. penjualan + HPP).
-- Atomik: jika satu item tidak valid, tidak ada yang tersimpan.
-- p_source_id: id unik pesan (mis. "tg:<chat_id>:<message_id>"), mencegah pencatatan ganda
--   saat Telegram mengirim ulang webhook.

create or replace function public.post_ai_transactions(
  p_business_id uuid,
  p_source_id   text,
  p_items       jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_item    jsonb;
  v_idx     integer := 0;
  v_result  jsonb   := '[]'::jsonb;
  v_invoice text;
  v_dcode   text;
  v_ccode   text;
  v_debit   uuid;
  v_credit  uuid;
  v_dname   text;
  v_cname   text;
  v_amount  numeric;
  v_tanggal date;
  v_desc    text;
  v_id      uuid;
begin
  if p_business_id is null or not exists (select 1 from public.companies where id = p_business_id) then
    raise exception 'Usaha tidak ditemukan';
  end if;

  if p_source_id is null or length(trim(p_source_id)) = 0 then
    raise exception 'source_id wajib diisi';
  end if;

  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'Daftar transaksi kosong';
  end if;

  if jsonb_array_length(p_items) > 10 then
    raise exception 'Maksimal 10 transaksi per pesan';
  end if;

  -- Pesan yang sama tidak dicatat dua kali
  if exists (
    select 1 from public.transactions
    where business_id = p_business_id and source = 'TELEGRAM_AI' and source_id = p_source_id || ':1'
  ) then
    return jsonb_build_object('duplicate', true, 'items', '[]'::jsonb);
  end if;

  v_invoice := 'TG-' || upper(substr(md5(p_source_id), 1, 6));

  for v_item in select * from jsonb_array_elements(p_items) loop
    v_idx := v_idx + 1;

    v_dcode   := trim(coalesce(v_item->>'debit_code', ''));
    v_ccode   := trim(coalesce(v_item->>'credit_code', ''));
    v_desc    := trim(coalesce(v_item->>'description', ''));
    v_amount  := (v_item->>'amount')::numeric;
    v_tanggal := coalesce(nullif(v_item->>'tanggal', '')::date, current_date);

    if v_amount is null or v_amount <= 0 or v_amount > 1000000000000 then
      raise exception 'Item %: jumlah tidak valid', v_idx;
    end if;

    if v_desc = '' then
      raise exception 'Item %: deskripsi kosong', v_idx;
    end if;

    if v_tanggal < date '2000-01-01' or v_tanggal > current_date + 7 then
      raise exception 'Item %: tanggal tidak wajar (%)', v_idx, v_tanggal;
    end if;

    if v_dcode = v_ccode then
      raise exception 'Item %: akun debit dan kredit tidak boleh sama', v_idx;
    end if;

    v_debit := null; v_credit := null; v_dname := null; v_cname := null;

    select id, name into v_debit, v_dname
    from public.accounts where business_id = p_business_id and code = v_dcode;
    if v_debit is null then
      raise exception 'Item %: akun debit % tidak ada di COA usaha ini', v_idx, v_dcode;
    end if;

    select id, name into v_credit, v_cname
    from public.accounts where business_id = p_business_id and code = v_ccode;
    if v_credit is null then
      raise exception 'Item %: akun kredit % tidak ada di COA usaha ini', v_idx, v_ccode;
    end if;

    insert into public.transactions
      (business_id, tanggal, invoice, description, debit_account_id, credit_account_id, amount, source, source_id)
    values
      (p_business_id, v_tanggal, v_invoice, left(v_desc, 300), v_debit, v_credit, v_amount,
       'TELEGRAM_AI', p_source_id || ':' || v_idx)
    returning id into v_id;

    v_result := v_result || jsonb_build_object(
      'id',          v_id,
      'tanggal',     v_tanggal,
      'description', left(v_desc, 300),
      'debit',       v_dcode || ' - ' || v_dname,
      'credit',      v_ccode || ' - ' || v_cname,
      'amount',      v_amount
    );
  end loop;

  return jsonb_build_object('duplicate', false, 'items', v_result);
end;
$$;

revoke all on function public.post_ai_transactions(uuid, text, jsonb) from public, anon, authenticated;
grant execute on function public.post_ai_transactions(uuid, text, jsonb) to service_role;

-- =========================================================
-- UJI MANUAL (opsional, jalankan terpisah setelah file ini sukses)
-- Ganti <BUSINESS_ID> dengan id usaha (Table Editor -> companies -> kolom id),
-- dan pastikan akun 1101 dan 4101 ada di COA usaha itu.
--
--   select public.post_ai_transactions(
--     '<BUSINESS_ID>', 'uji:1',
--     '[{"debit_code":"1101","credit_code":"4101","amount":10000,"description":"Uji coba AI"}]'::jsonb
--   );
--
-- Lihat hasilnya di halaman Transaksi / Jurnal Umum. Hapus baris uji:
--   delete from public.transactions where source = 'TELEGRAM_AI' and source_id like 'uji:%';
-- =========================================================
