/// Canonical origin for links shared with players. Keep the old Vercel host
/// registered as an incoming App Link while new links use this origin.
const String kPublicWebOrigin = String.fromEnvironment(
  'PUBLIC_WEB_ORIGIN',
  defaultValue: 'https://saidalmafia.com',
);
