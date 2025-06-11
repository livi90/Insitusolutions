-- Corregir función y restaurar asignación completa de trabajadores y transportistas
-- como funcionaba en la versión 20

-- 1. Eliminar función problemática y recrearla correctamente
DROP FUNCTION IF EXISTS get_available_workers_for_assignment();

-- 2. Crear función corregida para obtener trabajadores disponibles
CREATE OR REPLACE FUNCTION get_available_workers_for_assignment()
RETURNS TABLE (
  id UUID,
  full_name TEXT,
  role TEXT,
  email TEXT
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  user_role TEXT;
BEGIN
  -- Obtener el rol del usuario actual
  SELECT up.role INTO user_role 
  FROM user_profiles up 
  WHERE up.id = auth.uid();
  
  -- Verificar que el usuario tenga permisos para asignar trabajadores
  IF user_role NOT IN ('oficial_almacen', 'encargado_obra') THEN
    RAISE EXCEPTION 'No tienes permisos para ver trabajadores';
  END IF;
  
  -- Retornar trabajadores disponibles (incluyendo transportistas para oficial_almacen)
  RETURN QUERY
  SELECT 
    up.id,
    up.full_name,
    up.role,
    up.email
  FROM user_profiles up
  WHERE 
    CASE 
      WHEN user_role = 'oficial_almacen' THEN 
        up.role IN ('operario_maquinaria', 'peon_logistica', 'transportista')
      WHEN user_role = 'encargado_obra' THEN 
        up.role IN ('operario_maquinaria', 'peon_logistica')
      ELSE FALSE
    END
  ORDER BY up.role, up.full_name;
END $$;

-- 3. Otorgar permisos para la función
GRANT EXECUTE ON FUNCTION get_available_workers_for_assignment() TO authenticated;

-- 4. Actualizar políticas para permitir ver transportistas
DROP POLICY IF EXISTS "Users can view worker profiles for assignment" ON user_profiles;

CREATE POLICY "Users can view worker profiles for assignment" ON user_profiles
FOR SELECT
USING (
  -- Los usuarios pueden ver su propio perfil
  auth.uid() = id
  OR
  -- Oficiales de almacén pueden ver perfiles de trabajadores Y transportistas para asignación
  (
    EXISTS (
      SELECT 1 FROM user_profiles up 
      WHERE up.id = auth.uid() 
      AND up.role = 'oficial_almacen'
    )
    AND user_profiles.role IN ('operario_maquinaria', 'peon_logistica', 'transportista')
  )
  OR
  -- Encargados de obra pueden ver perfiles de trabajadores para asignación
  (
    EXISTS (
      SELECT 1 FROM user_profiles up 
      WHERE up.id = auth.uid() 
      AND up.role = 'encargado_obra'
    )
    AND user_profiles.role IN ('operario_maquinaria', 'peon_logistica')
  )
);

-- 5. Crear función para asignar transportista a entrega (como en versión 20)
CREATE OR REPLACE FUNCTION assign_transporter_to_delivery(
  delivery_id UUID,
  transporter_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  user_role TEXT;
  transporter_role TEXT;
BEGIN
  -- Verificar que el usuario actual sea oficial de almacén
  SELECT up.role INTO user_role 
  FROM user_profiles up 
  WHERE up.id = auth.uid();
  
  IF user_role != 'oficial_almacen' THEN
    RAISE EXCEPTION 'Solo los oficiales de almacén pueden asignar transportistas';
  END IF;
  
  -- Verificar que el usuario a asignar sea transportista
  SELECT up.role INTO transporter_role 
  FROM user_profiles up 
  WHERE up.id = transporter_id;
  
  IF transporter_role != 'transportista' THEN
    RAISE EXCEPTION 'Solo se pueden asignar usuarios con rol de transportista';
  END IF;
  
  -- Actualizar la entrega
  UPDATE deliveries 
  SET 
    assigned_to = transporter_id,
    status = 'assigned',
    updated_at = NOW()
  WHERE id = delivery_id;
  
  -- Crear notificación para el transportista
  INSERT INTO notifications (
    id,
    title,
    message,
    type,
    user_id,
    delivery_id,
    read,
    created_at
  ) VALUES (
    gen_random_uuid(),
    'Nueva entrega asignada',
    'Se te ha asignado una nueva entrega para transportar',
    'delivery_assigned',
    transporter_id,
    delivery_id,
    false,
    NOW()
  );
  
  RETURN TRUE;
END $$;

-- 6. Otorgar permisos para la función de asignación
GRANT EXECUTE ON FUNCTION assign_transporter_to_delivery(UUID, UUID) TO authenticated;

-- 7. Verificar que existan transportistas, si no, crear algunos
DO $$
DECLARE
    transporter_count INTEGER;
    worker_count INTEGER;
BEGIN
    -- Verificar transportistas
    SELECT COUNT(*) INTO transporter_count 
    FROM user_profiles 
    WHERE role = 'transportista';
    
    IF transporter_count = 0 THEN
        RAISE NOTICE 'No se encontraron transportistas, creando transportistas de prueba...';
        
        INSERT INTO user_profiles (id, email, full_name, role, permission_level, created_at, updated_at)
        VALUES 
            (gen_random_uuid(), 'transportista1@insitu.com', 'Pedro Rodríguez - Transportista', 'transportista', 'normal', NOW(), NOW()),
            (gen_random_uuid(), 'transportista2@insitu.com', 'Luis Fernández - Transportista', 'transportista', 'normal', NOW(), NOW()),
            (gen_random_uuid(), 'transportista3@insitu.com', 'Miguel Torres - Transportista', 'transportista', 'normal', NOW(), NOW());
        
        RAISE NOTICE 'Transportistas de prueba creados exitosamente';
    ELSE
        RAISE NOTICE 'Se encontraron % transportistas existentes', transporter_count;
    END IF;
    
    -- Verificar trabajadores
    SELECT COUNT(*) INTO worker_count 
    FROM user_profiles 
    WHERE role IN ('operario_maquinaria', 'peon_logistica');
    
    IF worker_count = 0 THEN
        RAISE NOTICE 'No se encontraron trabajadores, creando trabajadores de prueba...';
        
        INSERT INTO user_profiles (id, email, full_name, role, permission_level, created_at, updated_at)
        VALUES 
            (gen_random_uuid(), 'operario1@insitu.com', 'Juan Pérez - Operario Maquinaria', 'operario_maquinaria', 'normal', NOW(), NOW()),
            (gen_random_uuid(), 'operario2@insitu.com', 'María García - Operario Maquinaria', 'operario_maquinaria', 'normal', NOW(), NOW()),
            (gen_random_uuid(), 'peon1@insitu.com', 'Carlos López - Peón Logística', 'peon_logistica', 'normal', NOW(), NOW()),
            (gen_random_uuid(), 'peon2@insitu.com', 'Ana Martínez - Peón Logística', 'peon_logistica', 'normal', NOW(), NOW()),
            (gen_random_uuid(), 'peon3@insitu.com', 'Roberto Silva - Peón Logística', 'peon_logistica', 'normal', NOW(), NOW());
        
        RAISE NOTICE 'Trabajadores de prueba creados exitosamente';
    ELSE
        RAISE NOTICE 'Se encontraron % trabajadores existentes', worker_count;
    END IF;
END $$;

-- 8. Probar la función corregida
SELECT 'Trabajadores y transportistas disponibles:' as info;
SELECT * FROM get_available_workers_for_assignment();

-- 9. Mostrar resumen de usuarios por rol
SELECT 
    role,
    COUNT(*) as cantidad,
    STRING_AGG(full_name, ', ') as nombres
FROM user_profiles 
WHERE role IN ('oficial_almacen', 'transportista', 'operario_maquinaria', 'peon_logistica', 'encargado_obra')
GROUP BY role
ORDER BY role;
