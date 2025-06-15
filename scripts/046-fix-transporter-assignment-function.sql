-- Recrear función de asignación de transportistas y simplificar el proceso

-- 1. Eliminar función anterior si existe
DROP FUNCTION IF EXISTS assign_transporter_to_delivery(UUID, UUID);
DROP FUNCTION IF EXISTS assign_transporter_to_delivery(delivery_id UUID, transporter_id UUID);

-- 2. Crear función corregida para asignar transportista
CREATE OR REPLACE FUNCTION assign_transporter_to_delivery(
  p_delivery_id UUID,
  p_transporter_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  current_user_role TEXT;
  transporter_role TEXT;
  delivery_exists BOOLEAN;
  transporter_exists BOOLEAN;
  result JSON;
BEGIN
  -- Verificar que el usuario actual sea oficial de almacén
  SELECT up.role::TEXT INTO current_user_role 
  FROM user_profiles up 
  WHERE up.id = auth.uid();
  
  IF current_user_role IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Usuario no encontrado');
  END IF;
  
  IF current_user_role != 'oficial_almacen' THEN
    RETURN json_build_object('success', false, 'error', 'Solo los oficiales de almacén pueden asignar transportistas');
  END IF;
  
  -- Verificar que la entrega existe
  SELECT EXISTS(SELECT 1 FROM deliveries WHERE id = p_delivery_id) INTO delivery_exists;
  IF NOT delivery_exists THEN
    RETURN json_build_object('success', false, 'error', 'Entrega no encontrada');
  END IF;
  
  -- Verificar que el transportista existe y tiene el rol correcto
  SELECT up.role::TEXT INTO transporter_role 
  FROM user_profiles up 
  WHERE up.id = p_transporter_id;
  
  IF transporter_role IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Transportista no encontrado');
  END IF;
  
  IF transporter_role != 'transportista' THEN
    RETURN json_build_object('success', false, 'error', 'El usuario seleccionado no es transportista');
  END IF;
  
  -- Actualizar la entrega
  UPDATE deliveries 
  SET 
    assigned_to = p_transporter_id,
    status = 'assigned',
    updated_at = NOW()
  WHERE id = p_delivery_id;
  
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
    p_transporter_id,
    p_delivery_id,
    false,
    NOW()
  );
  
  RETURN json_build_object('success', true, 'message', 'Transportista asignado exitosamente');
  
EXCEPTION
  WHEN OTHERS THEN
    RETURN json_build_object('success', false, 'error', SQLERRM);
END $$;

-- 3. Otorgar permisos para la función
GRANT EXECUTE ON FUNCTION assign_transporter_to_delivery(UUID, UUID) TO authenticated;

-- 4. Crear función simple para obtener transportistas disponibles
CREATE OR REPLACE FUNCTION get_available_transporters()
RETURNS TABLE (
  id UUID,
  full_name TEXT,
  email TEXT,
  role TEXT
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  current_user_role TEXT;
BEGIN
  -- Obtener el rol del usuario actual
  SELECT up.role::TEXT INTO current_user_role 
  FROM user_profiles up 
  WHERE up.id = auth.uid();
  
  -- Solo oficial de almacén puede ver transportistas
  IF current_user_role != 'oficial_almacen' THEN
    RETURN;
  END IF;
  
  -- Retornar transportistas disponibles
  RETURN QUERY
  SELECT 
    up.id,
    up.full_name,
    up.email,
    up.role::TEXT
  FROM user_profiles up
  WHERE up.role::TEXT = 'transportista'
  ORDER BY up.full_name;
END $$;

-- 5. Otorgar permisos para la función de transportistas
GRANT EXECUTE ON FUNCTION get_available_transporters() TO authenticated;

-- 6. Verificar que las funciones se crearon correctamente
SELECT 'Funciones creadas:' as info;
SELECT routine_name, routine_type 
FROM information_schema.routines 
WHERE routine_name IN ('assign_transporter_to_delivery', 'get_available_transporters')
AND routine_schema = 'public';

-- 7. Probar las funciones
SELECT 'Probando función get_available_transporters:' as test;
SELECT * FROM get_available_transporters();

-- 8. Mostrar transportistas existentes
SELECT 'Transportistas en la base de datos:' as info;
SELECT id, full_name, email, role::TEXT as role_text
FROM user_profiles 
WHERE role::TEXT = 'transportista'
ORDER BY full_name;
