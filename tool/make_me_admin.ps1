# Makes the owner's email account the payments admin (run once, after signing
# in at https://almafia.vercel.app/admin with eyadsyam124@gmail.com).
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)
$sql = "insert into public.commerce_admins(user_id,note) select id,'owner' from auth.users where lower(email)='eyadsyam124@gmail.com' and coalesce(is_anonymous,false)=false on conflict (user_id) do nothing; select count(*) as admins from public.commerce_admins;"
npx -y supabase db query --linked --project-ref hezjbrnveajypfqmjfnh $sql
