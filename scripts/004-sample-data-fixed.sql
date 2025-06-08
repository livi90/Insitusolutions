-- =====================================================
-- DATOS DE PRUEBA PARA EL SISTEMA (CORREGIDO)
-- =====================================================

-- =====================================================
-- FUNCIÓN PARA CREAR DATOS DE PRUEBA
-- =====================================================

CREATE OR REPLACE FUNCTION create_sample_data()
RETURNS void AS $$
DECLARE
  work_site1_id UUID;
  work_site2_id UUID;
  first_user_id UUID;
BEGIN
  -- Intentar obtener el ID de un usuario existente
  SELECT id INTO first_user_id FROM auth.users LIMIT 1;
  
  -- Crear sitios de trabajo de ejemplo
  INSERT INTO public.work_sites (name, address, description, site_manager_id) VALUES
  ('Construcción Centro Comercial Plaza Norte', 'Av. Principal 123, Lima', 'Proyecto de construcción de centro comercial de 3 pisos', first_user_id)
  RETURNING id INTO work_site1_id;
  
  INSERT INTO public.work_sites (name, address, description, site_manager_id) VALUES
  ('Edificio Residencial Los Pinos', 'Calle Los Pinos 456, San Isidro', 'Complejo residencial de 15 pisos con 120 departamentos', first_user_id)
  RETURNING id INTO work_site2_id;
  
  -- Crear equipos de ejemplo
  INSERT INTO public.equipment (name, description, serial_number, work_site_id, status) VALUES
  ('Excavadora CAT 320', 'Excavadora hidráulica para movimiento de tierra', 'CAT320-2023-001', work_site1_id, 'available'),
  ('Grúa Torre Liebherr', 'Grúa torre para construcción en altura', 'LIB-GT-2023-002', work_site2_id, 'in_use'),
  ('Mezcladora de Concreto', 'Mezcladora industrial para concreto', 'MIX-CON-2023-003', work_site1_id, 'available'),
  ('Compactadora Vibrante', 'Compactadora para asfalto y tierra', 'COMP-VIB-2023-004', work_site2_id, 'maintenance');
  
  -- Crear trabajadores de ejemplo
  INSERT INTO public.workers (full_name, position, phone, work_site_id, supervisor_id, status) VALUES
  ('Carlos Mendoza', 'Operador de Excavadora', '+51 987654321', work_site1_id, first_user_id, 'active'),
  ('Ana García', 'Supervisora de Obra', '+51 987654322', work_site1_id, first_user_id, 'active'),
  ('Luis Rodríguez', 'Operador de Grúa', '+51 987654323', work_site2_id, first_user_id, 'active'),
  ('María Fernández', 'Ingeniera de Campo', '+51 987654324', work_site2_id, first_user_id, 'active'),
  ('José Pérez', 'Albañil Especializado', '+51 987654325', work_site1_id, first_user_id, 'active'),
  ('Carmen López', 'Electricista', '+51 987654326', work_site2_id, first_user_id, 'active');
  
  -- Solo crear notificación si tenemos un usuario
  IF first_user_id IS NOT NULL THEN
    -- Crear notificación de sistema para el primer usuario
    INSERT INTO public.notifications (title, message, type, user_id, read)
    VALUES ('Sistema Inicializado', 'El sistema de gestión logística ha sido configurado correctamente', 'system', first_user_id, true);
  END IF;
  
  RAISE NOTICE 'Datos de prueba creados exitosamente';
  RAISE NOTICE 'Sitios de trabajo: %, %', work_site1_id, work_site2_id;
  
END;
$$ LANGUAGE plpgsql;

-- Ejecutar la función para crear datos de prueba
SELECT create_sample_data();
