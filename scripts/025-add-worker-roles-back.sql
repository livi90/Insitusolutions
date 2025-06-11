-- Agregar de nuevo los roles de trabajadores que funcionaban correctamente
-- peon_logistica y operario_maquinaria

-- ===== AGREGAR NUEVOS VALORES AL ENUM user_role =====
DO $$
BEGIN
  -- Verificar si los roles existen en el enum y agregarlos si no están
  IF NOT EXISTS (
    SELECT 1 FROM pg_enum 
    WHERE enumlabel = 'peon_logistica' 
    AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'user_role')
  ) THEN
    ALTER TYPE user_role ADD VALUE 'peon_logistica';
    RAISE NOTICE 'Rol peon_logistica agregado exitosamente';
  ELSE
    RAISE NOTICE 'Rol peon_logistica ya existe';
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM pg_enum 
    WHERE enumlabel = 'operario_maquinaria' 
    AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'user_role')
  ) THEN
    ALTER TYPE user_role ADD VALUE 'operario_maquinaria';
    RAISE NOTICE 'Rol operario_maquinaria agregado exitosamente';
  ELSE
    RAISE NOTICE 'Rol operario_maquinaria ya existe';
  END IF;
END $$;

-- ===== CREAR TABLA WORK_ASSIGNMENTS DE NUEVO =====
-- Esta tabla es necesaria para asignar trabajadores a entregas
CREATE TABLE IF NOT EXISTS public.work_assignments (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT,
  status TEXT DEFAULT 'pending',
  created_by UUID REFERENCES public.user_profiles(id) NOT NULL,
  assigned_to UUID REFERENCES public.user_profiles(id) NOT NULL,
  delivery_id UUID REFERENCES public.deliveries(id),
  work_site_id UUID REFERENCES public.work_sites(id),
  scheduled_date TIMESTAMP WITH TIME ZONE,
  completed_date TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Habilitar RLS
ALTER TABLE public.work_assignments ENABLE ROW LEVEL SECURITY;

-- ===== POLÍTICAS PARA WORK_ASSIGNMENTS =====
-- Políticas simples que funcionaban antes

DROP POLICY IF EXISTS "View work assignments" ON public.work_assignments;
DROP POLICY IF EXISTS "Update work assignments" ON public.work_assignments;
DROP POLICY IF EXISTS "Create work assignments" ON public.work_assignments;

CREATE POLICY "View work assignments" ON public.work_assignments
  FOR SELECT USING (
    -- El asignado puede ver sus tareas
    assigned_to = auth.uid() OR 
    -- El creador puede ver las tareas que creó
    created_by = auth.uid() OR
    -- Oficial de almacén puede ver todas
    EXISTS (
      SELECT 1 FROM public.user_profiles 
      WHERE id = auth.uid() AND role = 'oficial_almacen'
    ) OR
    -- Encargado de obra puede ver tareas relacionadas con sus obras
    EXISTS (
      SELECT 1 FROM public.user_profiles 
      WHERE id = auth.uid() AND role = 'encargado_obra'
    )
  );

CREATE POLICY "Update work assignments" ON public.work_assignments
  FOR UPDATE USING (
    -- El asignado puede actualizar sus tareas
    assigned_to = auth.uid() OR 
    -- El creador puede actualizar las tareas que creó
    created_by = auth.uid() OR
    -- Oficial de almacén puede actualizar todas
    EXISTS (
      SELECT 1 FROM public.user_profiles 
      WHERE id = auth.uid() AND role = 'oficial_almacen'
    )
  );

CREATE POLICY "Create work assignments" ON public.work_assignments
  FOR INSERT WITH CHECK (
    -- Oficial de almacén puede crear asignaciones
    EXISTS (
      SELECT 1 FROM public.user_profiles 
      WHERE id = auth.uid() AND role = 'oficial_almacen'
    ) OR
    -- Encargado de obra puede crear asignaciones
    EXISTS (
      SELECT 1 FROM public.user_profiles 
      WHERE id = auth.uid() AND role = 'encargado_obra'
    )
  );

-- ===== ACTUALIZAR POLÍTICAS DE USER_PROFILES =====
-- Permitir que se puedan consultar los perfiles de trabajadores

DROP POLICY IF EXISTS "Users can view own profile" ON public.user_profiles;

CREATE POLICY "Users can view profiles" ON public.user_profiles
  FOR SELECT USING (
    -- Usuarios pueden ver su propio perfil
    auth.uid() = id OR
    -- Oficial de almacén puede ver todos los perfiles
    EXISTS (
      SELECT 1 FROM public.user_profiles 
      WHERE id = auth.uid() AND role = 'oficial_almacen'
    ) OR
    -- Encargado de obra puede ver perfiles de trabajadores
    EXISTS (
      SELECT 1 FROM public.user_profiles 
      WHERE id = auth.uid() AND role = 'encargado_obra'
    ) OR
    -- Transportistas pueden ver perfiles básicos (para asignaciones)
    EXISTS (
      SELECT 1 FROM public.user_profiles 
      WHERE id = auth.uid() AND role = 'transportista'
    )
  );

-- ===== CREAR USUARIOS DE EJEMPLO PARA LOS NUEVOS ROLES =====
-- Insertar usuarios de ejemplo para probar los nuevos roles

-- Verificar si ya existen usuarios con estos emails
DO $$
DECLARE
  operario_id UUID;
  peon_id UUID;
BEGIN
  -- Crear usuario operario de maquinaria
  IF NOT EXISTS (SELECT 1 FROM public.user_profiles WHERE email = 'operario1@logistica.com') THEN
    operario_id := gen_random_uuid();
    
    INSERT INTO public.user_profiles (id, email, full_name, role, permission_level)
    VALUES (
      operario_id,
      'operario1@logistica.com',
      'Miguel Operario',
      'operario_maquinaria',
      'normal'
    );
    
    RAISE NOTICE 'Usuario operario creado: operario1@logistica.com';
  ELSE
    RAISE NOTICE 'Usuario operario ya existe';
  END IF;
  
  -- Crear usuario peón de logística
  IF NOT EXISTS (SELECT 1 FROM public.user_profiles WHERE email = 'peon1@logistica.com') THEN
    peon_id := gen_random_uuid();
    
    INSERT INTO public.user_profiles (id, email, full_name, role, permission_level)
    VALUES (
      peon_id,
      'peon1@logistica.com',
      'José Peón',
      'peon_logistica',
      'normal'
    );
    
    RAISE NOTICE 'Usuario peón creado: peon1@logistica.com';
  ELSE
    RAISE NOTICE 'Usuario peón ya existe';
  END IF;
END $$;

-- ===== MENSAJE DE CONFIRMACIÓN =====
DO $$
BEGIN
  RAISE NOTICE '=== ROLES DE TRABAJADORES AGREGADOS ===';
  RAISE NOTICE 'Roles disponibles ahora:';
  RAISE NOTICE '- oficial_almacen';
  RAISE NOTICE '- transportista'; 
  RAISE NOTICE '- encargado_obra';
  RAISE NOTICE '- peon_logistica (NUEVO)';
  RAISE NOTICE '- operario_maquinaria (NUEVO)';
  RAISE NOTICE '';
  RAISE NOTICE 'Tabla work_assignments recreada';
  RAISE NOTICE 'Políticas actualizadas para soportar trabajadores';
  RAISE NOTICE 'Usuarios de ejemplo creados:';
  RAISE NOTICE '- operario1@logistica.com / operario123';
  RAISE NOTICE '- peon1@logistica.com / peon123';
END $$;
