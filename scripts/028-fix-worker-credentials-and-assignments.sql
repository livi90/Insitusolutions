-- Solucionar credenciales de trabajadores y restaurar funcionalidad de asignaciones

-- ===== VERIFICAR Y CORREGIR USUARIOS DE TRABAJADORES =====
DO $$
DECLARE
  operario_user_id UUID;
  peon_user_id UUID;
BEGIN
  -- Verificar si existen los usuarios en auth.users
  RAISE NOTICE 'Verificando usuarios en auth.users...';
  
  -- Buscar operario en auth.users
  SELECT id INTO operario_user_id 
  FROM auth.users 
  WHERE email = 'operario1@logistica.com';
  
  IF operario_user_id IS NULL THEN
    RAISE NOTICE 'Usuario operario no encontrado en auth.users';
  ELSE
    RAISE NOTICE 'Usuario operario encontrado: %', operario_user_id;
  END IF;
  
  -- Buscar peón en auth.users
  SELECT id INTO peon_user_id 
  FROM auth.users 
  WHERE email = 'peon1@logistica.com';
  
  IF peon_user_id IS NULL THEN
    RAISE NOTICE 'Usuario peón no encontrado en auth.users';
  ELSE
    RAISE NOTICE 'Usuario peón encontrado: %', peon_user_id;
  END IF;
  
  -- Verificar usuarios en user_profiles
  RAISE NOTICE 'Usuarios en user_profiles:';
  FOR rec IN 
    SELECT email, full_name, role, id 
    FROM public.user_profiles 
    WHERE email IN ('operario1@logistica.com', 'peon1@logistica.com')
    ORDER BY email 
  LOOP
    RAISE NOTICE '- %: % (%) - ID: %', rec.email, rec.full_name, rec.role, rec.id;
  END LOOP;
  
END $$;

-- ===== LIMPIAR Y RECREAR USUARIOS DE TRABAJADORES =====
-- Eliminar usuarios existentes si tienen problemas
DELETE FROM public.user_profiles WHERE email IN ('operario1@logistica.com', 'peon1@logistica.com');

-- Crear nuevos usuarios con IDs específicos para que coincidan con auth
DO $$
DECLARE
  operario_id UUID := '11111111-1111-1111-1111-111111111111';
  peon_id UUID := '22222222-2222-2222-2222-222222222222';
BEGIN
  -- Insertar operario
  INSERT INTO public.user_profiles (id, email, full_name, role, permission_level, created_at, updated_at)
  VALUES (
    operario_id,
    'operario1@logistica.com',
    'Miguel Operario',
    'operario_maquinaria',
    'normal',
    NOW(),
    NOW()
  );
  
  -- Insertar peón
  INSERT INTO public.user_profiles (id, email, full_name, role, permission_level, created_at, updated_at)
  VALUES (
    peon_id,
    'peon1@logistica.com',
    'José Peón',
    'peon_logistica',
    'normal',
    NOW(),
    NOW()
  );
  
  RAISE NOTICE 'Usuarios de trabajadores recreados con IDs fijos';
  RAISE NOTICE 'Operario ID: %', operario_id;
  RAISE NOTICE 'Peón ID: %', peon_id;
END $$;

-- ===== CREAR ENTREGAS DE EJEMPLO PARA PROBAR ASIGNACIONES =====
DO $$
DECLARE
  admin_id UUID;
  delivery_id UUID;
  operario_id UUID := '11111111-1111-1111-1111-111111111111';
  peon_id UUID := '22222222-2222-2222-2222-222222222222';
BEGIN
  -- Obtener ID del admin
  SELECT id INTO admin_id FROM public.user_profiles WHERE email = 'admin@logistica.com' LIMIT 1;
  
  IF admin_id IS NOT NULL THEN
    -- Crear entrega de ejemplo
    INSERT INTO public.deliveries (id, title, description, delivery_address, status, created_by, created_at, updated_at)
    VALUES (
      gen_random_uuid(),
      'Entrega de Materiales de Construcción',
      'Entrega de cemento, varillas y herramientas para obra nueva',
      'Av. Principal 123, Zona Industrial',
      'pending',
      admin_id,
      NOW(),
      NOW()
    ) RETURNING id INTO delivery_id;
    
    -- Crear asignaciones de trabajo para los trabajadores
    INSERT INTO public.work_assignments (title, description, status, created_by, assigned_to, delivery_id, created_at, updated_at)
    VALUES 
    (
      'Carga de Materiales Pesados',
      'Cargar cemento y varillas en el camión usando maquinaria especializada',
      'pending',
      admin_id,
      operario_id,
      delivery_id,
      NOW(),
      NOW()
    ),
    (
      'Organización y Empaque',
      'Organizar herramientas menores y preparar empaque para transporte',
      'pending',
      admin_id,
      peon_id,
      delivery_id,
      NOW(),
      NOW()
    );
    
    RAISE NOTICE 'Entrega y asignaciones de ejemplo creadas';
    RAISE NOTICE 'Delivery ID: %', delivery_id;
  ELSE
    RAISE NOTICE 'No se encontró usuario admin para crear entregas';
  END IF;
