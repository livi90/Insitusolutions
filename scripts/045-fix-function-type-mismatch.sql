-- Corregir el error de tipo en la función get_available_workers_for_assignment

-- 1. Eliminar función problemática
DROP FUNCTION IF EXISTS get_available_workers_for_assignment();

-- 2. Crear función corregida con tipos correctos
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
  current_user_role TEXT;
BEGIN
  -- Obtener el rol del usuario actual y convertir a TEXT
  SELECT up.role::TEXT INTO current_user_role 
  FROM user_profiles up 
  WHERE up.id = auth.uid();
  
  -- Verificar que el usuario tenga permisos para asignar trabajadores
  IF current_user_role NOT IN ('oficial_almacen', 'encargado_obra') THEN
    RAISE EXCEPTION 'No tienes permisos para ver trabajadores';
  END IF;
  
  -- Retornar trabajadores disponibles con conversión explícita de tipos
  RETURN QUERY
  SELECT 
    up.id,
    up.full_name,
    up.role::TEXT,  -- Conversión explícita a TEXT
    up.email
  FROM user_profiles up
  WHERE 
    CASE 
      WHEN current_user_role = 'oficial_almacen' THEN 
        up.role::TEXT IN ('operario_maquinaria', 'peon_logistica', 'transportista')
      WHEN current_user_role = 'encargado_obra' THEN 
        up.role::TEXT IN ('operario_maquinaria', 'peon_logistica')
      ELSE FALSE
    END
  ORDER BY up.role::TEXT, up.full_name;
END $$;

-- 3. Otorgar permisos para la función
GRANT EXECUTE ON FUNCTION get_available_workers_for_assignment() TO authenticated;

-- 4. Crear función alternativa más simple para casos de emergencia
CREATE OR REPLACE FUNCTION get_workers_simple()
RETURNS TABLE (
  id UUID,
  full_name TEXT,
  role TEXT,
  email TEXT
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Función simple que retorna todos los trabajadores disponibles
  RETURN QUERY
  SELECT 
    up.id,
    up.full_name,
    up.role::TEXT,
    up.email
  FROM user_profiles up
  WHERE up.role::TEXT IN ('operario_maquinaria', 'peon_logistica', 'transportista')
  ORDER BY up.role::TEXT, up.full_name;
END $$;

-- 5. Otorgar permisos para la función simple
GRANT EXECUTE ON FUNCTION get_workers_simple() TO authenticated;

-- 6. Verificar que la función funciona correctamente
SELECT 'Probando función corregida:' as test;

-- Probar la función principal
SELECT * FROM get_available_workers_for_assignment() LIMIT 5;

-- Probar la función simple como fallback
SELECT 'Función simple (fallback):' as test;
SELECT * FROM get_workers_simple() LIMIT 5;

-- 7. Verificar tipos de datos en la tabla user_profiles
SELECT 
    column_name, 
    data_type, 
    udt_name
FROM information_schema.columns 
WHERE table_name = 'user_profiles' 
AND column_name IN ('role', 'full_name', 'email', 'id');

-- 8. Mostrar usuarios disponibles por rol
SELECT 
    role::TEXT as rol,
    COUNT(*) as cantidad,
    STRING_AGG(full_name, ', ') as nombres
FROM user_profiles 
WHERE role::TEXT IN ('oficial_almacen', 'transportista', 'operario_maquinaria', 'peon_logistica', 'encargado_obra')
GROUP BY role::TEXT
ORDER BY role::TEXT;
