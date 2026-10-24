-- 002_coa_templates.sql
-- Template Chart of Accounts lengkap (sekitar 150-170 akun per template).
-- Pengguna tinggal memilih template, akun terisi otomatis tanpa entri manual.
-- Jalankan di Supabase: SQL Editor -> New query -> tempel -> Run

-- =========================================================
-- 1. TABEL TEMPLATE (data referensi, hanya bisa dibaca)
-- =========================================================

create table public.coa_templates (
  id        text primary key,           -- 'dagang' | 'jasa' | 'fnb'
  nama      text not null,
  deskripsi text
);

create table public.coa_template_accounts (
  template_id text not null references public.coa_templates (id) on delete cascade,
  code        text not null,
  name        text not null,
  type        text not null check (type in ('ASSET', 'LIABILITY', 'EQUITY', 'REVENUE', 'EXPENSE')),
  primary key (template_id, code)
);

alter table public.coa_templates         enable row level security;
alter table public.coa_template_accounts enable row level security;

create policy coa_templates_read on public.coa_templates
  for select to authenticated using (true);
create policy coa_template_accounts_read on public.coa_template_accounts
  for select to authenticated using (true);

-- =========================================================
-- 2. DAFTAR TEMPLATE
-- =========================================================

insert into public.coa_templates (id, nama, deskripsi) values
  ('dagang', 'Usaha Dagang / Toko', 'Jual beli barang: persediaan, pembelian, dan harga pokok penjualan.'),
  ('jasa', 'Usaha Jasa', 'Pendapatan dari jasa dan proyek: tanpa persediaan barang dagang.'),
  ('fnb', 'Kafe / Resto (F&B)', 'Penjualan makanan dan minuman: bahan baku, dapur, dan pesan antar online.');

-- =========================================================
-- 3. AKUN UMUM (berlaku untuk semua template)
--    Penomoran: 1xxx Aset | 2xxx Liabilitas | 3xxx Ekuitas | 4xxx Pendapatan
--               5xxx Harga Pokok | 6xxx Beban Operasional | 7xxx Pendapatan Lain
--               8xxx Beban Lain | 9xxx Pajak Penghasilan
-- =========================================================

