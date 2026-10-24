// assets/supabase-client.js
// Klien Supabase bersama untuk semua halaman ERP.
// Hanya memakai Project URL dan PUBLISHABLE (anon) key. JANGAN taruh service_role key di sini.
// Harus dimuat SETELAH library supabase-js (CDN) dan SEBELUM skrip halaman.

const SUPABASE_URL = 'https://kjsnzisskklmvvglzztb.supabase.co';
const SUPABASE_KEY = 'sb_publishable_wSCsTawiCdXVDCagpwZCww_I21MM-n1';

const supabaseClient = window.supabase.createClient(SUPABASE_URL, SUPABASE_KEY);

// Kunci ini juga dipakai kasir (testingAI) agar membaca usaha yang sama.
const BUSINESS_KEY = 'ilhamerp_business_id';

function getActiveBusinessId() {
  try { return localStorage.getItem(BUSINESS_KEY); } catch (e) { return null; }
}

function setActiveBusinessId(id) {
  try { localStorage.setItem(BUSINESS_KEY, id); } catch (e) { /* abaikan */ }
}

function clearActiveBusinessId() {
  try { localStorage.removeItem(BUSINESS_KEY); } catch (e) { /* abaikan */ }
}

// Panggil di awal setiap halaman yang butuh login.
// Mengembalikan session, atau mengarahkan ke login.html bila belum login.
async function requireAuth() {
  const { data } = await supabaseClient.auth.getSession();
  if (!data.session) {
    window.location.href = 'login.html';
    return null;
  }
  return data.session;
}

// Panggil di halaman data: butuh login DAN usaha aktif.
async function requireBusiness() {
  const session = await requireAuth();
  if (!session) return null;
  const businessId = getActiveBusinessId();
  if (!businessId) {
    window.location.href = 'login.html';
    return null;
  }
  return { session, businessId };
}

async function signOut() {
  await supabaseClient.auth.signOut();
  clearActiveBusinessId();
  window.location.href = 'login.html';
}

// Daftar usaha milik pengguna yang sedang login.
async function listMyCompanies() {
  const { data, error } = await supabaseClient
    .from('business_members')
    .select('role, companies(id, nama, kode_usaha)');
  if (error) throw error;
  return (data || [])
    .filter(function (row) { return row.companies; })
    .map(function (row) {
      return {
        id: row.companies.id,
        nama: row.companies.nama,
        kode_usaha: row.companies.kode_usaha,
        role: row.role
      };
    });
}

// Buat usaha baru lewat RPC (otomatis menjadikan pembuatnya owner).
async function createCompany(nama) {
  const { data, error } = await supabaseClient.rpc('create_company', { p_nama: nama });
  if (error) throw error;
  return data;
}
