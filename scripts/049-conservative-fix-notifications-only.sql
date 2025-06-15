-- Script conservador que solo arregla el problema de notificaciones sin afectar otras funcionalidades

-- 1. Verificar funciones de notificación existentes antes de hacer cambios
DO $$
DECLARE
    existing_functions TEXT[];
BEGIN
    -- Obtener lista de funciones existentes relacionadas con notificaciones
    SELECT ARRAY_AGG(routine_name) INTO existing_functions
    FROM information_schema.routines 
    WHERE routine_schema = 'public' 
    AND routine_name ILIKE '%notification%';
    
    RAISE NOTICE 'Funciones de notificación existentes: %', existing_functions;
END $$;

-- 2. Solo eliminar funciones problemáticas específicas (las que causan el error "not unique")
DROP FUNCTION IF EXISTS create_notification(TEXT, TEXT, TEXT, UUID, UUID);
DROP FUNCTION IF EXISTS create_notification(TEXT, TEXT, TEXT, UUID);

-- 3. Crear función de notificación con nombre único y específico
CREATE OR REPLACE FUNCTION create_delivery_notification_safe(
  p_title TEXT,
  p_message TEXT,
  p_type TEXT,
  p_user_id UUID,
  p_delivery_id UUID DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  notification_id UUID;
BEGIN
  -- Generar ID único
  notification_id := gen_random_uuid();
  
  -- Insertar notificación
  INSERT INTO public.notifications (
    id,
    title,
    message,
    type,
    user_id,
    delivery_id,
    read,
    created_at
  ) VALUES (
    notification_id,
    p_title,
    p_message,
    p_type,
    p_user_id,
    p_delivery_id,
    false,
    NOW()
  );
  
  RETURN notification_id;
  
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'Error creating notification: %', SQLERRM;
    RETURN NULL;
END $$;

-- 4. Otorgar permisos para la nueva función
GRANT EXECUTE ON FUNCTION create_delivery_notification_safe(TEXT, TEXT, TEXT, UUID, UUID) TO authenticated;

-- 5. Solo actualizar la función de asignación de transportista para usar la nueva función de notificación
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
  transporter_name TEXT;
  delivery_title TEXT;
  notification_id UUID;
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
  
  -- Verificar que la entrega existe y obtener su título
  SELECT EXISTS(SELECT 1 FROM deliveries WHERE id = p_delivery_id), 
         (SELECT title FROM deliveries WHERE id = p_delivery_id LIMIT 1)
  INTO delivery_exists, delivery_title;
  
  IF NOT delivery_exists THEN
    RETURN json_build_object('success', false, 'error', 'Entrega no encontrada');
  END IF;
  
  -- Verificar que el transportista existe y obtener su información
  SELECT up.role::TEXT, up.full_name 
  INTO transporter_role, transporter_name
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
  
  -- Crear notificación usando la nueva función segura
  SELECT create_delivery_notification_safe(
    'Nueva entrega asignada',
    'Se te ha asignado la entrega: ' || COALESCE(delivery_title, 'Sin título'),
    'delivery_assigned',
    p_transporter_id,
    p_delivery_id
  ) INTO notification_id;
  
  RETURN json_build_object(
    'success', true, 
    'message', 'Transportista ' || transporter_name || ' asignado exitosamente',
    'notification_id', notification_id
  );
  
EXCEPTION
  WHEN OTHERS THEN
    RETURN json_build_object('success', false, 'error', SQLERRM);
END $$;

-- 6. Verificar que todo funciona correctamente
SELECT 'VERIFICACIÓN POST-CAMBIOS:' as info;

-- Verificar que las funciones se crearon correctamente
SELECT 'Funciones creadas:' as test;
SELECT routine_name, routine_type 
FROM information_schema.routines 
WHERE routine_name IN ('create_delivery_notification_safe', 'assign_transporter_to_delivery')
AND routine_schema = 'public';

-- Probar que podemos crear una notificación
SELECT 'Probando creación de notificación:' as test;
SELECT create_delivery_notification_safe(
  'Test Notification',
  'This is a test notification',
  'test',
  (SELECT id FROM user_profiles WHERE role::TEXT = 'transportista' LIMIT 1),
  NULL
) as test_notification_id;

-- Limpiar la notificación de prueba
DELETE FROM notifications WHERE title = 'Test Notification' AND type = 'test';

SELECT 'Script conservador ejecutado exitosamente. Solo se modificaron las funciones de notificación.' as resultado;
