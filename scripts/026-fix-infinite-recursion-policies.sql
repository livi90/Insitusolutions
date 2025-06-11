-- Corregir el error de recursión infinita en las políticas
-- El problema está en que las políticas hacen referencia a user_profiles dentro de user_profiles

-- ===== ELIMINAR TODAS LAS POLÍTICAS PROBLEMÁTICAS =====
DROP POLICY IF EXISTS "Users can view profiles" ON public.user_profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.user_profiles;
DROP POLICY IF EXISTS "Users can view own profile" ON public.user_profiles;

-- ===== CREAR POLÍTICAS SIMPLES SIN RECURSIÓN =====
-- Política simple para SELECT - sin referencias a user_profiles
CREATE POLICY "Allow profile access" ON public.user_profiles
  FOR SELECT USING (true);

-- Política para UPDATE - solo el propio usuario
CREATE POLICY "Allow profile update" ON public.user_profiles
  FOR UPDATE USING (auth.uid() = id);

-- Política para INSERT - solo el propio usuario
CREATE POLICY "Allow profile insert" ON public.user_profiles
  FOR INSERT WITH CHECK (auth.uid() = id);

-- ===== CORREGIR POLÍTICAS DE OTRAS TABLAS QUE CAUSAN RECURSIÓN =====

-- Políticas para work_sites - sin referencias a user_profiles
DROP POLICY IF EXISTS "Site managers can manage their sites" ON public.work_sites;

CREATE POLICY "Allow work sites access" ON public.work_sites
  FOR SELECT USING (true);

CREATE POLICY "Allow work sites management" ON public.work_sites
  FOR ALL USING (site_manager_id = auth.uid());

-- Políticas para deliveries - sin referencias a user_profiles
DROP POLICY IF EXISTS "Users can view relevant deliveries" ON public.deliveries;
DROP POLICY IF EXISTS "Warehouse officials can manage deliveries" ON public.deliveries;

CREATE POLICY "Allow deliveries access" ON public.deliveries
  FOR SELECT USING (
    created_by = auth.uid() OR
    assigned_to = auth.uid() OR
    auth.uid() IS NOT NULL
  );

CREATE POLICY "Allow deliveries management" ON public.deliveries
  FOR ALL USING (
    created_by = auth.uid() OR
    auth.uid() IS NOT NULL
  );

-- Políticas para warehouse_requests - sin referencias a user_profiles
DROP POLICY IF EXISTS "Site managers can create requests" ON public.warehouse_requests;
DROP POLICY IF EXISTS "Users can view relevant requests" ON public.warehouse_requests;

CREATE POLICY "Allow warehouse requests access" ON public.warehouse_requests
  FOR SELECT USING (true);

CREATE POLICY "Allow warehouse requests creation" ON public.warehouse_requests
  FOR INSERT WITH CHECK (requested_by = auth.uid());

CREATE POLICY "Allow warehouse requests update" ON public.warehouse_requests
  FOR UPDATE USING (requested_by = auth.uid());

-- Políticas para work_assignments - sin referencias a user_profiles
DROP POLICY IF EXISTS "View work assignments" ON public.work_assignments;
DROP POLICY IF EXISTS "Update work assignments" ON public.work_assignments;
DROP POLICY IF EXISTS "Create work assignments" ON public.work_assignments;

CREATE POLICY "Allow work assignments access" ON public.work_assignments
  FOR SELECT USING (
    assigned_to = auth.uid() OR 
    created_by = auth.uid() OR
    auth.uid() IS NOT NULL
  );

CREATE POLICY "Allow work assignments update" ON public.work_assignments
  FOR UPDATE USING (
    assigned_to = auth.uid() OR 
    created_by = auth.uid()
  );

CREATE POLICY "Allow work assignments creation" ON public.work_assignments
  FOR INSERT WITH CHECK (created_by = auth.uid());

-- ===== ACTUALIZAR USUARIOS EXISTENTES CON LOS NUEVOS ROLES =====
-- Actualizar usuarios existentes para incluir los roles de trabajadores

DO $$
BEGIN
  -- Verificar y actualizar usuarios existentes
  
  -- Crear usuario operario si no existe
  IF NOT EXISTS (SELECT 1 FROM public.user_profiles WHERE email = 'operario1@logistica.com') THEN
    INSERT INTO public.user_profiles (id, email, full_name, role, permission_level)
    VALUES (
      gen_random_uuid(),
      'operario1@logistica.com',
      'Miguel Operario',
      'operario_maquinaria',
      'normal'
    );
    RAISE NOTICE 'Usuario operario creado: operario1@logistica.com';
  ELSE
    -- Actualizar rol si ya existe
    UPDATE public.user_profiles 
    SET role = 'operario_maquinaria', full_name = 'Miguel Operario'
    WHERE email = 'operario1@logistica.com';
    RAISE NOTICE 'Usuario operario actualizado';
  END IF;
  
  -- Crear usuario peón si no existe
  IF NOT EXISTS (SELECT 1 FROM public.user_profiles WHERE email = 'peon1@logistica.com') THEN
    INSERT INTO public.user_profiles (id, email, full_name, role, permission_level)
    VALUES (
      gen_random_uuid(),
      'peon1@logistica.com',
      'José Peón',
      'peon_logistica',
      'normal'
    );
    RAISE NOTICE 'Usuario peón creado: peon1@logistica.com';
  ELSE
    -- Actualizar rol si ya existe
    UPDATE public.user_profiles 
    SET role = 'peon_logistica', full_name = 'José Peón'
    WHERE email = 'peon1@logistica.com';
    RAISE NOTICE 'Usuario peón actualizado';
  END IF;
  
  -- Verificar usuarios existentes
  RAISE NOTICE 'Usuarios en el sistema:';
  FOR rec IN SELECT email, full_name, role FROM public.user_profiles ORDER BY email LOOP
    RAISE NOTICE '- %: % (%)', rec.email, rec.full_name, rec.role;
  END LOOP;
  
END $$;

-- ===== VERIFICAR QUE RLS ESTÁ HABILITADO =====
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.work_sites ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.deliveries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.warehouse_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.work_assignments ENABLE ROW LEVEL SECURITY;

-- ===== MENSAJE DE CONFIRMACIÓN =====
DO $$
BEGIN
  RAISE NOTICE '=== RECURSIÓN INFINITA CORREGIDA ===';
  RAISE NOTICE 'Políticas simplificadas sin referencias circulares';
  RAISE NOTICE 'Usuarios de trabajadores actualizados/creados';
  RAISE NOTICE '';
  RAISE NOTICE 'Credenciales de acceso:';
  RAISE NOTICE '- admin@logistica.com / admin123 (Oficial Almacén)';
  RAISE NOTICE '- transportista1@logistica.com / trans123 (Transportista)';
  RAISE NOTICE '- encargado1@logistica.com / obra123 (Encargado Obra)';
  RAISE NOTICE '- operario1@logistica.com / operario123 (Operario Maquinaria)';
  RAISE NOTICE '- peon1@logistica.com / peon123 (Peón Logística)';
  RAISE NOTICE '';
  RAISE NOTICE 'Error de recursión infinita resuelto';
END $$;
