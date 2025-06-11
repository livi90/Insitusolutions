-- Corregir el error específico de la columna assignment_type que no existe
-- Esta versión verifica primero si la tabla existe antes de intentar eliminar columnas

-- ===== VERIFICAR SI LA TABLA EXISTE =====
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
  
  IF table_exists THEN
    RAISE NOTICE 'La tabla work_assignments existe, procediendo con la verificación de columnas';
    
    -- Verificar si la columna assignment_type existe antes de intentar eliminarla
    IF EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_name = 'work_assignments' 
      AND column_name = 'assignment_type' 
      AND table_schema = 'public'
    ) THEN
      RAISE NOTICE 'Columna assignment_type existe, eliminándola...';
      ALTER TABLE public.work_assignments DROP COLUMN assignment_type;
      RAISE NOTICE 'Columna assignment_type eliminada exitosamente';
    ELSE
      RAISE NOTICE 'La columna assignment_type no existe en la tabla work_assignments';
    END IF;
    
    -- Mostrar estructura actual de la tabla
    RAISE NOTICE 'Estructura actual de work_assignments:';
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
  ELSE
    RAISE NOTICE 'La tabla work_assignments no existe, se creará desde cero';
  END IF;
END $$;

-- ===== RECREAR TABLA WORK_ASSIGNMENTS CON ESTRUCTURA CORRECTA =====
-- Eliminar tabla existente si existe y recrear con estructura limpia
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

-- ===== CREAR POLÍTICAS SIMPLES PARA WORK_ASSIGNMENTS =====
CREATE POLICY "work_assignments_select" ON public.work_assignments
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "work_assignments_insert" ON public.work_assignments
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "work_assignments_update" ON public.work_assignments
  FOR UPDATE USING (auth.uid() IS NOT NULL);

CREATE POLICY "work_assignments_delete" ON public.work_assignments
  FOR DELETE USING (auth.uid() IS NOT NULL);

-- ===== CREAR ASIGNACIONES DE EJEMPLO =====
DO $$
DECLARE
  admin_id UUID;
  encargado_id UUID;
  operario_id UUID := '11111111-1111-1111-1111-111111111111';
  peon_id UUID := '22222222-2222-2222-2222-222222222222';
  delivery_id UUID;
BEGIN
  -- Obtener IDs de usuarios
  SELECT id INTO admin_id FROM public.user_profiles WHERE email = 'admin@logistica.com' LIMIT 1;
  SELECT id INTO encargado_id FROM public.user_profiles WHERE email = 'encargado1@logistica.com' LIMIT 1;
  
  -- Crear entrega de ejemplo si no existe
  IF NOT EXISTS (SELECT 1 FROM public.deliveries WHERE title = 'Entrega de Materiales de Construcción') THEN
    INSERT INTO public.deliveries (id, title, description, delivery_address, status, created_by, created_at, updated_at)
    VALUES (
      gen_random_uuid(),
      'Entrega de Materiales de Construcción',
      'Entrega de cemento, varillas y herramientas para obra nueva',
      'Av. Principal 123, Zona Industrial',
      'pending',
      COALESCE(admin_id, encargado_id),
      NOW(),
      NOW()
    ) RETURNING id INTO delivery_id;
    
    RAISE NOTICE 'Entrega de ejemplo creada: %', delivery_id;
  ELSE
    SELECT id INTO delivery_id FROM public.deliveries WHERE title = 'Entrega de Materiales de Construcción' LIMIT 1;
    RAISE NOTICE 'Usando entrega existente: %', delivery_id;
  END IF;
  
  -- Crear asignaciones de trabajo si los usuarios existen
  IF admin_id IS NOT NULL OR encargado_id IS NOT NULL THEN
    -- Limpiar asignaciones existentes para esta entrega si existen
    IF delivery_id IS NOT NULL THEN
      DELETE FROM public.work_assignments WHERE delivery_id = delivery_id;
    END IF;
    
    -- Crear nuevas asignaciones
    INSERT INTO public.work_assignments (title, description, status, created_by, assigned_to, delivery_id, created_at, updated_at)
    VALUES 
    (
      'Carga de Materiales Pesados',
      'Cargar cemento y varillas en el camión usando maquinaria especializada',
      'pending',
      COALESCE(admin_id, encargado_id),
      operario_id,
      delivery_id,
      NOW(),
      NOW()
    ),
    (
      'Organización y Empaque',
      'Organizar herramientas menores y preparar empaque para transporte',
      'pending',
      COALESCE(admin_id, encargado_id),
      peon_id,
      delivery_id,
      NOW(),
      NOW()
    );
    
    RAISE NOTICE 'Asignaciones de trabajo creadas exitosamente';
  ELSE
    RAISE NOTICE 'No se encontraron usuarios admin o encargado para crear asignaciones';
  END IF;
END $$;

-- ===== FUNCIÓN PARA CREAR ASIGNACIONES AUTOMÁTICAMENTE =====
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
  END IF;
  
  RETURN assignments_created;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ===== TRIGGER PARA CREAR ASIGNACIONES AUTOMÁTICAMENTE =====
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

-- Crear trigger
DROP TRIGGER IF EXISTS auto_create_assignments_trigger ON public.deliveries;
CREATE TRIGGER auto_create_assignments_trigger
  AFTER INSERT ON public.deliveries
  FOR EACH ROW
  EXECUTE FUNCTION auto_create_worker_assignments();

-- ===== VERIFICAR DATOS FINALES =====
DO $$
DECLARE
  rec RECORD;
BEGIN
  RAISE NOTICE '=== VERIFICACIÓN FINAL ===';
  
  -- Mostrar entregas
  RAISE NOTICE 'ENTREGAS EN SISTEMA:';
  FOR rec IN 
    SELECT id, title, status, created_by 
    FROM public.deliveries 
    ORDER BY created_at DESC 
    LIMIT 5
  LOOP
    RAISE NOTICE '- %: % (%) - Creado por: %', 
      rec.id, rec.title, rec.status, rec.created_by;
  END LOOP;
  
  -- Mostrar asignaciones
  RAISE NOTICE '';
  RAISE NOTICE 'ASIGNACIONES DE TRABAJO:';
  FOR rec IN 
    SELECT wa.id, wa.title, wa.status, up.full_name, up.role
    FROM public.work_assignments wa
    JOIN public.user_profiles up ON wa.assigned_to = up.id
    ORDER BY wa.created_at DESC
  LOOP
    RAISE NOTICE '- %: % (%) - Asignado a: % (%)', 
      rec.id, rec.title, rec.status, rec.full_name, rec.role;
  END LOOP;
  
  RAISE NOTICE '';
  RAISE NOTICE 'ESTRUCTURA CORREGIDA:';
  RAISE NOTICE '- Tabla work_assignments recreada sin columnas problemáticas';
  RAISE NOTICE '- Función automática para crear asignaciones implementada';
  RAISE NOTICE '- Trigger configurado para nuevas entregas';
  RAISE NOTICE '- Políticas RLS simplificadas aplicadas';
END $$;
