-- Corregir el problema de la función auto_create_worker_assignments que no existe
-- y asegurarnos de que el trigger funcione correctamente sin usar assignment_type

-- Primero, verificar si la función existe
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc 
    WHERE proname = 'auto_create_worker_assignments'
    AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
  ) THEN
    RAISE NOTICE 'La función auto_create_worker_assignments no existe, se creará desde cero';
  ELSE
    RAISE NOTICE 'La función auto_create_worker_assignments existe, se actualizará';
    -- Eliminar la función existente si existe
    DROP FUNCTION IF EXISTS auto_create_worker_assignments();
  END IF;
END $$;

-- Crear o reemplazar la función create_worker_assignments_for_delivery
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
    -- Insertar explícitamente solo las columnas que existen
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
  END IF;
  
  -- Crear asignación para peón si existe
  IF peon_id IS NOT NULL THEN
    -- Insertar explícitamente solo las columnas que existen
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
  END IF;
  
  RETURN assignments_created;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Crear la función auto_create_worker_assignments desde cero
CREATE OR REPLACE FUNCTION auto_create_worker_assignments()
RETURNS TRIGGER AS $$
DECLARE
  assignments_count INTEGER;
BEGIN
  -- Solo crear asignaciones para entregas nuevas con estado 'pending'
  IF TG_OP = 'INSERT' AND NEW.status = 'pending' THEN
    -- Crear asignaciones automáticamente
    SELECT create_worker_assignments_for_delivery(NEW.id, NEW.created_by) INTO assignments_count;
    
    IF assignments_count > 0 THEN
      -- Log para debugging
      RAISE NOTICE 'Creadas % asignaciones automáticas para entrega %', assignments_count, NEW.id;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Eliminar el trigger si existe
DROP TRIGGER IF EXISTS auto_create_assignments_trigger ON public.deliveries;

-- Crear el trigger
CREATE TRIGGER auto_create_assignments_trigger
  AFTER INSERT ON public.deliveries
  FOR EACH ROW
  EXECUTE FUNCTION auto_create_worker_assignments();

-- Verificar que la función y el trigger se han creado correctamente
DO $$
BEGIN
  RAISE NOTICE 'Función create_worker_assignments_for_delivery creada/actualizada';
  RAISE NOTICE 'Función auto_create_worker_assignments creada/actualizada';
  RAISE NOTICE 'Trigger auto_create_assignments_trigger recreado';
END $$;

-- Verificar que la tabla work_assignments existe y tiene la estructura correcta
DO $$
DECLARE
  table_exists BOOLEAN;
BEGIN
  -- Verificar si la tabla work_assignments existe
  SELECT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_name = 'work_assignments' 
    AND table_schema = 'public'
  ) INTO table_exists;
  
  IF NOT table_exists THEN
    RAISE NOTICE 'La tabla work_assignments no existe, se creará';
    
    -- Crear la tabla work_assignments
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
    
    -- Crear políticas simples
    CREATE POLICY "work_assignments_select" ON public.work_assignments
      FOR SELECT USING (auth.uid() IS NOT NULL);
    
    CREATE POLICY "work_assignments_insert" ON public.work_assignments
      FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
    
    CREATE POLICY "work_assignments_update" ON public.work_assignments
      FOR UPDATE USING (auth.uid() IS NOT NULL);
    
    CREATE POLICY "work_assignments_delete" ON public.work_assignments
      FOR DELETE USING (auth.uid() IS NOT NULL);
    
    RAISE NOTICE 'Tabla work_assignments creada con éxito';
  ELSE
    RAISE NOTICE 'La tabla work_assignments ya existe';
    
    -- Verificar si la columna assignment_type existe y eliminarla si es necesario
    IF EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_name = 'work_assignments' 
      AND column_name = 'assignment_type' 
      AND table_schema = 'public'
    ) THEN
      RAISE NOTICE 'Columna assignment_type existe, eliminándola...';
      ALTER TABLE public.work_assignments DROP COLUMN IF EXISTS assignment_type;
      RAISE NOTICE 'Columna assignment_type eliminada exitosamente';
    ELSE
      RAISE NOTICE 'La columna assignment_type no existe (correcto)';
    END IF;
  END IF;
END $$;

-- Mostrar estructura final de la tabla
DO $$
DECLARE
  rec RECORD;
BEGIN
  RAISE NOTICE 'Estructura final de work_assignments:';
  FOR rec IN 
    SELECT column_name, data_type, is_nullable 
    FROM information_schema.columns 
    WHERE table_name = 'work_assignments' 
    AND table_schema = 'public'
    ORDER BY ordinal_position
  LOOP
    RAISE NOTICE '- %: % (%)', rec.column_name, rec.data_type, 
      CASE WHEN rec.is_nullable = 'YES' THEN 'nullable' ELSE 'not null' END;
  END LOOP;
END $$;
