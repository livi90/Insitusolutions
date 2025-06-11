-- Corregir políticas de user_profiles para evitar recursión infinita

-- Eliminar todas las políticas existentes de user_profiles
DROP POLICY IF EXISTS "Users can view own profile" ON public.user_profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.user_profiles;
DROP POLICY IF EXISTS "View user profiles" ON public.user_profiles;
DROP POLICY IF EXISTS "Update own profile" ON public.user_profiles;

-- Crear políticas simples sin recursión
CREATE POLICY "Allow read access to user profiles" ON public.user_profiles
  FOR SELECT USING (true);

CREATE POLICY "Allow users to update own profile" ON public.user_profiles
  FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Allow insert for new users" ON public.user_profiles
  FOR INSERT WITH CHECK (auth.uid() = id);

-- Verificar que no hay otras políticas que puedan causar conflictos
-- Eliminar políticas problemáticas de work_assignments si existen
DROP POLICY IF EXISTS "Users can view their own assignments" ON public.work_assignments;
DROP POLICY IF EXISTS "Users can update their own assignments" ON public.work_assignments;
DROP POLICY IF EXISTS "Managers can create assignments" ON public.work_assignments;
DROP POLICY IF EXISTS "View work assignments" ON public.work_assignments;
DROP POLICY IF EXISTS "Update work assignments" ON public.work_assignments;
DROP POLICY IF EXISTS "Create work assignments" ON public.work_assignments;

-- Crear políticas simples para work_assignments
CREATE POLICY "Allow read work assignments" ON public.work_assignments
  FOR SELECT USING (
    assigned_to = auth.uid() OR 
    created_by = auth.uid() OR
    EXISTS (SELECT 1 FROM auth.users WHERE id = auth.uid())
  );

CREATE POLICY "Allow update work assignments" ON public.work_assignments
  FOR UPDATE USING (
    assigned_to = auth.uid() OR 
    created_by = auth.uid()
  );

CREATE POLICY "Allow create work assignments" ON public.work_assignments
  FOR INSERT WITH CHECK (
    created_by = auth.uid()
  );

-- Verificar políticas de deliveries también
DROP POLICY IF EXISTS "Users can view relevant deliveries" ON public.deliveries;
DROP POLICY IF EXISTS "Enhanced delivery visibility" ON public.deliveries;

CREATE POLICY "Allow read deliveries" ON public.deliveries
  FOR SELECT USING (
    created_by = auth.uid() OR
    assigned_to = auth.uid() OR
    EXISTS (SELECT 1 FROM auth.users WHERE id = auth.uid())
  );

-- Política simple para warehouse_requests
DROP POLICY IF EXISTS "Site managers can create requests" ON public.warehouse_requests;
DROP POLICY IF EXISTS "Users can view relevant requests" ON public.warehouse_requests;

CREATE POLICY "Allow read warehouse requests" ON public.warehouse_requests
  FOR SELECT USING (
    requested_by = auth.uid() OR
    EXISTS (SELECT 1 FROM auth.users WHERE id = auth.uid())
  );

CREATE POLICY "Allow create warehouse requests" ON public.warehouse_requests
  FOR INSERT WITH CHECK (
    requested_by = auth.uid()
  );

-- Política simple para work_sites
DROP POLICY IF EXISTS "Site managers can manage their sites" ON public.work_sites;

CREATE POLICY "Allow read work sites" ON public.work_sites
  FOR SELECT USING (
    site_manager_id = auth.uid() OR
    EXISTS (SELECT 1 FROM auth.users WHERE id = auth.uid())
  );

CREATE POLICY "Allow manage work sites" ON public.work_sites
  FOR ALL USING (
    site_manager_id = auth.uid()
  );

-- Política simple para notifications
DROP POLICY IF EXISTS "Users can view own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Enhanced notification visibility" ON public.notifications;

CREATE POLICY "Allow read notifications" ON public.notifications
  FOR SELECT USING (
    user_id = auth.uid()
  );

CREATE POLICY "Allow update notifications" ON public.notifications
  FOR UPDATE USING (
    user_id = auth.uid()
  );