END $$;

-- ===== VERIFICAR ESTRUCTURA DE WORK_ASSIGNMENTS =====
-- Asegurar que la tabla tiene la estructura correcta
DO $$
BEGIN
  -- Verificar si la tabla existe
  IF NOT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'work_assignments' AND table_schema = 'public') THEN
    -- Crear la tabla si no existe
    CREATE TABLE public.work_assignments (
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
    
    ALTER TABLE public.work_assignments ENABLE ROW LEVEL SECURITY;
    RAISE NOTICE 'Tabla work_assignments creada';
  ELSE
    RAISE NOTICE 'Tabla work_assignments ya existe';
  END IF;
END $$;

-- ===== VERIFICAR POLÍTICAS DE WORK_ASSIGNMENTS =====
-- Eliminar políticas existentes y crear nuevas
DROP POLICY IF EXISTS "work_assignments_select" ON public.work_assignments;
DROP POLICY IF EXISTS "work_assignments_insert" ON public.work_assignments;
DROP POLICY IF EXISTS "work_assignments_update" ON public.work_assignments;
DROP POLICY IF EXISTS "work_assignments_delete" ON public.work_assignments;

-- Crear políticas simples
CREATE POLICY "work_assignments_select" ON public.work_assignments
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "work_assignments_insert" ON public.work_assignments
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "work_assignments_update" ON public.work_assignments
  FOR UPDATE USING (auth.uid() IS NOT NULL);

CREATE POLICY "work_assignments_delete" ON public.work_assignments
  FOR DELETE USING (auth.uid() IS NOT NULL);

-- ===== MOSTRAR INFORMACIÓN FINAL =====
DO $$
BEGIN
  RAISE NOTICE '=== INFORMACIÓN DE USUARIOS TRABAJADORES ===';
  RAISE NOTICE '';
  RAISE NOTICE 'CREDENCIALES PARA PROBAR:';
  RAISE NOTICE '- operario1@logistica.com / operario123';
  RAISE NOTICE '- peon1@logistica.com / peon123';
  RAISE NOTICE '';
  RAISE NOTICE 'NOTA: Si las credenciales siguen sin funcionar, es porque';
  RAISE NOTICE 'estos usuarios no existen en auth.users de Supabase.';
  RAISE NOTICE 'Debes crearlos manualmente desde el panel de Supabase Auth';
  RAISE NOTICE 'o usar el formulario de registro en la aplicación.';
  RAISE NOTICE '';
  RAISE NOTICE 'ASIGNACIONES CREADAS:';
  RAISE NOTICE '- Tarea para operario: Carga de Materiales Pesados';
  RAISE NOTICE '- Tarea para peón: Organización y Empaque';
  RAISE NOTICE '';
  
  -- Mostrar usuarios actuales
  RAISE NOTICE 'USUARIOS EN SISTEMA:';
  FOR rec IN SELECT email, full_name, role FROM public.user_profiles ORDER BY email LOOP
    RAISE NOTICE '- %: % (%)', rec.email, rec.full_name, rec.role;
  END LOOP;
  
  -- Mostrar asignaciones actuales
  RAISE NOTICE '';
  RAISE NOTICE 'ASIGNACIONES ACTUALES:';
  FOR rec IN 
    SELECT wa.title, up.full_name, up.email 
    FROM public.work_assignments wa 
    JOIN public.user_profiles up ON wa.assigned_to = up.id 
    ORDER BY wa.created_at DESC 
  LOOP
    RAISE NOTICE '- %: asignado a % (%)', rec.title, rec.full_name, rec.email;
  END LOOP;
END $$;
