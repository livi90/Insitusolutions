-- Restaurar a la versión que funcionaba correctamente
-- Eliminar todas las políticas problemáticas y restaurar las originales

-- ===== RESTAURAR POLÍTICAS DE USER_PROFILES =====
DROP POLICY IF EXISTS "Allow read access to user profiles" ON public.user_profiles;
DROP POLICY IF EXISTS "Allow users to update own profile" ON public.user_profiles;
DROP POLICY IF EXISTS "Allow insert for new users" ON public.user_profiles;
DROP POLICY IF EXISTS "View user profiles" ON public.user_profiles;
DROP POLICY IF EXISTS "Update own profile" ON public.user_profiles;

-- Políticas originales que funcionaban
CREATE POLICY "Users can view own profile" ON public.user_profiles
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON public.user_profiles
  FOR UPDATE USING (auth.uid() = id);

-- ===== RESTAURAR POLÍTICAS DE WORK_SITES =====
DROP POLICY IF EXISTS "Allow read work sites" ON public.work_sites;
DROP POLICY IF EXISTS "Allow manage work sites" ON public.work_sites;

CREATE POLICY "Site managers can manage their sites" ON public.work_sites
  FOR ALL USING (
    site_manager_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM public.user_profiles 
      WHERE id = auth.uid() AND role = 'oficial_almacen'
    )
  );

-- ===== RESTAURAR POLÍTICAS DE DELIVERIES =====
DROP POLICY IF EXISTS "Allow read deliveries" ON public.deliveries;
DROP POLICY IF EXISTS "Enhanced delivery visibility" ON public.deliveries;

CREATE POLICY "Users can view relevant deliveries" ON public.deliveries
  FOR SELECT USING (
    created_by = auth.uid() OR
    assigned_to = auth.uid() OR
    EXISTS (
      SELECT 1 FROM public.user_profiles 
      WHERE id = auth.uid() AND (role = 'oficial_almacen' OR role = 'encargado_obra')
    )
  );

CREATE POLICY "Warehouse officials can manage deliveries" ON public.deliveries
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.user_profiles 
      WHERE id = auth.uid() AND role = 'oficial_almacen'
    )
  );

-- ===== RESTAURAR POLÍTICAS DE NOTIFICATIONS =====
DROP POLICY IF EXISTS "Allow read notifications" ON public.notifications;
DROP POLICY IF EXISTS "Allow update notifications" ON public.notifications;

CREATE POLICY "Users can view own notifications" ON public.notifications
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "Users can update own notifications" ON public.notifications
  FOR UPDATE USING (user_id = auth.uid());

-- ===== RESTAURAR POLÍTICAS DE WAREHOUSE_REQUESTS =====
DROP POLICY IF EXISTS "Allow read warehouse requests" ON public.warehouse_requests;
DROP POLICY IF EXISTS "Allow create warehouse requests" ON public.warehouse_requests;

CREATE POLICY "Site managers can create requests" ON public.warehouse_requests
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.user_profiles 
      WHERE id = auth.uid() AND role = 'encargado_obra'
    )
  );

CREATE POLICY "Users can view relevant requests" ON public.warehouse_requests
  FOR SELECT USING (
    requested_by = auth.uid() OR
    EXISTS (
      SELECT 1 FROM public.user_profiles 
      WHERE id = auth.uid() AND role = 'oficial_almacen'
    )
  );

-- ===== ELIMINAR TABLA WORK_ASSIGNMENTS Y SUS POLÍTICAS =====
-- Esta tabla causaba problemas, la eliminamos completamente
DROP TABLE IF EXISTS public.work_assignments CASCADE;

-- ===== RESTAURAR FUNCIONES ORIGINALES =====
-- Restaurar función original de notificaciones
CREATE OR REPLACE FUNCTION create_notification(
  p_title TEXT,
  p_message TEXT,
  p_type TEXT,
  p_user_id UUID,
  p_delivery_id UUID DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  notification_id UUID;
BEGIN
  INSERT INTO public.notifications (title, message, type, user_id, delivery_id)
  VALUES (p_title, p_message, p_type, p_user_id, p_delivery_id)
  RETURNING id INTO notification_id;
  
  RETURN notification_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Restaurar función original de cambio de estado de entregas
CREATE OR REPLACE FUNCTION handle_delivery_status_change()
RETURNS TRIGGER AS $$
BEGIN
  -- Notify when delivery is assigned
  IF OLD.status = 'pending' AND NEW.status = 'assigned' THEN
    PERFORM create_notification(
      'Entrega Asignada',
      'Te han asignado una nueva entrega: ' || NEW.title,
      'delivery_assigned',
      NEW.assigned_to,
      NEW.id
    );
  END IF;
  
  -- Notify when delivery is in transit
  IF OLD.status = 'assigned' AND NEW.status = 'in_transit' THEN
    PERFORM create_notification(
      'Entrega en Camino',
      'La entrega está en camino: ' || NEW.title,
      'delivery_in_transit',
      NEW.created_by,
      NEW.id
    );
  END IF;
  
  -- Notify when delivery is completed
  IF OLD.status = 'in_transit' AND NEW.status = 'delivered' THEN
    PERFORM create_notification(
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

-- Eliminar triggers problemáticos y restaurar el original
DROP TRIGGER IF EXISTS delivery_status_change_enhanced_trigger ON public.deliveries;
DROP TRIGGER IF EXISTS delivery_status_change_trigger ON public.deliveries;

CREATE TRIGGER delivery_status_change_trigger
  AFTER UPDATE ON public.deliveries
  FOR EACH ROW
  EXECUTE FUNCTION handle_delivery_status_change();
