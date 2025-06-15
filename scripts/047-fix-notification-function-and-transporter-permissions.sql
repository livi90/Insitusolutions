-- Solucionar problemas con notificaciones y permisos de transportistas

-- 1. Eliminar funciones de notificación conflictivas
DROP FUNCTION IF EXISTS create_notification(TEXT, TEXT, TEXT, UUID, UUID);
DROP FUNCTION IF EXISTS create_notification(TEXT, TEXT, TEXT, UUID);
DROP FUNCTION IF EXISTS create_notification(p_title TEXT, p_message TEXT, p_type TEXT, p_user_id UUID, p_delivery_id UUID);

-- 2. Crear función de notificación limpia y específica
CREATE OR REPLACE FUNCTION create_delivery_notification(
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
END $$;

-- 3. Otorgar permisos para la función de notificación
GRANT EXECUTE ON FUNCTION create_delivery_notification(TEXT, TEXT, TEXT, UUID, UUID) TO authenticated;

-- 4. Actualizar función de asignación de transportista para usar la nueva función
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
  
  -- Crear notificación usando la nueva función
  SELECT create_delivery_notification(
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

-- 5. Crear función para que transportistas puedan actualizar estado de entregas
CREATE OR REPLACE FUNCTION update_delivery_status_by_transporter(
  p_delivery_id UUID,
  p_new_status TEXT
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  current_user_id UUID;
  current_user_role TEXT;
  delivery_assigned_to UUID;
  delivery_title TEXT;
  creator_id UUID;
  valid_statuses TEXT[] := ARRAY['in_transit', 'delivered'];
BEGIN
  -- Obtener información del usuario actual
  current_user_id := auth.uid();
  
  SELECT up.role::TEXT INTO current_user_role 
  FROM user_profiles up 
  WHERE up.id = current_user_id;
  
  IF current_user_role IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Usuario no encontrado');
  END IF;
  
  IF current_user_role != 'transportista' THEN
    RETURN json_build_object('success', false, 'error', 'Solo los transportistas pueden actualizar el estado de sus entregas');
  END IF;
  
  -- Verificar que el estado es válido
  IF NOT (p_new_status = ANY(valid_statuses)) THEN
    RETURN json_build_object('success', false, 'error', 'Estado no válido para transportista');
  END IF;
  
  -- Verificar que la entrega existe y está asignada al transportista
  SELECT assigned_to, title, created_by
  INTO delivery_assigned_to, delivery_title, creator_id
  FROM deliveries 
  WHERE id = p_delivery_id;
  
  IF delivery_assigned_to IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Entrega no encontrada');
  END IF;
  
  IF delivery_assigned_to != current_user_id THEN
    RETURN json_build_object('success', false, 'error', 'Esta entrega no está asignada a ti');
  END IF;
  
  -- Actualizar el estado de la entrega
  UPDATE deliveries 
  SET 
    status = p_new_status,
    updated_at = NOW()
  WHERE id = p_delivery_id;
  
  -- Crear notificación para el creador de la entrega
  IF creator_id IS NOT NULL THEN
    PERFORM create_delivery_notification(
      CASE 
        WHEN p_new_status = 'in_transit' THEN 'Entrega en tránsito'
        WHEN p_new_status = 'delivered' THEN 'Entrega completada'
        ELSE 'Estado de entrega actualizado'
      END,
      CASE 
        WHEN p_new_status = 'in_transit' THEN 'La entrega "' || COALESCE(delivery_title, 'Sin título') || '" está en camino'
        WHEN p_new_status = 'delivered' THEN 'La entrega "' || COALESCE(delivery_title, 'Sin título') || '" ha sido entregada'
        ELSE 'El estado de la entrega ha sido actualizado'
      END,
      CASE 
        WHEN p_new_status = 'in_transit' THEN 'delivery_in_transit'
        WHEN p_new_status = 'delivered' THEN 'delivery_completed'
        ELSE 'delivery_updated'
      END,
      creator_id,
      p_delivery_id
    );
  END IF;
  
  RETURN json_build_object(
    'success', true, 
    'message', 'Estado actualizado exitosamente',
    'new_status', p_new_status
  );
  
EXCEPTION
  WHEN OTHERS THEN
    RETURN json_build_object('success', false, 'error', SQLERRM);
END $$;

-- 6. Otorgar permisos para la función de actualización de estado
GRANT EXECUTE ON FUNCTION update_delivery_status_by_transporter(UUID, TEXT) TO authenticated;

-- 7. Actualizar políticas para permitir que transportistas actualicen sus entregas
-- Primero eliminar política existente si existe
DROP POLICY IF EXISTS "Transportistas can update their assigned deliveries" ON deliveries;

-- Crear nueva política para transportistas
CREATE POLICY "Transportistas can update their assigned deliveries" ON deliveries
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM user_profiles up 
    WHERE up.id = auth.uid() 
    AND up.role::TEXT = 'transportista'
    AND deliveries.assigned_to = auth.uid()
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM user_profiles up 
    WHERE up.id = auth.uid() 
    AND up.role::TEXT = 'transportista'
    AND deliveries.assigned_to = auth.uid()
  )
);

-- 8. Verificar que las funciones se crearon correctamente
SELECT 'Funciones creadas correctamente:' as info;
SELECT routine_name, routine_type 
FROM information_schema.routines 
WHERE routine_name IN (
  'create_delivery_notification', 
  'assign_transporter_to_delivery', 
  'update_delivery_status_by_transporter'
)
AND routine_schema = 'public';

-- 9. Mostrar políticas activas para deliveries
SELECT 'Políticas activas para deliveries:' as info;
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual 
FROM pg_policies 
WHERE tablename = 'deliveries' 
ORDER BY policyname;
