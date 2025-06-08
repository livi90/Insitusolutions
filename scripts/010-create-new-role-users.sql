-- =====================================================
-- CREAR USUARIOS PARA LOS NUEVOS ROLES
-- =====================================================

CREATE OR REPLACE FUNCTION create_new_role_users()
RETURNS void AS $$
DECLARE
  operario1_id UUID;
  operario2_id UUID;
  peon1_id UUID;
  peon2_id UUID;
BEGIN
  -- Crear operario de maquinaria 1
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
    'operario1@logistica.com',
    crypt('maq123', gen_salt('bf')),
    now(),
    now(),
    now(),
    '{"provider":"email","providers":["email"]}',
    '{"full_name":"Roberto Operario Grúa","role":"operario_maquinaria","permission_level":"normal"}',
    now(),
    now(),
    '',
    '',
    '',
    ''
  ) RETURNING id INTO operario1_id;

  -- Crear operario de maquinaria 2
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
    'operario2@logistica.com',
    crypt('maq123', gen_salt('bf')),
    now(),
    now(),
    now(),
    '{"provider":"email","providers":["email"]}',
    '{"full_name":"Miguel Operario Excavadora","role":"operario_maquinaria","permission_level":"normal"}',
    now(),
    now(),
    '',
    '',
    '',
    ''
  ) RETURNING id INTO operario2_id;

  -- Crear peón de logística 1
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
    'peon1@logistica.com',
    crypt('log123', gen_salt('bf')),
    now(),
    now(),
    now(),
    '{"provider":"email","providers":["email"]}',
    '{"full_name":"Pedro Peón Logística","role":"peon_logistica","permission_level":"normal"}',
    now(),
    now(),
    '',
    '',
    '',
    ''
  ) RETURNING id INTO peon1_id;

  -- Crear peón de logística 2
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
    'peon2@logistica.com',
    crypt('log123', gen_salt('bf')),
    now(),
    now(),
    now(),
    '{"provider":"email","providers":["email"]}',
    '{"full_name":"Sandra Peón Señalización","role":"peon_logistica","permission_level":"normal"}',
    now(),
    now(),
    '',
    '',
    '',
    ''
  ) RETURNING id INTO peon2_id;

  -- Crear perfiles de usuario
  INSERT INTO public.user_profiles (id, email, full_name, role, permission_level) VALUES
  (operario1_id, 'operario1@logistica.com', 'Roberto Operario Grúa', 'operario_maquinaria', 'normal'),
  (operario2_id, 'operario2@logistica.com', 'Miguel Operario Excavadora', 'operario_maquinaria', 'normal'),
  (peon1_id, 'peon1@logistica.com', 'Pedro Peón Logística', 'peon_logistica', 'normal'),
  (peon2_id, 'peon2@logistica.com', 'Sandra Peón Señalización', 'peon_logistica', 'normal')
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    full_name = EXCLUDED.full_name,
    role = EXCLUDED.role,
    permission_level = EXCLUDED.permission_level;

  -- Crear algunas asignaciones de trabajo de ejemplo
  INSERT INTO public.work_assignments (
    title,
    description,
    assigned_to,
    assignment_type,
    priority,
    status,
    equipment_needed,
    special_instructions,
    safety_requirements,
    created_by
  ) VALUES
  (
    'Operación de Grúa - Descarga Materiales',
    'Operar grúa torre para descarga de materiales pesados en obra Plaza Norte',
    operario1_id,
    'machinery',
    'high',
    'pending',
    'Grúa torre Liebherr, eslingas certificadas',
    'Coordinar con transportista para posicionamiento óptimo',
    'Uso obligatorio de casco, arnés y chaleco reflectivo',
    (SELECT id FROM public.user_profiles WHERE role = 'oficial_almacen' LIMIT 1)
  ),
  (
    'Apoyo Logístico - Señalización Zona Descarga',
    'Establecer señalización y coordinar tráfico durante descarga en Los Pinos',
    peon1_id,
    'logistics',
    'normal',
    'pending',
    'Conos, señales, radio comunicación',
    'Mantener zona despejada y comunicación constante con operarios',
    'Chaleco reflectivo, casco, radio en frecuencia asignada',
    (SELECT id FROM public.user_profiles WHERE role = 'oficial_almacen' LIMIT 1)
  );

  RAISE NOTICE 'Usuarios de nuevos roles creados exitosamente:';
  RAISE NOTICE 'Operario 1: operario1@logistica.com / maq123';
  RAISE NOTICE 'Operario 2: operario2@logistica.com / maq123';
  RAISE NOTICE 'Peón 1: peon1@logistica.com / log123';
  RAISE NOTICE 'Peón 2: peon2@logistica.com / log123';

END;
$$ LANGUAGE plpgsql;

-- Ejecutar la función
SELECT create_new_role_users();
