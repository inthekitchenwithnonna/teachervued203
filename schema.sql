-- Run in Supabase SQL Editor. NEVER put service_role key in website code.
create extension if not exists pgcrypto;
create table public.profiles (id uuid primary key references auth.users(id) on delete cascade, email text not null, full_name text not null default '', role text not null default 'pending' check(role in ('pending','admin','teacher')), created_at timestamptz not null default now());
create table public.students (id uuid primary key default gen_random_uuid(), first_name text not null, last_name text not null, grade text not null, status text not null default 'Active', created_at timestamptz not null default now());
create table public.courses (id uuid primary key default gen_random_uuid(), name text not null, period text not null default '', teacher_id uuid references public.profiles(id) on delete set null);
create table public.enrollments (id uuid primary key default gen_random_uuid(), student_id uuid not null references public.students(id) on delete cascade, course_id uuid not null references public.courses(id) on delete cascade, unique(student_id,course_id));
create table public.attendance (id uuid primary key default gen_random_uuid(), student_id uuid not null references public.students(id) on delete cascade, course_id uuid not null references public.courses(id) on delete cascade, day date not null, status text not null check(status in ('Present','Absent','Tardy','Excused')), unique(student_id,course_id,day));
create table public.grades (id uuid primary key default gen_random_uuid(), student_id uuid not null references public.students(id) on delete cascade, course_id uuid not null references public.courses(id) on delete cascade, assignment text not null, score numeric not null check(score>=0), possible numeric not null check(possible>0 and score<=possible));
create index on public.courses(teacher_id); create index on public.enrollments(course_id,student_id); create index on public.attendance(course_id); create index on public.grades(course_id);
-- Trigger creates a pending profile on sign-up; signup cannot choose its own role.
create function public.create_profile() returns trigger language plpgsql security definer set search_path = '' as $$ begin insert into public.profiles(id,email,full_name,role) values(new.id,coalesce(new.email,''),coalesce(new.raw_user_meta_data->>'full_name',''),'pending'); return new; end $$;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.create_profile();
-- Security-definer helpers prevent recursive profile policy evaluation.
create function public.is_admin() returns boolean language sql stable security definer set search_path = '' as $$ select exists(select 1 from public.profiles where id=(select auth.uid()) and role='admin') $$;
create function public.is_course_teacher(cid uuid) returns boolean language sql stable security definer set search_path = '' as $$ select exists(select 1 from public.courses where id=cid and teacher_id=(select auth.uid()) and exists(select 1 from public.profiles where id=(select auth.uid()) and role='teacher')) $$;
create function public.teaches_student(sid uuid) returns boolean language sql stable security definer set search_path = '' as $$ select exists(select 1 from public.enrollments e join public.courses c on c.id=e.course_id join public.profiles p on p.id=c.teacher_id where e.student_id=sid and p.id=(select auth.uid()) and p.role='teacher') $$;
create function public.is_enrolled(sid uuid,cid uuid) returns boolean language sql stable security definer set search_path = '' as $$ select exists(select 1 from public.enrollments e where e.student_id=sid and e.course_id=cid) $$;
revoke all on function public.is_enrolled(uuid,uuid) from public; revoke all on function public.is_admin() from public; revoke all on function public.is_course_teacher(uuid) from public; revoke all on function public.teaches_student(uuid) from public;
grant execute on function public.is_enrolled(uuid,uuid) to authenticated; grant execute on function public.is_admin() to authenticated; grant execute on function public.is_course_teacher(uuid) to authenticated; grant execute on function public.teaches_student(uuid) to authenticated;
alter table public.profiles enable row level security; alter table public.students enable row level security; alter table public.courses enable row level security; alter table public.enrollments enable row level security; alter table public.attendance enable row level security; alter table public.grades enable row level security;
create policy profile_read on public.profiles for select to authenticated using (id=(select auth.uid()) or public.is_admin());
create policy profile_admin_update on public.profiles for update to authenticated using (public.is_admin()) with check(public.is_admin());
create policy student_read on public.students for select to authenticated using (public.is_admin() or public.teaches_student(id));
create policy student_admin_insert on public.students for insert to authenticated with check(public.is_admin());
create policy student_admin_update on public.students for update to authenticated using(public.is_admin()) with check(public.is_admin());
create policy student_admin_delete on public.students for delete to authenticated using(public.is_admin());
create policy course_read on public.courses for select to authenticated using(public.is_admin() or public.is_course_teacher(id));
create policy course_admin_insert on public.courses for insert to authenticated with check(public.is_admin());
create policy course_admin_update on public.courses for update to authenticated using(public.is_admin()) with check(public.is_admin());
create policy course_admin_delete on public.courses for delete to authenticated using(public.is_admin());
create policy enrollment_read on public.enrollments for select to authenticated using(public.is_admin() or public.is_course_teacher(course_id));
create policy enrollment_admin_insert on public.enrollments for insert to authenticated with check(public.is_admin());
create policy enrollment_admin_update on public.enrollments for update to authenticated using(public.is_admin()) with check(public.is_admin());
create policy enrollment_admin_delete on public.enrollments for delete to authenticated using(public.is_admin());
create policy attendance_read on public.attendance for select to authenticated using(public.is_admin() or public.is_course_teacher(course_id));
create policy attendance_insert on public.attendance for insert to authenticated with check((public.is_admin() or public.is_course_teacher(course_id)) and public.is_enrolled(student_id,course_id));
create policy attendance_update on public.attendance for update to authenticated using(public.is_admin() or public.is_course_teacher(course_id)) with check((public.is_admin() or public.is_course_teacher(course_id)) and public.is_enrolled(student_id,course_id));
create policy attendance_delete on public.attendance for delete to authenticated using(public.is_admin() or public.is_course_teacher(course_id));
create policy grade_read on public.grades for select to authenticated using(public.is_admin() or public.is_course_teacher(course_id));
create policy grade_insert on public.grades for insert to authenticated with check((public.is_admin() or public.is_course_teacher(course_id)) and public.is_enrolled(student_id,course_id));
create policy grade_update on public.grades for update to authenticated using(public.is_admin() or public.is_course_teacher(course_id)) with check((public.is_admin() or public.is_course_teacher(course_id)) and public.is_enrolled(student_id,course_id));
create policy grade_delete on public.grades for delete to authenticated using(public.is_admin() or public.is_course_teacher(course_id));
-- After your first user signs up, promote ONLY that verified account in SQL Editor:
-- update public.profiles set role='admin' where id=(select id from auth.users where email='YOUR-EMAIL@example.com');