insert into public.coa_template_accounts (template_id, code, name, type)
select t.id, a.code, a.name, a.type
from public.coa_templates t
cross join (values
    ('1101', 'Kas', 'ASSET'),
    ('1102', 'Kas Kecil', 'ASSET'),
    ('1103', 'Bank - Rekening Operasional', 'ASSET'),
    ('1104', 'Bank - Rekening Tabungan', 'ASSET'),
    ('1105', 'Dompet Digital / E-Wallet', 'ASSET'),
    ('1106', 'Saldo QRIS dalam Proses Penyelesaian', 'ASSET'),
    ('1107', 'Deposito Jangka Pendek', 'ASSET'),
    ('1111', 'Piutang Usaha', 'ASSET'),
    ('1112', 'Cadangan Kerugian Piutang', 'ASSET'),
    ('1113', 'Piutang Karyawan', 'ASSET'),
    ('1114', 'Piutang Pemilik', 'ASSET'),
    ('1115', 'Piutang Lain-lain', 'ASSET'),
    ('1116', 'Pendapatan yang Masih Harus Diterima', 'ASSET'),
    ('1141', 'Perlengkapan Kantor', 'ASSET'),
    ('1142', 'Sewa Dibayar di Muka', 'ASSET'),
    ('1143', 'Asuransi Dibayar di Muka', 'ASSET'),
    ('1144', 'Biaya Dibayar di Muka Lainnya', 'ASSET'),
    ('1145', 'Uang Muka Pembelian', 'ASSET'),
    ('1146', 'PPh Dibayar di Muka', 'ASSET'),
    ('1147', 'PPN Masukan', 'ASSET'),
    ('1148', 'Uang Muka Karyawan', 'ASSET'),
    ('1149', 'Aset Lancar Lainnya', 'ASSET'),
    ('1201', 'Tanah', 'ASSET'),
    ('1202', 'Bangunan', 'ASSET'),
    ('1203', 'Akumulasi Penyusutan Bangunan', 'ASSET'),
    ('1204', 'Kendaraan', 'ASSET'),
    ('1205', 'Akumulasi Penyusutan Kendaraan', 'ASSET'),
    ('1206', 'Peralatan', 'ASSET'),
    ('1207', 'Akumulasi Penyusutan Peralatan', 'ASSET'),
    ('1208', 'Peralatan Kantor', 'ASSET'),
    ('1209', 'Akumulasi Penyusutan Peralatan Kantor', 'ASSET'),
    ('1210', 'Komputer dan Perangkat IT', 'ASSET'),
    ('1211', 'Akumulasi Penyusutan Komputer dan Perangkat IT', 'ASSET'),
    ('1212', 'Mesin', 'ASSET'),
    ('1213', 'Akumulasi Penyusutan Mesin', 'ASSET'),
    ('1214', 'Renovasi Bangunan Sewa', 'ASSET'),
    ('1215', 'Akumulasi Amortisasi Renovasi Bangunan Sewa', 'ASSET'),
    ('1301', 'Merek dan Lisensi', 'ASSET'),
    ('1302', 'Perangkat Lunak', 'ASSET'),
    ('1303', 'Akumulasi Amortisasi Aset Tak Berwujud', 'ASSET'),
    ('1401', 'Deposit Jaminan Sewa', 'ASSET'),
    ('1402', 'Investasi Jangka Panjang', 'ASSET'),
    ('1403', 'Aset Tidak Lancar Lainnya', 'ASSET'),
    ('2101', 'Utang Usaha', 'LIABILITY'),
    ('2102', 'Utang Gaji dan Upah', 'LIABILITY'),
    ('2103', 'Utang Bonus dan THR', 'LIABILITY'),
    ('2104', 'Utang BPJS Ketenagakerjaan', 'LIABILITY'),
    ('2105', 'Utang BPJS Kesehatan', 'LIABILITY'),
    ('2106', 'Utang PPh 21', 'LIABILITY'),
    ('2107', 'Utang PPh 23', 'LIABILITY'),
    ('2108', 'Utang PPh Final', 'LIABILITY'),
    ('2109', 'Utang PPh Badan (PPh 25/29)', 'LIABILITY'),
    ('2110', 'PPN Keluaran', 'LIABILITY'),
    ('2111', 'Utang Pajak Lainnya', 'LIABILITY'),
    ('2112', 'Utang Bunga', 'LIABILITY'),
    ('2113', 'Beban yang Masih Harus Dibayar', 'LIABILITY'),
    ('2114', 'Pendapatan Diterima di Muka', 'LIABILITY'),
    ('2115', 'Uang Muka Pelanggan', 'LIABILITY'),
    ('2116', 'Utang kepada Pemilik', 'LIABILITY'),
    ('2117', 'Utang Kartu Kredit', 'LIABILITY'),
    ('2118', 'Utang Lain-lain', 'LIABILITY'),
    ('2119', 'Utang Bank Jangka Pendek', 'LIABILITY'),
    ('2201', 'Utang Bank Jangka Panjang', 'LIABILITY'),
    ('2202', 'Utang Pembiayaan Kendaraan dan Leasing', 'LIABILITY'),
    ('2203', 'Pinjaman dari Pemilik Jangka Panjang', 'LIABILITY'),
    ('2204', 'Utang Jangka Panjang Lainnya', 'LIABILITY'),
    ('2205', 'Liabilitas Imbalan Kerja', 'LIABILITY'),
    ('3101', 'Modal Pemilik', 'EQUITY'),
    ('3102', 'Tambahan Modal Disetor', 'EQUITY'),
    ('3103', 'Prive', 'EQUITY'),
    ('3104', 'Saldo Laba Ditahan', 'EQUITY'),
    ('3105', 'Laba Rugi Tahun Berjalan', 'EQUITY'),
    ('3106', 'Ikhtisar Laba Rugi', 'EQUITY'),
    ('3107', 'Bagi Hasil dan Dividen', 'EQUITY'),
    ('3108', 'Saldo Awal Ekuitas', 'EQUITY'),
    ('7101', 'Pendapatan Bunga Bank', 'REVENUE'),
    ('7102', 'Pendapatan Sewa', 'REVENUE'),
    ('7103', 'Laba Penjualan Aset Tetap', 'REVENUE'),
    ('7104', 'Keuntungan Selisih Kurs', 'REVENUE'),
    ('7105', 'Pendapatan Hibah dan Bantuan', 'REVENUE'),
    ('7106', 'Pendapatan Denda dan Komisi', 'REVENUE'),
    ('7107', 'Selisih Lebih Kas', 'REVENUE'),
    ('7108', 'Cashback dan Promo dari Pemasok', 'REVENUE'),
    ('7109', 'Pendapatan Lain-lain', 'REVENUE'),
    ('8101', 'Beban Bunga Pinjaman', 'EXPENSE'),
    ('8102', 'Beban Administrasi Bank', 'EXPENSE'),
    ('8103', 'Rugi Penjualan Aset Tetap', 'EXPENSE'),
    ('8104', 'Kerugian Selisih Kurs', 'EXPENSE'),
    ('8105', 'Selisih Kurang Kas', 'EXPENSE'),
    ('8106', 'Beban Denda dan Sanksi Pajak', 'EXPENSE'),
    ('8107', 'Kerugian Lain-lain', 'EXPENSE'),
    ('9101', 'Beban Pajak Penghasilan Final', 'EXPENSE'),
    ('9102', 'Beban Pajak Penghasilan Badan', 'EXPENSE'),
    ('6101', 'Beban Gaji dan Upah', 'EXPENSE'),
    ('6102', 'Beban Lembur', 'EXPENSE'),
    ('6103', 'Beban Bonus dan Insentif', 'EXPENSE'),
    ('6104', 'Beban THR', 'EXPENSE'),
    ('6105', 'Beban BPJS Ketenagakerjaan', 'EXPENSE'),
    ('6106', 'Beban BPJS Kesehatan', 'EXPENSE'),
    ('6107', 'Beban Tunjangan Karyawan', 'EXPENSE'),
    ('6108', 'Beban Pelatihan dan Pengembangan', 'EXPENSE'),
    ('6109', 'Beban Rekrutmen', 'EXPENSE'),
    ('6110', 'Beban Konsumsi Karyawan', 'EXPENSE'),
    ('6111', 'Beban Seragam Karyawan', 'EXPENSE'),
    ('6112', 'Beban Pesangon dan Imbalan Kerja', 'EXPENSE'),
    ('6201', 'Beban Sewa', 'EXPENSE'),
    ('6202', 'Beban Listrik', 'EXPENSE'),
    ('6203', 'Beban Air', 'EXPENSE'),
    ('6204', 'Beban Telepon dan Internet', 'EXPENSE'),
    ('6205', 'Beban Perlengkapan Kantor', 'EXPENSE'),
    ('6206', 'Beban ATK dan Percetakan', 'EXPENSE'),
    ('6207', 'Beban Kebersihan dan Keamanan', 'EXPENSE'),
    ('6208', 'Beban Perbaikan dan Pemeliharaan', 'EXPENSE'),
    ('6209', 'Beban Pemeliharaan Kendaraan', 'EXPENSE'),
    ('6210', 'Beban Bahan Bakar Kendaraan', 'EXPENSE'),
    ('6211', 'Beban Parkir dan Tol', 'EXPENSE'),
    ('6212', 'Beban Transportasi dan Perjalanan Dinas', 'EXPENSE'),
    ('6213', 'Beban Asuransi', 'EXPENSE'),
    ('6214', 'Beban Langganan Software dan Aplikasi', 'EXPENSE'),
    ('6215', 'Beban Perizinan dan Legalitas', 'EXPENSE'),
    ('6216', 'Beban Pajak dan Retribusi', 'EXPENSE'),
    ('6217', 'Beban Iuran dan Sumbangan', 'EXPENSE'),
    ('6218', 'Beban Jasa Profesional', 'EXPENSE'),
    ('6219', 'Beban Representasi dan Jamuan', 'EXPENSE'),
    ('6220', 'Beban Pos dan Pengiriman Dokumen', 'EXPENSE'),
    ('6221', 'Beban Piutang Tak Tertagih', 'EXPENSE'),
    ('6301', 'Beban Penyusutan Bangunan', 'EXPENSE'),
    ('6302', 'Beban Penyusutan Kendaraan', 'EXPENSE'),
    ('6303', 'Beban Penyusutan Peralatan', 'EXPENSE'),
    ('6304', 'Beban Penyusutan Peralatan Kantor', 'EXPENSE'),
    ('6305', 'Beban Penyusutan Komputer dan Perangkat IT', 'EXPENSE'),
    ('6306', 'Beban Penyusutan Mesin', 'EXPENSE'),
    ('6307', 'Beban Amortisasi Renovasi Bangunan Sewa', 'EXPENSE'),
    ('6308', 'Beban Amortisasi Aset Tak Berwujud', 'EXPENSE'),
    ('6401', 'Beban Iklan dan Promosi', 'EXPENSE'),
    ('6402', 'Beban Iklan Digital dan Media Sosial', 'EXPENSE'),
    ('6403', 'Beban Komisi Penjualan', 'EXPENSE'),
    ('6404', 'Beban Diskon dan Promo', 'EXPENSE'),
    ('6405', 'Beban Ongkos Kirim Penjualan', 'EXPENSE'),
    ('6406', 'Beban Biaya Platform Marketplace', 'EXPENSE'),
    ('6407', 'Beban Biaya Payment Gateway dan QRIS', 'EXPENSE'),
    ('6408', 'Beban Sampel dan Hadiah Pelanggan', 'EXPENSE'),
    ('6409', 'Beban Desain dan Konten', 'EXPENSE'),
    ('6410', 'Beban Event dan Pameran', 'EXPENSE'),
    ('6501', 'Beban Operasional Lain-lain', 'EXPENSE')
) as a(code, name, type);

