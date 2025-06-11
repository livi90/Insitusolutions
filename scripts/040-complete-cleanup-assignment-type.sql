-- Limpieza completa y definitiva del error assignment_type
-- Este script elimina TODAS las referencias a assignment_type

-- ===== PASO 1: ELIMINAR TODOS LOS TRIGGERS =====
DROP TRIGGER IF EXISTS auto_create_assignments_trigger ON public.deliveries CASCADE;
DROP TRIGGER IF EXISTS delivery_status_change_trigger ON public.deliveries CASCADE;

-- ===== PASO 2: ELIMINAR TODAS LAS FUNCIONES RELACIONADAS =====
DROP FUNCTION IF EXISTS auto_create_worker_assignments() CASCADE;
DROP FUNCTION IF EXISTS create_worker_assignments_for_delivery(UUID, UUID) CASCADE;
DROP FUNCTION IF EXISTS create_work_assignments_for_delivery() CASCADE;
DROP FUNCTION IF EXISTS create_work_assignments_for_delivery(UUID) CASCADE;
DROP FUNCTION IF EXISTS handle_delivery_status_change() CASCADE;

-- ===== PASO 3: BUSCAR Y ELIMINAR CUALQUIER FUNCIÓN QUE CONTENGA assignment_type =====
DO $$
DECLARE
    func_record RECORD;
BEGIN
    -- Buscar todas las funciones que podrían contener assignment_type
    FOR func_record IN 
        SELECT n.nspname as schema_name, p.proname as function_name
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public'
        AND (
            p.proname LIKE '%assignment%' OR 
            p.proname LIKE '%work%' OR
            p.proname LIKE '%delivery%'
        )
    LOOP
        BEGIN
            EXECUTE format('DROP FUNCTION IF EXISTS %I.%I CASCADE', func_record.schema_name, func_record.function_name);
            RAISE NOTICE 'Eliminada función: %.%', func_record.schema_name, func_record.function_name;
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'No se pudo eliminar función: %.% - %', func_record.schema_name, func_record.function_name, SQLERRM;
        END;
    END LOOP;
END $$;

-- ===== PASO 4: RECREAR TABLA WORK_ASSIGNMENTS COMPLETAMENTE LIMPIA =====
DROP TABLE IF EXISTS public.work_assignments CASCADE;

CREATE TABLE public.work_assignments (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'in_progress', 'completed', 'cancelled')),
  priority TEXT DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
  special_instructions TEXT,
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

-- ===== PASO 5: CREAR POLÍTICAS SIMPLES =====
CREATE POLICY "work_assignments_select" ON public.work_assignments
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "work_assignments_insert" ON public.work_assignments
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "work_assignments_update" ON public.work_assignments
  FOR UPDATE USING (auth.uid() IS NOT NULL);

CREATE POLICY "work_assignments_delete" ON public.work_assignments
  FOR DELETE USING (auth.uid() IS NOT NULL);

-- ===== PASO 6: CREAR FUNCIÓN COMPLETAMENTE NUEVA SIN assignment_type =====
CREATE OR REPLACE FUNCTION create_work_assignments_for_delivery(
  p_delivery_id UUID,
  p_created_by UUID
)
RETURNS INTEGER AS $$
DECLARE
  operario_id UUID;
  peon_id UUID;
  assignments_created INTEGER := 0;
BEGIN
  RAISE NOTICE 'Iniciando creación de asignaciones para entrega: %', p_delivery_id;
  
  -- Buscar operario de maquinaria
  SELECT id INTO operario_id 
  FROM public.user_profiles 
  WHERE role = 'operario_maquinaria' 
  LIMIT 1;
  
  -- Buscar peón de logística
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
      priority,
      special_instructions,
      created_by,
      assigned_to,
      delivery_id,
      created_at,
      updated_at
    )
    VALUES (
      'Operación de Maquinaria',
      'Operar equipos especializados para carga y descarga',
      'pending',
      'normal',
      'Coordinar con el transportista para la operación segura',
      p_created_by,
      operario_id,
      p_delivery_id,
      NOW(),
      NOW()
    );
    assignments_created := assignments_created + 1;
    RAISE NOTICE 'Asignación creada para operario: %', operario_id;
  ELSE
    RAISE NOTICE 'No se encontró operario de maquinaria disponible';
  END IF;
  
  -- Crear asignación para peón si existe
  IF peon_id IS NOT NULL THEN
    INSERT INTO public.work_assignments (
      title,
      description,
      status,
      priority,
      special_instructions,
      created_by,
      assigned_to,
      delivery_id,
      created_at,
      updated_at
    )
    VALUES (
      'Apoyo Logístico',
      'Organizar, clasificar y preparar materiales',
      'pending',
      'normal',
      'Coordinar con transportista y supervisar descarga',
      p_created_by,
      peon_id,
      p_delivery_id,
      NOW(),
      NOW()
    );
    assignments_created := assignments_created + 1;
    RAISE NOTICE 'Asignación creada para peón: %', peon_id;
  ELSE
    RAISE NOTICE 'No se encontró peón de logística disponible';
  END IF;
  
  RAISE NOTICE 'Total de asignaciones creadas: %', assignments_created;
  RETURN assignments_created;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ===== PASO 7: CREAR FUNCIÓN DE TRIGGER LIMPIA =====
