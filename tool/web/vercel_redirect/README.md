almafia.vercel.app is kept only as a permanent redirect to https://saidalmafia.com
(links shared by 1.0 builds and old invites keep working). It still serves
/.well-known/assetlinks.json directly, because Android App Links verification
does not follow redirects. Deploy: copy build/web/.vercel here, then
`npx vercel deploy --prod --yes` from this folder and alias to almafia.vercel.app.
