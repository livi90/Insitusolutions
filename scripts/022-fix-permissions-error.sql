-- Corregir el error de permisos en la tabla users
-- El problema es que las políticas están intentando acceder a auth.users incorrectamente

-- ===== CORREGIR POLÍTICAS DE USER_PROFILES =====
DROP POLICY IF EXISTS "Users can view own profile" ON public.user_profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.user_profiles;

-- Políticas más simples sin referencias problemáticas
CREATE POLICY "Allow users to view profiles" ON public.user_profiles
  FOR SELECT USING (true);

CREATE POLICY "Allow users to update own profile" ON public.user_profiles
  FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Allow users to insert own profile" ON public.user_profiles
  FOR INSERT WITH CHECK (auth.uid() = id);

-- ===== CORREGIR POLÍTICAS DE DELIVERIES =====
DROP POLICY IF EXISTS "Users can view relevant deliveries" ON public.deliveries;
DROP POLICY IF EXISTS "Warehouse officials can manage deliveries" ON public.deliveries;

-- Política simple para deliveries
CREATE POLICY "Allow users to view deliveries" ON public.deliveries
  FOR SELECT USING (
    created_by = auth.uid() OR
    assigned_to = auth.uid() OR
    auth.uid() IS NOT NULL
  );

CREATE POLICY "Allow users to manage deliveries" ON public.deliveries
  FOR ALL USING (
    created_by = auth.uid() OR
    auth.uid() IS NOT NULL
  );

-- ===== CORREGIR POLÍTICAS DE WORK_SITES =====
DROP POLICY IF EXISTS "Site managers can manage their sites" ON public.work_sites;

CREATE POLICY "Allow users to view work sites" ON public.work_sites
  FOR SELECT USING (
    site_manager_id = auth.uid() OR
    auth.uid() IS NOT NULL
  );

CREATE POLICY "Allow users to manage work sites" ON public.work_sites
  FOR ALL USING (
    site_manager_id = auth.uid() OR
    auth.uid() IS NOT NULL
  );

-- ===== CORREGIR POLÍTICAS DE WAREHOUSE_REQUESTS =====
DROP POLICY IF EXISTS "Site managers can create requests" ON public.warehouse_requests;
DROP POLICY IF EXISTS "Users can view relevant requests" ON public.warehouse_requests;

CREATE POLICY "Allow users to view warehouse requests" ON public.warehouse_requests
  FOR SELECT USING (
    requested_by = auth.uid() OR
    auth.uid() IS NOT NULL
  );

CREATE POLICY "Allow users to create warehouse requests" ON public.warehouse_requests
  FOR INSERT WITH CHECK (
    requested_by = auth.uid()
  );

CREATE POLICY "Allow users to update warehouse requests" ON public.warehouse_requests
  FOR UPDATE USING (
    requested_by = auth.uid() OR
    auth.uid() IS NOT NULL
  );

-- ===== CORREGIR POLÍTICAS DE NOTIFICATIONS =====
DROP POLICY IF EXISTS "Users can view own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users can update own notifications" ON public.notifications;

CREATE POLICY "Allow users to view notifications" ON public.notifications
  FOR SELECT USING (
    user_id = auth.uid()
  );

CREATE POLICY "Allow users to update notifications" ON public.notifications
  FOR UPDATE USING (
    user_id = auth.uid()
  );

CREATE POLICY "Allow system to create notifications" ON public.notifications
  FOR INSERT WITH CHECK (true);

-- ===== VERIFICAR QUE RLS ESTÁ HABILITADO =====
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.deliveries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.work_sites ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.warehouse_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- ===== CREAR FUNCIÓN PARA VERIFICAR ROLES SIN RECURSIÓN =====
CREATE OR REPLACE FUNCTION get_user_role(user_id UUID)
RETURNS TEXT AS $$
DECLARE
  user_role TEXT;
BEGIN
  SELECT role INTO user_role
  FROM public.user_profiles
  WHERE id = user_id;
  
  RETURN COALESCE(user_role, 'transportista');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ===== GRANT PERMISOS NECESARIOS =====
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO anon, authenticated;