-- =========================================================
-- 4. AKUN KHUSUS: DAGANG
-- =========================================================

insert into public.coa_template_accounts (template_id, code, name, type) values
  ('dagang', '1121', 'Persediaan Barang Dagang', 'ASSET'),
  ('dagang', '1122', 'Persediaan Barang dalam Perjalanan', 'ASSET'),
  ('dagang', '1123', 'Persediaan Kemasan', 'ASSET'),
  ('dagang', '1124', 'Cadangan Penurunan Nilai Persediaan', 'ASSET'),
  ('dagang', '4101', 'Penjualan', 'REVENUE'),
  ('dagang', '4102', 'Penjualan Online dan Marketplace', 'REVENUE'),
  ('dagang', '4103', 'Penjualan Grosir', 'REVENUE'),
  ('dagang', '4104', 'Pendapatan Ongkos Kirim', 'REVENUE'),
  ('dagang', '4105', 'Retur Penjualan', 'REVENUE'),
  ('dagang', '4106', 'Potongan Penjualan', 'REVENUE'),
  ('dagang', '5101', 'Pembelian Barang Dagang', 'EXPENSE'),
  ('dagang', '5102', 'Retur Pembelian', 'EXPENSE'),
  ('dagang', '5103', 'Potongan Pembelian', 'EXPENSE'),
  ('dagang', '5104', 'Beban Angkut Pembelian', 'EXPENSE'),
  ('dagang', '5105', 'Harga Pokok Penjualan', 'EXPENSE'),
  ('dagang', '5106', 'Selisih Stok Opname', 'EXPENSE'),
  ('dagang', '5107', 'Kerugian Barang Rusak dan Kedaluwarsa', 'EXPENSE'),
  ('dagang', '6222', 'Beban Pengemasan dan Packing', 'EXPENSE'),
  ('dagang', '6223', 'Beban Gudang', 'EXPENSE');

