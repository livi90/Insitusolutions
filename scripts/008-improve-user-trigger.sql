-- =====================================================
-- MEJORAR EL TRIGGER DE CREACIÓN DE USUARIOS
-- =====================================================

-- Eliminar el trigger existente
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS handle_new_user();

-- Crear función mejorada para manejar nuevos usuarios
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  user_role user_role;
  user_permission permission_level;
BEGIN
  -- Obtener el rol del metadata, con valor por defecto
  user_role := COALESCE(NEW.raw_user_meta_data->>'role', 'transportista')::user_role;
  user_permission := COALESCE(NEW.raw_user_meta_data->>'permission_level', 'normal')::permission_level;

  -- Insertar perfil de usuario
  INSERT INTO public.user_profiles (
    id, 
    email, 
    full_name, 
    role, 
    permission_level,
    phone,
    avatar_url
  ) VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', 'Usuario'),
    user_role,
    user_permission,
    NEW.raw_user_meta_data->>'phone',
    NEW.raw_user_meta_data->>'avatar_url'
  )
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    full_name = EXCLUDED.full_name,
    role = EXCLUDED.role,
    permission_level = EXCLUDED.permission_level,
    phone = EXCLUDED.phone,
    avatar_url = EXCLUDED.avatar_url,
    updated_at = NOW();

  -- Crear notificación de bienvenida
  INSERT INTO public.notifications (
    title, 
    message, 
    type, 
    user_id, 
    read
  ) VALUES (
    'Bienvenido al Sistema',
    'Tu cuenta ha sido creada exitosamente. ¡Bienvenido al sistema de gestión logística!',
    'welcome',
    NEW.id,
    false
  );

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    -- Log del error pero no fallar la creación del usuario
    RAISE WARNING 'Error creating user profile for %: %', NEW.email, SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Crear el trigger mejorado
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_user();

-- Función para verificar y reparar perfiles faltantes
CREATE OR REPLACE FUNCTION repair_missing_profiles()
RETURNS void AS $$
DECLARE
  user_record RECORD;
BEGIN
  -- Buscar usuarios sin perfil
  FOR user_record IN 
    SELECT u.id, u.email, u.raw_user_meta_data
    FROM auth.users u
    LEFT JOIN public.user_profiles p ON u.id = p.id
    WHERE p.id IS NULL
  LOOP
    -- Crear perfil faltante
    INSERT INTO public.user_profiles (
      id, 
      email, 
      full_name, 
      role, 
      permission_level
    ) VALUES (
      user_record.id,
      user_record.email,
      COALESCE(user_record.raw_user_meta_data->>'full_name', 'Usuario'),
      COALESCE(user_record.raw_user_meta_data->>'role', 'transportista')::user_role,
      COALESCE(user_record.raw_user_meta_data->>'permission_level', 'normal')::permission_level
    );
    
    RAISE NOTICE 'Perfil creado para usuario: %', user_record.email;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Ejecutar reparación de perfiles faltantes
SELECT repair_missing_profiles();
