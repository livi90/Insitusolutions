-- Actualizar políticas para que los encargados de obra vean entregas destinadas a sus obras

-- Eliminar política existente de entregas
DROP POLICY IF EXISTS "Users can view relevant deliveries" ON public.deliveries;

-- Crear nueva política más permisiva para entregas
CREATE POLICY "Enhanced delivery visibility" ON public.deliveries
  FOR SELECT USING (
    -- El creador puede ver sus entregas
    created_by = auth.uid() OR
    -- El asignado puede ver sus entregas
    assigned_to = auth.uid() OR
    -- Oficial de almacén puede ver todas
    EXISTS (
      SELECT 1 FROM public.user_profiles 
      WHERE id = auth.uid() AND role = 'oficial_almacen'
    ) OR
    -- Encargado de obra puede ver entregas destinadas a sus obras
    (
      EXISTS (
        SELECT 1 FROM public.user_profiles 
        WHERE id = auth.uid() AND role = 'encargado_obra'
      ) AND
      work_site_id IN (
        SELECT id FROM public.work_sites 
        WHERE site_manager_id = auth.uid()
      )
    )
  );

-- Actualizar política de notificaciones para incluir notificaciones relacionadas con obras
DROP POLICY IF EXISTS "Users can view own notifications" ON public.notifications;

CREATE POLICY "Enhanced notification visibility" ON public.notifications
  FOR SELECT USING (
    -- Notificaciones directas del usuario
    user_id = auth.uid() OR
    -- Notificaciones sobre entregas a obras del encargado
    (
      EXISTS (
        SELECT 1 FROM public.user_profiles 
        WHERE id = auth.uid() AND role = 'encargado_obra'
      ) AND
      delivery_id IN (
        SELECT id FROM public.deliveries 
        WHERE work_site_id IN (
          SELECT id FROM public.work_sites 
          WHERE site_manager_id = auth.uid()
        )
      )
    )
  );

-- Función mejorada para crear notificaciones que incluya al encargado de obra
CREATE OR REPLACE FUNCTION create_notification_enhanced(
  p_title TEXT,
  p_message TEXT,
  p_type TEXT,
  p_user_id UUID,
  p_delivery_id UUID DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  notification_id UUID;
  obra_manager_id UUID;
BEGIN
  -- Crear notificación principal
  INSERT INTO public.notifications (title, message, type, user_id, delivery_id)
  VALUES (p_title, p_message, p_type, p_user_id, p_delivery_id)
  RETURNING id INTO notification_id;
  
  -- Si hay una entrega asociada, notificar también al encargado de obra
  IF p_delivery_id IS NOT NULL THEN
    SELECT ws.site_manager_id INTO obra_manager_id
    FROM public.deliveries d
    JOIN public.work_sites ws ON d.work_site_id = ws.id
    WHERE d.id = p_delivery_id AND ws.site_manager_id != p_user_id;
    
    -- Crear notificación adicional para el encargado de obra si existe y es diferente
    IF obra_manager_id IS NOT NULL THEN
      INSERT INTO public.notifications (title, message, type, user_id, delivery_id)
      VALUES (
        p_title || ' (Para tu obra)',
        p_message,
        p_type || '_obra',
        obra_manager_id,
        p_delivery_id
      );
    END IF;
  END IF;
  
  RETURN notification_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Actualizar trigger para usar la nueva función
DROP TRIGGER IF EXISTS delivery_status_change_trigger ON public.deliveries;

CREATE OR REPLACE FUNCTION handle_delivery_status_change_enhanced()
RETURNS TRIGGER AS $$
BEGIN
  -- Notify when delivery is assigned
  IF OLD.status = 'pending' AND NEW.status = 'assigned' THEN
    PERFORM create_notification_enhanced(
      'Entrega Asignada',
      'Te han asignado una nueva entrega: ' || NEW.title,
      'delivery_assigned',
      NEW.assigned_to,
      NEW.id
    );
  END IF;
  
  -- Notify when delivery is in transit
  IF OLD.status = 'assigned' AND NEW.status = 'in_transit' THEN
    PERFORM create_notification_enhanced(
      'Entrega en Camino',
      'La entrega está en camino: ' || NEW.title,
      'delivery_in_transit',
      NEW.created_by,
      NEW.id
    );
  END IF;
  
  -- Notify when delivery is completed
  IF OLD.status = 'in_transit' AND NEW.status = 'delivered' THEN
    PERFORM create_notification_enhanced(
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

-- Crear nuevo trigger
CREATE TRIGGER delivery_status_change_enhanced_trigger
  AFTER UPDATE ON public.deliveries
  FOR EACH ROW
  EXECUTE FUNCTION handle_delivery_status_change_enhanced();