-- =========================================================
-- 5. AKUN KHUSUS: JASA
-- =========================================================

insert into public.coa_template_accounts (template_id, code, name, type) values
  ('jasa', '1131', 'Biaya Proyek dalam Proses', 'ASSET'),
  ('jasa', '1132', 'Pendapatan Jasa yang Belum Ditagih', 'ASSET'),
  ('jasa', '4101', 'Pendapatan Jasa', 'REVENUE'),
  ('jasa', '4102', 'Pendapatan Jasa Konsultasi', 'REVENUE'),
  ('jasa', '4103', 'Pendapatan Jasa Proyek', 'REVENUE'),
  ('jasa', '4104', 'Pendapatan Langganan dan Retainer', 'REVENUE'),
  ('jasa', '4105', 'Pendapatan Komisi dan Fee', 'REVENUE'),
  ('jasa', '4106', 'Retur dan Potongan Pendapatan', 'REVENUE'),
  ('jasa', '5101', 'Biaya Tenaga Kerja Langsung', 'EXPENSE'),
  ('jasa', '5102', 'Biaya Subkontraktor dan Freelance', 'EXPENSE'),
  ('jasa', '5103', 'Biaya Langsung Proyek', 'EXPENSE'),
  ('jasa', '5104', 'Biaya Perjalanan Proyek', 'EXPENSE'),
  ('jasa', '5105', 'Biaya Lisensi dan Software Proyek', 'EXPENSE');

