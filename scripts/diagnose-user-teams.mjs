// Read-only public API probe. Does NOT impersonate an authenticated user or test owner RLS.
const base = process.env.EXPO_PUBLIC_SUPABASE_URL;
const key = process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY;
if (!base || !key) throw new Error('Public Supabase config missing');
const url = new URL('/rest/v1/user_teams', base);
url.searchParams.set('select', '*');
url.searchParams.set('user_id', 'eq.00000000-0000-0000-0000-000000000000');
url.searchParams.set('limit', '1');
const response = await fetch(url, {headers: {apikey: key, Authorization: `Bearer ${key}`}});
const body = await response.json();
console.log(JSON.stringify({host: url.host, role: 'anon (not authenticated)', status: response.status, code: body?.code ?? null,
  message: typeof body?.message === 'string' && /^(Could not find the table|permission denied for table|relation .* does not exist)/.test(body.message) ? body.message : '(response details withheld)'}));
