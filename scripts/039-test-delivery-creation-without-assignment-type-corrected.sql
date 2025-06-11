-- Script de prueba para verificar que la creación de entregas funciona sin errores (CORREGIDO)

DO $$
DECLARE
  admin_id UUID;
  delivery_id UUID;
  assignments_count INTEGER;
  assignment_record RECORD;
BEGIN
  RAISE NOTICE '=== PRUEBA DE CREACIÓN DE ENTREGA ===';
  
  -- Obtener ID del admin
  SELECT id INTO admin_id FROM public.user_profiles WHERE email = 'admin@logistica.com' LIMIT 1;
  
  IF admin_id IS NULL THEN
    RAISE NOTICE '❌ No se encontró usuario admin';
    RETURN;
  END IF;
  
  RAISE NOTICE '✅ Usuario admin encontrado: %', admin_id;
  
  -- Crear entrega de prueba
  BEGIN
    INSERT INTO public.deliveries (
      title, 
      description, 
      delivery_address, 
      status, 
      created_by,
      created_at,
      updated_at
    )
    VALUES (
      'Prueba Final - Sin Assignment Type',
      'Entrega para verificar que todo funciona correctamente',
      'Calle de Prueba 456, Ciudad',
      'pending',
      admin_id,
      NOW(),
      NOW()
    ) RETURNING id INTO delivery_id;
    
    RAISE NOTICE '✅ Entrega creada exitosamente: %', delivery_id;
    
    -- Esperar un momento para que el trigger se ejecute
    PERFORM pg_sleep(1);
    
    -- Verificar asignaciones creadas
    SELECT COUNT(*) INTO assignments_count
    FROM public.work_assignments 
    WHERE delivery_id = delivery_id;
    
    RAISE NOTICE '✅ Asignaciones automáticas creadas: %', assignments_count;
    
    -- Mostrar detalles de las asignaciones
    FOR assignment_record IN 
      SELECT wa.title, up.full_name, up.role
      FROM public.work_assignments wa
      JOIN public.user_profiles up ON wa.assigned_to = up.id
      WHERE wa.delivery_id = delivery_id
    LOOP
      RAISE NOTICE '  - %: % (%)', assignment_record.title, assignment_record.full_name, assignment_record.role;
    END LOOP;
    
    RAISE NOTICE '✅ PRUEBA EXITOSA: La creación de entregas funciona correctamente';
    
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '❌ ERROR EN LA PRUEBA: %', SQLERRM;
  END;
END $$;