-- =========================================================
-- 6. AKUN KHUSUS: KAFE / RESTO (F&B)
-- =========================================================

insert into public.coa_template_accounts (template_id, code, name, type) values
  ('fnb', '1121', 'Persediaan Bahan Makanan', 'ASSET'),
  ('fnb', '1122', 'Persediaan Bahan Minuman', 'ASSET'),
  ('fnb', '1123', 'Persediaan Kemasan dan Cup', 'ASSET'),
  ('fnb', '1124', 'Persediaan Gas dan Bahan Habis Pakai', 'ASSET'),
  ('fnb', '1216', 'Peralatan Dapur', 'ASSET'),
  ('fnb', '1217', 'Akumulasi Penyusutan Peralatan Dapur', 'ASSET'),
  ('fnb', '4101', 'Penjualan Makanan', 'REVENUE'),
  ('fnb', '4102', 'Penjualan Minuman', 'REVENUE'),
  ('fnb', '4103', 'Penjualan Snack dan Dessert', 'REVENUE'),
  ('fnb', '4104', 'Penjualan Pesan Antar Online', 'REVENUE'),
  ('fnb', '4105', 'Penjualan Catering dan Pesanan', 'REVENUE'),
  ('fnb', '4106', 'Pendapatan Service Charge', 'REVENUE'),
  ('fnb', '4107', 'Retur dan Diskon Penjualan', 'REVENUE'),
  ('fnb', '5101', 'Harga Pokok Makanan', 'EXPENSE'),
  ('fnb', '5102', 'Harga Pokok Minuman', 'EXPENSE'),
  ('fnb', '5103', 'Pembelian Bahan Makanan', 'EXPENSE'),
  ('fnb', '5104', 'Pembelian Bahan Minuman', 'EXPENSE'),
  ('fnb', '5105', 'Biaya Kemasan dan Cup', 'EXPENSE'),
  ('fnb', '5106', 'Biaya Bahan Habis Pakai Dapur', 'EXPENSE'),
  ('fnb', '5107', 'Selisih Stok dan Bahan Rusak', 'EXPENSE'),
  ('fnb', '6222', 'Beban Gas dan Bahan Bakar Dapur', 'EXPENSE'),
  ('fnb', '6223', 'Beban Peralatan Dapur dan Pecah Belah', 'EXPENSE'),
  ('fnb', '6224', 'Beban Kebersihan Dapur', 'EXPENSE'),
  ('fnb', '6309', 'Beban Penyusutan Peralatan Dapur', 'EXPENSE'),
  ('fnb', '6411', 'Beban Komisi Aplikasi Pesan Antar', 'EXPENSE');

-- =========================================================
-- 7. RPC: TERAPKAN TEMPLATE KE USAHA
-- =========================================================
-- Hanya owner usaha. Aman dijalankan ulang: akun dengan kode yang sudah ada dilewati.
-- Mengembalikan jumlah akun yang baru ditambahkan.

create or replace function public.apply_coa_template(p_business_id uuid, p_template_id text)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer;
begin
  if not public.is_owner(p_business_id) then
    raise exception 'Hanya owner usaha yang boleh menerapkan template akun';
  end if;

  if not exists (select 1 from public.coa_templates where id = p_template_id) then
    raise exception 'Template % tidak ditemukan', p_template_id;
  end if;

  insert into public.accounts (business_id, code, name, type)
  select p_business_id, code, name, type
  from public.coa_template_accounts
  where template_id = p_template_id
  on conflict (business_id, code) do nothing;

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke all on function public.apply_coa_template(uuid, text) from public, anon;
grant execute on function public.apply_coa_template(uuid, text) to authenticated;
