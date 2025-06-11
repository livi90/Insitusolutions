-- Corregir el trigger que está intentando usar la columna assignment_type

-- Primero, eliminar el trigger existente
DROP TRIGGER IF EXISTS auto_create_assignments_trigger ON public.deliveries;

-- Luego, actualizar la función para asegurarnos de que no use assignment_type
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

-- Recrear el trigger con la función actualizada
CREATE TRIGGER auto_create_assignments_trigger
  AFTER INSERT ON public.deliveries
  FOR EACH ROW
  EXECUTE FUNCTION auto_create_worker_assignments();

-- Verificar que la función y el trigger se han creado correctamente
DO $$
BEGIN
  RAISE NOTICE 'Función create_worker_assignments_for_delivery actualizada';
  RAISE NOTICE 'Trigger auto_create_assignments_trigger recreado';
END $$;
