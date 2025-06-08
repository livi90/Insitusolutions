-- =====================================================
-- VERIFICAR Y CORREGIR USUARIOS DE EJEMPLO
-- =====================================================

-- Función para verificar y crear usuarios faltantes
CREATE OR REPLACE FUNCTION verify_and_create_sample_users()
RETURNS void AS $$
DECLARE
  user_count INTEGER;
  operario_count INTEGER;
  peon_count INTEGER;
BEGIN
  -- Verificar cuántos usuarios tenemos
  SELECT COUNT(*) INTO user_count FROM public.user_profiles;
  
  -- Verificar operarios de maquinaria
  SELECT COUNT(*) INTO operario_count FROM public.user_profiles WHERE role = 'operario_maquinaria';
  
  -- Verificar peones de logística
  SELECT COUNT(*) INTO peon_count FROM public.user_profiles WHERE role = 'peon_logistica';
  
  RAISE NOTICE 'Total usuarios: %, Operarios: %, Peones: %', user_count, operario_count, peon_count;
  
  -- Si no hay operarios, crearlos
  IF operario_count = 0 THEN
    RAISE NOTICE 'Creando operarios de maquinaria...';
    
    -- Crear operario 1 directamente en user_profiles
    INSERT INTO public.user_profiles (
      id, 
      email, 
      full_name, 
      role, 
      permission_level
    ) VALUES (
      gen_random_uuid(),
      'operario1@logistica.com',
      'Roberto Operario Grúa',
      'operario_maquinaria',
      'normal'
    ) ON CONFLICT (email) DO NOTHING;
    
    -- Crear operario 2 directamente en user_profiles
    INSERT INTO public.user_profiles (
      id, 
      email, 
      full_name, 
      role, 
      permission_level
    ) VALUES (
      gen_random_uuid(),
      'operario2@logistica.com',
      'Miguel Operario Excavadora',
      'operario_maquinaria',
      'normal'
    ) ON CONFLICT (email) DO NOTHING;
  END IF;
  
  -- Si no hay peones, crearlos
  IF peon_count = 0 THEN
    RAISE NOTICE 'Creando peones de logística...';
    
    -- Crear peón 1 directamente en user_profiles
    INSERT INTO public.user_profiles (
      id, 
      email, 
      full_name, 
      role, 
      permission_level
    ) VALUES (
      gen_random_uuid(),
      'peon1@logistica.com',
      'Pedro Peón Logística',
      'peon_logistica',
      'normal'
    ) ON CONFLICT (email) DO NOTHING;
    
    -- Crear peón 2 directamente en user_profiles
    INSERT INTO public.user_profiles (
      id, 
      email, 
      full_name, 
      role, 
      permission_level
    ) VALUES (
      gen_random_uuid(),
      'peon2@logistica.com',
      'Sandra Peón Señalización',
      'peon_logistica',
      'normal'
    ) ON CONFLICT (email) DO NOTHING;
  END IF;
  
  -- Mostrar todos los usuarios actuales
  RAISE NOTICE 'Usuarios en el sistema:';
  FOR user_record IN 
    SELECT full_name, email, role FROM public.user_profiles ORDER BY role, full_name
  LOOP
    RAISE NOTICE '- %: % (%)', user_record.role, user_record.full_name, user_record.email;
  END LOOP;
  
END;
$$ LANGUAGE plpgsql;

-- Ejecutar la función
SELECT verify_and_create_sample_users();

-- Verificar que todos los roles estén representados
SELECT 
  role,
  COUNT(*) as cantidad,
  STRING_AGG(full_name, ', ') as usuarios
FROM public.user_profiles 
GROUP BY role 
ORDER BY role;
