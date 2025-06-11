-- Script de prueba para verificar que la creación de entregas funciona

DO $$
DECLARE
  admin_id UUID;
  new_delivery_id UUID;
  delivery_count INTEGER;
  rec RECORD;
BEGIN
  RAISE NOTICE '=== PRUEBA DE CREACIÓN DE ENTREGAS ===';
  
  -- Obtener ID del admin
  SELECT id INTO admin_id FROM public.user_profiles WHERE email = 'admin@logistica.com' LIMIT 1;
  
  IF admin_id IS NULL THEN
    RAISE NOTICE 'No se encontró usuario admin, usando usuario de prueba';
    admin_id := '99999999-9999-9999-9999-999999999999';
  END IF;
  
  RAISE NOTICE 'Usando usuario ID: %', admin_id;
  
  -- Contar entregas antes
  SELECT COUNT(*) INTO delivery_count FROM public.deliveries;
  RAISE NOTICE 'Entregas antes de la prueba: %', delivery_count;
  
  -- Crear entrega de prueba
  INSERT INTO public.deliveries (
    title,
    description,
    delivery_address,
    status,
    created_by,
    created_at,
    updated_at
  ) VALUES (
    'Entrega de Prueba Final',
    'Entrega creada para verificar que todo funciona correctamente',
    'Calle de Prueba 456, Ciudad de Prueba',
    'pending',
    admin_id,
    NOW(),
    NOW()
  ) RETURNING id INTO new_delivery_id;
  
  RAISE NOTICE 'Nueva entrega creada con ID: %', new_delivery_id;
  
  -- Contar entregas después
  SELECT COUNT(*) INTO delivery_count FROM public.deliveries;
  RAISE NOTICE 'Entregas después de la prueba: %', delivery_count;
  
  -- Verificar que se puede leer la entrega
  IF EXISTS (
    SELECT 1 FROM public.deliveries 
    WHERE id = new_delivery_id 
    AND title = 'Entrega de Prueba Final'
  ) THEN
    RAISE NOTICE 'SUCCESS: La entrega se creó y se puede leer correctamente';
  ELSE
    RAISE NOTICE 'ERROR: La entrega no se puede leer después de crearla';
  END IF;
  
  -- Mostrar todas las entregas actuales
  RAISE NOTICE 'Entregas actuales en el sistema:';
  FOR rec IN 
    SELECT id, title, status, created_by, created_at
    FROM public.deliveries 
    ORDER BY created_at DESC 
    LIMIT 10
  LOOP
    RAISE NOTICE '- %: % (%) - Creado por: % el %', 
      rec.id, rec.title, rec.status, rec.created_by, rec.created_at;
  END LOOP;
  
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'ERROR en la prueba: %', SQLERRM;
END $$;
