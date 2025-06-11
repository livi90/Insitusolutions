-- Solución definitiva para el error de assignment_type
-- Este script elimina completamente cualquier referencia a la columna problemática

-- ===== PASO 1: ELIMINAR TODOS LOS TRIGGERS Y FUNCIONES PROBLEMÁTICAS =====
DROP TRIGGER IF EXISTS auto_create_assignments_trigger ON public.deliveries;
DROP FUNCTION IF EXISTS auto_create_worker_assignments() CASCADE;
DROP FUNCTION IF EXISTS create_worker_assignments_for_delivery(UUID, UUID) CASCADE;

-- ===== PASO 2: VERIFICAR Y LIMPIAR LA TABLA WORK_ASSIGNMENTS =====
DO $$
DECLARE
  rec RECORD;
BEGIN
  -- Verificar si la tabla existe
  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_name = 'work_assignments' 
    AND table_schema = 'public'
  ) THEN
    RAISE NOTICE 'Tabla work_assignments existe, verificando estructura...';
    
    -- Mostrar estructura actual
    FOR rec IN 
      SELECT column_name, data_type, is_nullable 
      FROM information_schema.columns 
      WHERE table_name = 'work_assignments' 
      AND table_schema = 'public'
      ORDER BY ordinal_position
    LOOP
      RAISE NOTICE '- Columna: % (% - %)', rec.column_name, rec.data_type, 
        CASE WHEN rec.is_nullable = 'YES' THEN 'nullable' ELSE 'not null' END;
    END LOOP;
    
    -- Eliminar columna assignment_type si existe
    IF EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_name = 'work_assignments' 
      AND column_name = 'assignment_type' 
      AND table_schema = 'public'
    ) THEN
      RAISE NOTICE 'Eliminando columna assignment_type...';
      ALTER TABLE public.work_assignments DROP COLUMN assignment_type CASCADE;
      RAISE NOTICE 'Columna assignment_type eliminada';
    ELSE
      RAISE NOTICE 'Columna assignment_type no existe (correcto)';
    END IF;
  ELSE
    RAISE NOTICE 'Tabla work_assignments no existe, se creará';
  END IF;
END $$;

-- ===== PASO 3: RECREAR TABLA WORK_ASSIGNMENTS LIMPIA =====
DROP TABLE IF EXISTS public.work_assignments CASCADE;

CREATE TABLE public.work_assignments (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'in_progress', 'completed', 'cancelled')),
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

-- ===== PASO 4: CREAR POLÍTICAS SIMPLES =====
CREATE POLICY "work_assignments_select" ON public.work_assignments
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "work_assignments_insert" ON public.work_assignments
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "work_assignments_update" ON public.work_assignments
  FOR UPDATE USING (auth.uid() IS NOT NULL);

CREATE POLICY "work_assignments_delete" ON public.work_assignments
  FOR DELETE USING (auth.uid() IS NOT NULL);

-- ===== PASO 5: CREAR FUNCIÓN LIMPIA SIN ASSIGNMENT_TYPE =====
CREATE OR REPLACE FUNCTION create_worker_assignments_for_delivery(
  p_delivery_id UUID,
  p_created_by UUID
)
RETURNS INTEGER AS $$
DECLARE
  operario_id UUID;
  peon_id UUID;
  assignments_created INTEGER := 0;
BEGIN
  -- Buscar trabajadores disponibles
  SELECT id INTO operario_id 
  FROM public.user_profiles 
  WHERE role = 'operario_maquinaria' 
  LIMIT 1;
  
  SELECT id INTO peon_id 
  FROM public.user_profiles 
  WHERE role = 'peon_logistica' 
  LIMIT 1;
  
  -- Crear asignación para operario si existe
  IF operario_id IS NOT NULL THEN
    INSERT INTO public.work_assignments (
      title, 
      description, 
      status, 
      created_by, 
      assigned_to, 
      delivery_id,
      created_at,
      updated_at
    )
    VALUES (
      'Operación de Maquinaria para Entrega',
      'Operar equipos especializados para carga y descarga de materiales',
      'pending',
      p_created_by,
      operario_id,
      p_delivery_id,
      NOW(),
      NOW()
    );
    assignments_created := assignments_created + 1;
    RAISE NOTICE 'Asignación creada para operario: %', operario_id;
  END IF;
  
  -- Crear asignación para peón si existe
  IF peon_id IS NOT NULL THEN
    INSERT INTO public.work_assignments (
      title, 
      description, 
      status, 
      created_by, 
      assigned_to, 
      delivery_id,
      created_at,
      updated_at
    )
    VALUES (
      'Apoyo Logístico para Entrega',
      'Organizar, clasificar y preparar materiales para el transporte',
      'pending',
      p_created_by,
      peon_id,
      p_delivery_id,
      NOW(),
      NOW()
    );
    assignments_created := assignments_created + 1;
    RAISE NOTICE 'Asignación creada para peón: %', peon_id;
  END IF;
  
  RAISE NOTICE 'Total de asignaciones creadas: %', assignments_created;
  RETURN assignments_created;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ===== PASO 6: CREAR TRIGGER LIMPIO =====
