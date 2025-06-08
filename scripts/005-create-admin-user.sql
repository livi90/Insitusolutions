-- =====================================================
-- CREAR USUARIO ADMINISTRADOR INICIAL
-- =====================================================
-- Este script crea un usuario administrador inicial
-- Nota: Debes cambiar el email y contraseña antes de ejecutar

DO $$
DECLARE
  admin_id UUID;
  admin_email TEXT := 'admin@insitu.com'; -- CAMBIAR ESTO
  admin_password TEXT := 'password123';     -- CAMBIAR ESTO
BEGIN
  -- Verificar si el usuario ya existe
  SELECT id INTO admin_id FROM auth.users WHERE email = admin_email;
  
  IF admin_id IS NULL THEN
    -- Crear usuario en auth.users
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
      admin_email,
      crypt(admin_password, gen_salt('bf')),
      now(),
      now(),
      now(),
      '{"provider":"email","providers":["email"]}',
      '{"full_name":"Administrador del Sistema","role":"oficial_almacen","permission_level":"admin"}',
      now(),
      now(),
      '',
      '',
      '',
      ''
    ) RETURNING id INTO admin_id;
    
    -- El trigger on_auth_user_created debería crear automáticamente el perfil
    -- pero podemos verificar y crearlo manualmente si es necesario
    IF NOT EXISTS (SELECT 1 FROM public.user_profiles WHERE id = admin_id) THEN
      INSERT INTO public.user_profiles (
        id, 
        email, 
        full_name, 
        role, 
        permission_level
      ) VALUES (
        admin_id,
        admin_email,
        'Administrador del Sistema',
        'oficial_almacen',
        'admin'
      );
    END IF;
    
    RAISE NOTICE 'Usuario administrador creado con ID: %', admin_id;
  ELSE
    RAISE NOTICE 'El usuario administrador ya existe con ID: %', admin_id;
  END IF;
END $$;
