-- =====================================================
-- DATOS DE PRUEBA PARA EL SISTEMA
-- =====================================================

-- Nota: Este script debe ejecutarse DESPUÉS de crear algunos usuarios
-- a través de la aplicación, ya que necesitamos IDs reales de auth.users

-- =====================================================
-- FUNCIÓN PARA CREAR DATOS DE PRUEBA
-- =====================================================

CREATE OR REPLACE FUNCTION create_sample_data()
RETURNS void AS $$
DECLARE
  admin_id UUID;
  transporter1_id UUID;
  transporter2_id UUID;
  site_manager1_id UUID;
  site_manager2_id UUID;
  work_site1_id UUID;
  work_site2_id UUID;
  delivery1_id UUID;
  delivery2_id UUID;
BEGIN
  -- Buscar usuarios existentes o crear IDs de ejemplo
  -- (En producción, estos serían usuarios reales creados a través de la app)
  
  -- Crear sitios de trabajo de ejemplo
  INSERT INTO public.work_sites (name, address, description) VALUES
  ('Construcción Centro Comercial Plaza Norte', 'Av. Principal 123, Lima', 'Proyecto de construcción de centro comercial de 3 pisos')
  RETURNING id INTO work_site1_id;
  
  INSERT INTO public.work_sites (name, address, description) VALUES
  ('Edificio Residencial Los Pinos', 'Calle Los Pinos 456, San Isidro', 'Complejo residencial de 15 pisos con 120 departamentos')
  RETURNING id INTO work_site2_id;
  
  -- Crear equipos de ejemplo
  INSERT INTO public.equipment (name, description, serial_number, work_site_id, status) VALUES
  ('Excavadora CAT 320', 'Excavadora hidráulica para movimiento de tierra', 'CAT320-2023-001', work_site1_id, 'available'),
  ('Grúa Torre Liebherr', 'Grúa torre para construcción en altura', 'LIB-GT-2023-002', work_site2_id, 'in_use'),
  ('Mezcladora de Concreto', 'Mezcladora industrial para concreto', 'MIX-CON-2023-003', work_site1_id, 'available'),
  ('Compactadora Vibrante', 'Compactadora para asfalto y tierra', 'COMP-VIB-2023-004', work_site2_id, 'maintenance');
  
  -- Crear trabajadores de ejemplo
  INSERT INTO public.workers (full_name, position, phone, work_site_id, status) VALUES
  ('Carlos Mendoza', 'Operador de Excavadora', '+51 987654321', work_site1_id, 'active'),
  ('Ana García', 'Supervisora de Obra', '+51 987654322', work_site1_id, 'active'),
  ('Luis Rodríguez', 'Operador de Grúa', '+51 987654323', work_site2_id, 'active'),
  ('María Fernández', 'Ingeniera de Campo', '+51 987654324', work_site2_id, 'active'),
  ('José Pérez', 'Albañil Especializado', '+51 987654325', work_site1_id, 'active'),
  ('Carmen López', 'Electricista', '+51 987654326', work_site2_id, 'active');
  
  RAISE NOTICE 'Datos de prueba creados exitosamente';
  RAISE NOTICE 'Sitios de trabajo: %, %', work_site1_id, work_site2_id;
  
END;
$$ LANGUAGE plpgsql;

-- Ejecutar la función para crear datos de prueba
SELECT create_sample_data();

-- =====================================================
-- DATOS ADICIONALES DE CONFIGURACIÓN
-- =====================================================

-- Crear algunos tipos de notificación estándar
INSERT INTO public.notifications (title, message, type, user_id, read) VALUES
('Sistema Inicializado', 'El sistema de gestión logística ha sido configurado correctamente', 'system', '00000000-0000-0000-0000-000000000000', true);

-- Crear configuraciones del sistema (si necesitas una tabla de configuración)
-- CREATE TABLE IF NOT EXISTS public.system_config (
--   key TEXT PRIMARY KEY,
--   value TEXT NOT NULL,
--   description TEXT,
--   updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
-- );

-- INSERT INTO public.system_config (key, value, description) VALUES
-- ('max_delivery_distance', '100', 'Distancia máxima de entrega en kilómetros'),
-- ('notification_retention_days', '30', 'Días que se mantienen las notificaciones'),
-- ('auto_assign_deliveries', 'false', 'Asignación automática de entregas');