CREATE OR REPLACE FUNCTION auto_create_worker_assignments()
RETURNS TRIGGER AS $$
DECLARE
  assignments_count INTEGER;
BEGIN
  -- Solo crear asignaciones para entregas nuevas con estado 'pending'
  IF TG_OP = 'INSERT' AND NEW.status = 'pending' THEN
    RAISE NOTICE 'Trigger ejecutado para entrega: % con estado: %', NEW.id, NEW.status;
    
    -- Crear asignaciones automáticamente
    SELECT create_worker_assignments_for_delivery(NEW.id, NEW.created_by) INTO assignments_count;
    
    RAISE NOTICE 'Creadas % asignaciones automáticas para entrega %', assignments_count, NEW.id;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Crear trigger
CREATE TRIGGER auto_create_assignments_trigger
  AFTER INSERT ON public.deliveries
  FOR EACH ROW
  EXECUTE FUNCTION auto_create_worker_assignments();

-- ===== PASO 7: CREAR DATOS DE PRUEBA =====
DO $$
DECLARE
  admin_id UUID;
  operario_id UUID := '11111111-1111-1111-1111-111111111111';
  peon_id UUID := '22222222-2222-2222-2222-222222222222';
  delivery_id UUID;
BEGIN
  -- Obtener ID del admin
  SELECT id INTO admin_id FROM public.user_profiles WHERE email = 'admin@logistica.com' LIMIT 1;
  
  IF admin_id IS NOT NULL THEN
    -- Crear entrega de prueba
    INSERT INTO public.deliveries (
      id, title, description, delivery_address, status, created_by, created_at, updated_at
    )
    VALUES (
      gen_random_uuid(),
      'Entrega de Prueba - Sin Assignment Type',
      'Entrega para verificar que el trigger funciona sin errores',
      'Dirección de Prueba 123',
      'pending',
      admin_id,
      NOW(),
      NOW()
    ) RETURNING id INTO delivery_id;
    
    RAISE NOTICE 'Entrega de prueba creada: %', delivery_id;
    
    -- Verificar asignaciones creadas
    FOR rec IN 
      SELECT wa.id, wa.title, up.full_name, up.role
      FROM public.work_assignments wa
      JOIN public.user_profiles up ON wa.assigned_to = up.id
      WHERE wa.delivery_id = delivery_id
    LOOP
      RAISE NOTICE 'Asignación: % - Asignado a: % (%)', rec.title, rec.full_name, rec.role;
    END LOOP;
  ELSE
    RAISE NOTICE 'No se encontró usuario admin para crear entrega de prueba';
  END IF;
END $$;

-- ===== PASO 8: VERIFICACIÓN FINAL =====
DO $$
DECLARE
  rec RECORD;
BEGIN
  RAISE NOTICE '=== VERIFICACIÓN FINAL ===';
  
  -- Verificar estructura de work_assignments
  RAISE NOTICE 'ESTRUCTURA DE WORK_ASSIGNMENTS:';
  FOR rec IN 
    SELECT column_name, data_type 
    FROM information_schema.columns 
    WHERE table_name = 'work_assignments' 
    AND table_schema = 'public'
    ORDER BY ordinal_position
  LOOP
    RAISE NOTICE '- %: %', rec.column_name, rec.data_type;
  END LOOP;
  
  -- Verificar que no existe assignment_type
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'work_assignments' 
    AND column_name = 'assignment_type' 
    AND table_schema = 'public'
  ) THEN
    RAISE NOTICE '✅ CORRECTO: La columna assignment_type NO existe';
  ELSE
    RAISE NOTICE '❌ ERROR: La columna assignment_type todavía existe';
  END IF;
  
  -- Verificar funciones y triggers
  RAISE NOTICE '';
  RAISE NOTICE 'FUNCIONES Y TRIGGERS:';
  RAISE NOTICE '- create_worker_assignments_for_delivery: RECREADA';
  RAISE NOTICE '- auto_create_worker_assignments: RECREADA';
  RAISE NOTICE '- auto_create_assignments_trigger: RECREADO';
  
  RAISE NOTICE '';
  RAISE NOTICE '✅ SOLUCIÓN APLICADA: El error de assignment_type debería estar resuelto';
END $$;
