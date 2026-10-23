# EduVUE SIS — Supabase-backed version

A GitHub Pages-compatible frontend with real Supabase email/password authentication, a PostgreSQL database, role-based permissions and row-level security (RLS).

## Setup (about 15–30 minutes)

1. Create a **Supabase** project at https://supabase.com/ . Note: the free tier has limits and can change.
2. In Supabase **SQL Editor**, run all of `schema.sql` once on a **new empty project**. Do not run it twice.
3. Under **Authentication → Providers**, enable Email; keep email verification enabled. Configure **Authentication → URL Configuration** with your eventual GitHub Pages URL as Site URL and redirect URL. If you do not yet have the URL, you can configure it after creating the repository.
4. Copy `config.example.js` to `config.js`. In Supabase **Project Settings → API / Connect**, copy your project URL and **publishable (or legacy anon) key** into it. These are intended for browser use. **Never** paste the service-role key, secret key, database password, or API secret into GitHub.
5. Open the deployed site and create your first account. Verify its email. It will be `pending`.
6. In Supabase SQL Editor, run the following **after replacing the example email with your own verified email**:

   ```sql
   update public.profiles set role='admin'
   where id=(select id from auth.users where email='YOUR-EMAIL@example.com');
   ```

7. Sign out and back in. You now have administrator access. Other users can create accounts, but remain `pending` until you change their role under **Staff Accounts**. Only approve users you recognize.
8. In GitHub, create a repository and upload `index.html`, `app.js`, `schema.sql`, `config.js`, and this README. Enable **Settings → Pages → Deploy from a branch → main / root**.
9. Sign in from another browser/device: records are stored in Supabase and shared according to permissions.

## Roles and security

- **Pending:** no student records or staff directory access.
- **Teacher:** sees only assigned courses and students enrolled in those courses; can enter/update attendance and grades for enrolled students in assigned courses.
- **Admin:** manages students, teacher role assignments, courses, enrollments, grades, and attendance.
- Supabase Auth manages password hashing and login sessions. PostgreSQL RLS enforces access even if someone modifies browser JavaScript.
- Staff roles are assigned by an existing admin, not by self-registration.
- Teacher profiles are not created as actual Supabase Auth accounts by admins; teachers must register themselves, then an admin approves them.

## Important limitations

**Not production-certified for school student data.** This is a starter implementation, not a FERPA compliance guarantee or an independently security-audited SIS. Before using real student information, obtain school/district authorization, perform a formal privacy/security assessment, confirm data-processing terms, retention/deletion and backup requirements, configure MFA, audit logging, rate limits, appropriate student identifiers, disaster recovery, and ongoing updates. Avoid storing real student data in this project until those controls are in place.

GitHub Pages serves only the public frontend. Supabase hosts the shared database and authentication. The browser `config.js` key is public by design; RLS is the security boundary.

Do not run `schema.sql` against an existing database with important tables. SQL assumes a fresh Supabase project. No fictional sample student records are automatically inserted.