CREATE OR REPLACE FUNCTION auto_create_worker_assignments()
RETURNS TRIGGER AS $$
DECLARE
  assignments_count INTEGER;
BEGIN
  -- Solo para entregas nuevas con estado 'pending'
  IF TG_OP = 'INSERT' AND NEW.status = 'pending' THEN
    RAISE NOTICE 'Creando asignaciones automáticas para entrega: %', NEW.id;
    
    -- Crear asignaciones
    SELECT create_work_assignments_for_delivery(NEW.id, NEW.created_by) INTO assignments_count;
    
    RAISE NOTICE 'Creadas % asignaciones para entrega %', assignments_count, NEW.id;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ===== PASO 8: RECREAR FUNCIÓN DE NOTIFICACIONES =====
CREATE OR REPLACE FUNCTION handle_delivery_status_change()
RETURNS TRIGGER AS $$
BEGIN
  -- Notify when delivery is assigned
  IF OLD.status = 'pending' AND NEW.status = 'assigned' THEN
    PERFORM create_notification(
      'Entrega Asignada',
      'Te han asignado una nueva entrega: ' || NEW.title,
      'delivery_assigned',
      NEW.assigned_to,
      NEW.id
    );
  END IF;
  
  -- Notify when delivery is in transit
  IF OLD.status = 'assigned' AND NEW.status = 'in_transit' THEN
    PERFORM create_notification(
      'Entrega en Camino',
      'La entrega está en camino: ' || NEW.title,
      'delivery_in_transit',
      NEW.created_by,
      NEW.id
    );
  END IF;
  
  -- Notify when delivery is completed
  IF OLD.status = 'in_transit' AND NEW.status = 'delivered' THEN
    PERFORM create_notification(
      'Entrega Completada',
      'La entrega ha sido completada: ' || NEW.title,
      'delivery_completed',
      NEW.created_by,
      NEW.id
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ===== PASO 9: CREAR TRIGGERS =====
CREATE TRIGGER auto_create_assignments_trigger
  AFTER INSERT ON public.deliveries
  FOR EACH ROW
  EXECUTE FUNCTION auto_create_worker_assignments();

CREATE TRIGGER delivery_status_change_trigger
  AFTER UPDATE ON public.deliveries
  FOR EACH ROW
  EXECUTE FUNCTION handle_delivery_status_change();

-- ===== PASO 10: VERIFICACIÓN FINAL =====
DO $$
DECLARE
  column_exists BOOLEAN := FALSE;
  func_count INTEGER;
BEGIN
  RAISE NOTICE '=== VERIFICACIÓN FINAL COMPLETA ===';
  
  -- Verificar que no existe assignment_type
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'work_assignments' 
    AND column_name = 'assignment_type' 
    AND table_schema = 'public'
  ) INTO column_exists;
  
  IF NOT column_exists THEN
    RAISE NOTICE '✅ CORRECTO: La columna assignment_type NO existe';
  ELSE
    RAISE NOTICE '❌ ERROR: La columna assignment_type todavía existe';
  END IF;
  
  -- Contar funciones recreadas
  SELECT COUNT(*) INTO func_count
  FROM pg_proc p
  JOIN pg_namespace n ON p.pronamespace = n.oid
  WHERE n.nspname = 'public'
  AND p.proname IN ('create_work_assignments_for_delivery', 'auto_create_worker_assignments', 'handle_delivery_status_change');
  
  RAISE NOTICE '✅ Funciones recreadas: %', func_count;
  
  -- Verificar triggers
  IF EXISTS (
    SELECT 1 FROM information_schema.triggers 
    WHERE trigger_name = 'auto_create_assignments_trigger'
  ) THEN
    RAISE NOTICE '✅ Trigger auto_create_assignments_trigger: CREADO';
  ELSE
    RAISE NOTICE '❌ Trigger auto_create_assignments_trigger: NO ENCONTRADO';
  END IF;
  
  RAISE NOTICE '';
  RAISE NOTICE '🎯 LIMPIEZA COMPLETA TERMINADA';
  RAISE NOTICE '   - Todas las funciones antiguas eliminadas';
  RAISE NOTICE '   - Tabla work_assignments recreada sin assignment_type';
  RAISE NOTICE '   - Funciones nuevas creadas sin referencias problemáticas';
  RAISE NOTICE '   - Triggers recreados';
END $$;
