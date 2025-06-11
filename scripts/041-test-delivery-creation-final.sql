-- Prueba final para verificar que la creación de entregas funciona

DO $$
DECLARE
  admin_id UUID;
  delivery_id UUID;
  assignments_count INTEGER;
BEGIN
  RAISE NOTICE '=== PRUEBA FINAL DE CREACIÓN DE ENTREGA ===';
  
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
      'Prueba Final Completa',
      'Entrega para verificar que todo funciona sin assignment_type',
      'Avenida Principal 789, Ciudad',
      'pending',
      admin_id,
      NOW(),
      NOW()
    ) RETURNING id INTO delivery_id;
    
    RAISE NOTICE '✅ Entrega creada exitosamente: %', delivery_id;
    
    -- Verificar asignaciones creadas
    SELECT COUNT(*) INTO assignments_count
    FROM public.work_assignments 
    WHERE delivery_id = delivery_id;
    
    RAISE NOTICE '✅ Asignaciones automáticas creadas: %', assignments_count;
    
    IF assignments_count > 0 THEN
      RAISE NOTICE '🎉 ÉXITO TOTAL: La creación de entregas funciona perfectamente';
    ELSE
      RAISE NOTICE '⚠️  Entrega creada pero sin asignaciones automáticas';
    END IF;
    
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '❌ ERROR EN LA PRUEBA: %', SQLERRM;
    RAISE NOTICE '   Código de error: %', SQLSTATE;
  END;
END $$;
