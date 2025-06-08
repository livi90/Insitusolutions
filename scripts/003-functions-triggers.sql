-- =====================================================
-- FUNCIONES Y TRIGGERS DEL SISTEMA
-- =====================================================

-- =====================================================
-- FUNCIÓN PARA CREAR NOTIFICACIONES
-- =====================================================

CREATE OR REPLACE FUNCTION create_notification(
  p_title TEXT,
  p_message TEXT,
  p_type TEXT,
  p_user_id UUID,
  p_delivery_id UUID DEFAULT NULL,
  p_work_site_id UUID DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  notification_id UUID;
BEGIN
  INSERT INTO public.notifications (title, message, type, user_id, delivery_id, work_site_id)
  VALUES (p_title, p_message, p_type, p_user_id, p_delivery_id, p_work_site_id)
  RETURNING id INTO notification_id;
  
  RETURN notification_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- FUNCIÓN PARA MANEJAR CAMBIOS DE ESTADO EN ENTREGAS
-- =====================================================

CREATE OR REPLACE FUNCTION handle_delivery_status_change()
RETURNS TRIGGER AS $$
BEGIN
  -- Notificar cuando se asigna una entrega
  IF OLD.status = 'pending' AND NEW.status = 'assigned' AND NEW.assigned_to IS NOT NULL THEN
    PERFORM create_notification(
      'Entrega Asignada',
      'Te han asignado una nueva entrega: ' || NEW.title,
      'delivery_assigned',
      NEW.assigned_to,
      NEW.id
    );
  END IF;
  
  -- Notificar cuando la entrega está en tránsito
  IF OLD.status = 'assigned' AND NEW.status = 'in_transit' THEN
    PERFORM create_notification(
      'Entrega en Camino',
      'La entrega está en camino: ' || NEW.title,
      'delivery_in_transit',
      NEW.created_by,
      NEW.id
    );
    
    -- Actualizar timestamp de inicio
    NEW.started_at = NOW();
  END IF;
  
  -- Notificar cuando la entrega es completada
  IF OLD.status = 'in_transit' AND NEW.status = 'delivered' THEN
    PERFORM create_notification(
      'Entrega Realizada',
      'La entrega ha sido realizada: ' || NEW.title,
      'delivery_delivered',
      NEW.created_by,
      NEW.id
    );
  END IF;
  
  -- Notificar cuando la entrega es confirmada como completada
  IF OLD.status = 'delivered' AND NEW.status = 'completed' THEN
    PERFORM create_notification(
      'Entrega Completada',
      'La entrega ha sido confirmada como completada: ' || NEW.title,
      'delivery_completed',
      NEW.assigned_to,
      NEW.id
    );
    
    -- Actualizar timestamp de finalización
    NEW.completed_date = NOW();
  END IF;
  
  -- Actualizar timestamp de modificación
  NEW.updated_at = NOW();
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- FUNCIÓN PARA MANEJAR CAMBIOS EN SOLICITUDES DE ALMACÉN
-- =====================================================

CREATE OR REPLACE FUNCTION handle_warehouse_request_change()
RETURNS TRIGGER AS $$
BEGIN
  -- Notificar cuando se aprueba una solicitud
  IF OLD.status = 'pending' AND NEW.status = 'approved' THEN
    PERFORM create_notification(
      'Solicitud Aprobada',
      'Tu solicitud ha sido aprobada: ' || NEW.title,
      'request_approved',
      NEW.requested_by
    );
    
    NEW.approved_at = NOW();
    NEW.approved_by = auth.uid();
  END IF;
  
  -- Notificar cuando se rechaza una solicitud
  IF OLD.status = 'pending' AND NEW.status = 'rejected' THEN
    PERFORM create_notification(
      'Solicitud Rechazada',
      'Tu solicitud ha sido rechazada: ' || NEW.title,
      'request_rejected',
      NEW.requested_by
    );
  END IF;
  
  -- Notificar cuando se completa una solicitud
  IF OLD.status = 'approved' AND NEW.status = 'completed' THEN
    PERFORM create_notification(
      'Solicitud Completada',
      'Tu solicitud ha sido completada: ' || NEW.title,
      'request_completed',
      NEW.requested_by
    );
    
    NEW.completed_at = NOW();
  END IF;
  
  -- Actualizar timestamp de modificación
  NEW.updated_at = NOW();
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- FUNCIÓN PARA MANEJAR NUEVOS USUARIOS
-- =====================================================

CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.user_profiles (id, email, full_name, role, permission_level)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', 'Usuario'),
    COALESCE(NEW.raw_user_meta_data->>'role', 'transportista')::user_role,
    COALESCE(NEW.raw_user_meta_data->>'permission_level', 'normal')::permission_level
  );
  
  -- Crear notificación de bienvenida
  PERFORM create_notification(
    'Bienvenido al Sistema',
    'Tu cuenta ha sido creada exitosamente. ¡Bienvenido al sistema de gestión logística!',
    'welcome',
    NEW.id
  );
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- FUNCIÓN PARA ACTUALIZAR TIMESTAMPS
-- =====================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- CREAR TRIGGERS
-- =====================================================

-- Trigger para cambios de estado en entregas
CREATE TRIGGER delivery_status_change_trigger
  BEFORE UPDATE ON public.deliveries
  FOR EACH ROW
  EXECUTE FUNCTION handle_delivery_status_change();

-- Trigger para cambios en solicitudes de almacén
CREATE TRIGGER warehouse_request_change_trigger
  BEFORE UPDATE ON public.warehouse_requests
  FOR EACH ROW
  EXECUTE FUNCTION handle_warehouse_request_change();

-- Trigger para nuevos usuarios
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_user();

-- Triggers para actualizar timestamps automáticamente
CREATE TRIGGER update_user_profiles_updated_at
  BEFORE UPDATE ON public.user_profiles
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_work_sites_updated_at
  BEFORE UPDATE ON public.work_sites
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_equipment_updated_at
  BEFORE UPDATE ON public.equipment
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_workers_updated_at
  BEFORE UPDATE ON public.workers
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_maintenance_tasks_updated_at
  BEFORE UPDATE ON public.maintenance_tasks
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
