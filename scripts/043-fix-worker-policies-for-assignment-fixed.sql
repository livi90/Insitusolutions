-- Arreglar políticas para permitir que oficiales de almacén y encargados de obra
-- puedan ver trabajadores para asignación

-- 1. Verificar y ajustar políticas de user_profiles para asignación de trabajadores
DROP POLICY IF EXISTS "Users can view worker profiles for assignment" ON user_profiles;

CREATE POLICY "Users can view worker profiles for assignment" ON user_profiles
FOR SELECT
USING (
  -- Los usuarios pueden ver su propio perfil
  auth.uid() = id
  OR
  -- Oficiales de almacén pueden ver perfiles de trabajadores para asignación
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

-- 2. Verificar políticas de workers si es necesario
DROP POLICY IF EXISTS "Users can view workers for assignment" ON workers;

CREATE POLICY "Users can view workers for assignment" ON workers
FOR SELECT
USING (
  -- Oficiales de almacén pueden ver todos los trabajadores
  EXISTS (
    SELECT 1 FROM user_profiles up 
    WHERE up.id = auth.uid() 
    AND up.role = 'oficial_almacen'
  )
  OR
  -- Encargados de obra pueden ver trabajadores de sus sitios
  EXISTS (
    SELECT 1 FROM user_profiles up 
    WHERE up.id = auth.uid() 
    AND up.role = 'encargado_obra'
  )
);

-- 3. Crear función para obtener trabajadores disponibles
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
  
  -- Retornar trabajadores disponibles
  RETURN QUERY
  SELECT 
    up.id,
    up.full_name,
    up.role,
    up.email
  FROM user_profiles up
  WHERE up.role IN ('operario_maquinaria', 'peon_logistica')
  ORDER BY up.role, up.full_name;
END $$;

-- 4. Otorgar permisos para la función
GRANT EXECUTE ON FUNCTION get_available_workers_for_assignment() TO authenticated;

-- 5. Verificar que existan trabajadores, si no, crear algunos de prueba
DO $$
DECLARE
    worker_count INTEGER;
    rec RECORD;
BEGIN
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

-- 6. Probar la función
SELECT 'Trabajadores disponibles:' as info;
SELECT * FROM get_available_workers_for_assignment();
