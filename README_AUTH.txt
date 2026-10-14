HOME BUILD MANAGER PRO - AUTHENTICATED VERSION

SETUP
1. In Supabase SQL Editor, run schema_auth.sql only.
2. In Supabase Dashboard > Authentication > Providers, ensure Email is enabled.
3. In Authentication > URL Configuration, set Site URL to your hosted URL and add it to Redirect URLs.
4. Deploy index.html, styles.css, app.js, and supabase.js together.
5. Open the site, choose Create Account, and confirm the email if confirmation is enabled.
6. Sign in. The actual app is hidden until Supabase returns a valid session.

EXISTING DATA
Older rows have no owner_id and will be hidden. After creating your user, copy the user's UUID from Authentication > Users, then run the four UPDATE statements shown at the bottom of schema_auth.sql.

SECURITY
Passwords are handled by Supabase Auth and are not stored in public.profiles. RLS restricts each operational table to rows whose owner_id equals auth.uid(). The browser contains only the publishable key, never a service-role key.
