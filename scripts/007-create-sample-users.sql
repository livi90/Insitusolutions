-- =====================================================
-- CREAR USUARIOS DE EJEMPLO PARA TODOS LOS ROLES
-- =====================================================

-- Función para crear usuarios de ejemplo
CREATE OR REPLACE FUNCTION create_sample_users()
RETURNS void AS $$
DECLARE
  admin_id UUID;
  transporter1_id UUID;
  transporter2_id UUID;
  site_manager1_id UUID;
  site_manager2_id UUID;
BEGIN
  -- Crear usuario administrador (Oficial de Almacén)
  INSERT INTO auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    recovery_sent_at,
    last_sign_in_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at,
    confirmation_token,
    email_change,
    email_change_token_new,
    recovery_token
  )
  VALUES (
    '00000000-0000-0000-0000-000000000000',
    gen_random_uuid(),
    'authenticated',
    'authenticated',
    'admin@logistica.com',
    crypt('admin123', gen_salt('bf')),
    now(),
    now(),
    now(),
    '{"provider":"email","providers":["email"]}',
    '{"full_name":"Administrador Sistema","role":"oficial_almacen","permission_level":"admin"}',
    now(),
    now(),
    '',
    '',
    '',
    ''
  ) RETURNING id INTO admin_id;

  -- Crear transportista 1
  INSERT INTO auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    recovery_sent_at,
    last_sign_in_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at,
    confirmation_token,
    email_change,
    email_change_token_new,
    recovery_token
  )
  VALUES (
    '00000000-0000-0000-0000-000000000000',
    gen_random_uuid(),
    'authenticated',
    'authenticated',
    'transportista1@logistica.com',
    crypt('trans123', gen_salt('bf')),
    now(),
    now(),
    now(),
    '{"provider":"email","providers":["email"]}',
    '{"full_name":"Carlos Transportista","role":"transportista","permission_level":"normal"}',
    now(),
    now(),
    '',
    '',
    '',
    ''
  ) RETURNING id INTO transporter1_id;

  -- Crear transportista 2
  INSERT INTO auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    recovery_sent_at,
    last_sign_in_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at,
    confirmation_token,
    email_change,
    email_change_token_new,
    recovery_token
  )
  VALUES (
    '00000000-0000-0000-0000-000000000000',
    gen_random_uuid(),
    'authenticated',
    'authenticated',
    'transportista2@logistica.com',
    crypt('trans123', gen_salt('bf')),
    now(),
    now(),
    now(),
    '{"provider":"email","providers":["email"]}',
    '{"full_name":"Ana Transportista","role":"transportista","permission_level":"normal"}',
    now(),
    now(),
    '',
    '',
    '',
    ''
  ) RETURNING id INTO transporter2_id;

  -- Crear encargado de obra 1
  INSERT INTO auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    recovery_sent_at,
    last_sign_in_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at,
    confirmation_token,
    email_change,
    email_change_token_new,
    recovery_token
  )
  VALUES (
    '00000000-0000-0000-0000-000000000000',
    gen_random_uuid(),
    'authenticated',
    'authenticated',
    'encargado1@logistica.com',
    crypt('obra123', gen_salt('bf')),
    now(),
    now(),
    now(),
    '{"provider":"email","providers":["email"]}',
    '{"full_name":"Luis Encargado Obra","role":"encargado_obra","permission_level":"normal"}',
    now(),
    now(),
    '',
    '',
    '',
    ''
  ) RETURNING id INTO site_manager1_id;

  -- Crear encargado de obra 2
  INSERT INTO auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    recovery_sent_at,
    last_sign_in_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at,
    confirmation_token,
    email_change,
    email_change_token_new,
    recovery_token
  )
  VALUES (
    '00000000-0000-0000-0000-000000000000',
    gen_random_uuid(),
    'authenticated',
    'authenticated',
    'encargado2@logistica.com',
    crypt('obra123', gen_salt('bf')),
    now(),
    now(),
    now(),
    '{"provider":"email","providers":["email"]}',
    '{"full_name":"María Encargada Obra","role":"encargado_obra","permission_level":"normal"}',
    now(),
    now(),
    '',
    '',
    '',
    ''
  ) RETURNING id INTO site_manager2_id;

  -- Crear perfiles de usuario manualmente (por si el trigger no funciona)
  INSERT INTO public.user_profiles (id, email, full_name, role, permission_level) VALUES
  (admin_id, 'admin@logistica.com', 'Administrador Sistema', 'oficial_almacen', 'admin'),
  (transporter1_id, 'transportista1@logistica.com', 'Carlos Transportista', 'transportista', 'normal'),
  (transporter2_id, 'transportista2@logistica.com', 'Ana Transportista', 'transportista', 'normal'),
  (site_manager1_id, 'encargado1@logistica.com', 'Luis Encargado Obra', 'encargado_obra', 'normal'),
  (site_manager2_id, 'encargado2@logistica.com', 'María Encargada Obra', 'encargado_obra', 'normal')
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    full_name = EXCLUDED.full_name,
    role = EXCLUDED.role,
    permission_level = EXCLUDED.permission_level;

  -- Crear sitios de trabajo para los encargados
  INSERT INTO public.work_sites (name, address, description, site_manager_id) VALUES
  ('Construcción Centro Comercial Plaza Norte', 'Av. Principal 123, Lima', 'Proyecto de construcción de centro comercial de 3 pisos', site_manager1_id),
  ('Edificio Residencial Los Pinos', 'Calle Los Pinos 456, San Isidro', 'Complejo residencial de 15 pisos con 120 departamentos', site_manager2_id),
  ('Obra Industrial Zona Este', 'Av. Industrial 789, Ate', 'Complejo industrial con almacenes y oficinas', site_manager1_id);

  -- Crear algunas entregas de ejemplo
  INSERT INTO public.deliveries (title, description, delivery_address, created_by, assigned_to, status) VALUES
  ('Entrega de Materiales - Plaza Norte', 'Cemento, varillas y agregados para construcción', 'Av. Principal 123, Lima', admin_id, transporter1_id, 'assigned'),
  ('Transporte de Equipos - Los Pinos', 'Herramientas eléctricas y maquinaria menor', 'Calle Los Pinos 456, San Isidro', admin_id, transporter2_id, 'pending'),
  ('Suministros de Oficina - Zona Este', 'Materiales de oficina y equipos de seguridad', 'Av. Industrial 789, Ate', admin_id, NULL, 'pending');

  -- Crear solicitudes de almacén de ejemplo
  INSERT INTO public.warehouse_requests (title, description, quantity, requested_by, status) VALUES
  ('Solicitud de Cemento', 'Necesitamos 50 sacos de cemento para la obra', 50, site_manager1_id, 'pending'),
  ('Herramientas Eléctricas', 'Taladros, sierras y extensiones eléctricas', 10, site_manager2_id, 'approved'),
  ('Materiales de Seguridad', 'Cascos, chalecos y señalización', 25, site_manager1_id, 'pending');

  RAISE NOTICE 'Usuarios de ejemplo creados exitosamente:';
  RAISE NOTICE 'Admin: admin@logistica.com / admin123';
  RAISE NOTICE 'Transportista 1: transportista1@logistica.com / trans123';
  RAISE NOTICE 'Transportista 2: transportista2@logistica.com / trans123';
  RAISE NOTICE 'Encargado 1: encargado1@logistica.com / obra123';
  RAISE NOTICE 'Encargado 2: encargado2@logistica.com / obra123';

END;
$$ LANGUAGE plpgsql;

-- Ejecutar la función
SELECT create_sample_users();
