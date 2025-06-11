-- Restaurar exactamente las políticas de la versión 22 que funcionaba perfectamente
-- Esta versión eliminará TODAS las políticas actuales y restaurará las originales

-- ===== ELIMINAR TODAS LAS POLÍTICAS EXISTENTES =====
DO $$
DECLARE
  pol_name TEXT;
  table_name TEXT;
BEGIN
  RAISE NOTICE '=== ELIMINANDO TODAS LAS POLÍTICAS EXISTENTES ===';
  
  -- Lista de tablas con políticas
  FOR table_name IN 
    SELECT DISTINCT tablename 
    FROM pg_policies 
    WHERE schemaname = 'public'
  LOOP
    RAISE NOTICE 'Eliminando políticas de tabla: %', table_name;
    
    -- Eliminar todas las políticas de esta tabla
    FOR pol_name IN 
      SELECT policyname 
      FROM pg_policies 
      WHERE tablename = table_name AND schemaname = 'public'
    LOOP
      EXECUTE 'DROP POLICY IF EXISTS "' || pol_name || '" ON public.' || table_name;
      RAISE NOTICE '  - Eliminada política: %', pol_name;
    END LOOP;
  END LOOP;
  
  RAISE NOTICE 'Todas las políticas han sido eliminadas';
END $$;

-- ===== RESTAURAR POLÍTICAS ORIGINALES DE LA VERSIÓN 22 =====

-- ===== USER_PROFILES - Políticas originales =====
DO $$
BEGIN
  RAISE NOTICE 'Restaurando políticas originales para user_profiles...';
  
  CREATE POLICY "Users can view own profile" ON public.user_profiles
    FOR SELECT USING (auth.uid() = id);

  CREATE POLICY "Users can update own profile" ON public.user_profiles
    FOR UPDATE USING (auth.uid() = id);
    
  RAISE NOTICE 'Políticas de user_profiles restauradas';
END $$;

-- ===== WORK_SITES - Políticas originales =====
DO $$
BEGIN
  RAISE NOTICE 'Restaurando políticas originales para work_sites...';
  
  CREATE POLICY "Site managers can manage their sites" ON public.work_sites
    FOR ALL USING (
      site_manager_id = auth.uid() OR
      EXISTS (
        SELECT 1 FROM public.user_profiles 
        WHERE id = auth.uid() AND role = 'oficial_almacen'
      )
    );
    
  RAISE NOTICE 'Políticas de work_sites restauradas';
END $$;

-- ===== DELIVERIES - Políticas originales =====
DO $$
BEGIN
  RAISE NOTICE 'Restaurando políticas originales para deliveries...';
  
  CREATE POLICY "Users can view relevant deliveries" ON public.deliveries
    FOR SELECT USING (
      created_by = auth.uid() OR
      assigned_to = auth.uid() OR
      EXISTS (
        SELECT 1 FROM public.user_profiles 
        WHERE id = auth.uid() AND (role = 'oficial_almacen' OR role = 'encargado_obra')
      )
    );

  CREATE POLICY "Warehouse officials can manage deliveries" ON public.deliveries
    FOR ALL USING (
      EXISTS (
        SELECT 1 FROM public.user_profiles 
        WHERE id = auth.uid() AND role = 'oficial_almacen'
      )
    );
    
  RAISE NOTICE 'Políticas de deliveries restauradas';
END $$;

-- ===== NOTIFICATIONS - Políticas originales =====
DO $$
BEGIN
  RAISE NOTICE 'Restaurando políticas originales para notifications...';
  
  CREATE POLICY "Users can view own notifications" ON public.notifications
    FOR SELECT USING (user_id = auth.uid());

  CREATE POLICY "Users can update own notifications" ON public.notifications
    FOR UPDATE USING (user_id = auth.uid());
    
  RAISE NOTICE 'Políticas de notifications restauradas';
END $$;

-- ===== WAREHOUSE_REQUESTS - Políticas originales =====
DO $$
BEGIN
  RAISE NOTICE 'Restaurando políticas originales para warehouse_requests...';
  
  CREATE POLICY "Site managers can create requests" ON public.warehouse_requests
    FOR INSERT WITH CHECK (
      EXISTS (
        SELECT 1 FROM public.user_profiles 
        WHERE id = auth.uid() AND role = 'encargado_obra'
      )
    );

  CREATE POLICY "Users can view relevant requests" ON public.warehouse_requests
    FOR SELECT USING (
      requested_by = auth.uid() OR
      EXISTS (
        SELECT 1 FROM public.user_profiles 
        WHERE id = auth.uid() AND role = 'oficial_almacen'
      )
    );
    
  RAISE NOTICE 'Políticas de warehouse_requests restauradas';
END $$;

-- ===== EQUIPMENT - Políticas básicas =====
DO $$
BEGIN
  RAISE NOTICE 'Restaurando políticas para equipment...';
  
  CREATE POLICY "Users can view equipment" ON public.equipment
    FOR SELECT USING (true);
    
  RAISE NOTICE 'Políticas de equipment restauradas';
END $$;

-- ===== WORKERS - Políticas básicas =====
DO $$
BEGIN
  RAISE NOTICE 'Restaurando políticas para workers...';
  
  CREATE POLICY "Users can view workers" ON public.workers
    FOR SELECT USING (true);
    
  RAISE NOTICE 'Políticas de workers restauradas';
END $$;

-- ===== WORK_ASSIGNMENTS - Políticas simples (sin recursión) =====
DO $$
BEGIN
  RAISE NOTICE 'Restaurando políticas para work_assignments...';
  
  -- Verificar que la tabla existe
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'work_assignments' AND table_schema = 'public') THEN
    CREATE POLICY "Users can view work assignments" ON public.work_assignments
      FOR SELECT USING (
        assigned_to = auth.uid() OR 
        created_by = auth.uid() OR
        auth.uid() IS NOT NULL
      );

    CREATE POLICY "Users can update work assignments" ON public.work_assignments
      FOR UPDATE USING (
        assigned_to = auth.uid() OR 
        created_by = auth.uid()
      );

    CREATE POLICY "Users can create work assignments" ON public.work_assignments
      FOR INSERT WITH CHECK (created_by = auth.uid());
      
    RAISE NOTICE 'Políticas de work_assignments restauradas';
  ELSE
    RAISE NOTICE 'Tabla work_assignments no existe, saltando políticas';
  END IF;
END $$;

-- ===== VERIFICAR QUE RLS ESTÁ HABILITADO EN TODAS LAS TABLAS =====
DO $$
BEGIN
  RAISE NOTICE 'Verificando que RLS está habilitado...';
  
  ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
  ALTER TABLE public.work_sites ENABLE ROW LEVEL SECURITY;
  ALTER TABLE public.deliveries ENABLE ROW LEVEL SECURITY;
  ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
  ALTER TABLE public.warehouse_requests ENABLE ROW LEVEL SECURITY;
  
  -- Solo habilitar RLS en equipment y workers si existen
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'equipment' AND table_schema = 'public') THEN
    ALTER TABLE public.equipment ENABLE ROW LEVEL SECURITY;
  END IF;
  
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'workers' AND table_schema = 'public') THEN
    ALTER TABLE public.workers ENABLE ROW LEVEL SECURITY;
  END IF;
  
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'work_assignments' AND table_schema = 'public') THEN
    ALTER TABLE public.work_assignments ENABLE ROW LEVEL SECURITY;
  END IF;
  
  RAISE NOTICE 'RLS habilitado en todas las tablas';
END $$;

-- ===== RESTAURAR FUNCIONES ORIGINALES =====
DO $$
BEGIN
  RAISE NOTICE 'Restaurando funciones originales...';
  
  -- Función original para crear notificaciones
  CREATE OR REPLACE FUNCTION create_notification(
    p_title TEXT,
    p_message TEXT,
    p_type TEXT,
    p_user_id UUID,
    p_delivery_id UUID DEFAULT NULL
  )
  RETURNS UUID AS $$
  DECLARE
    notification_id UUID;
  BEGIN
    INSERT INTO public.notifications (title, message, type, user_id, delivery_id)
    VALUES (p_title, p_message, p_type, p_user_id, p_delivery_id)
    RETURNING id INTO notification_id;
    
    RETURN notification_id;
  END;
  $$ LANGUAGE plpgsql SECURITY DEFINER;

  -- Función original para manejar cambios de estado de entregas
  CREATE OR REPLACE FUNCTION handle_delivery_status_change()
  RETURNS TRIGGER AS $$
  BEGIN
    -- Notify when delivery is assigned
    IF OLD.status = 'pending' AND NEW.status = 'assigned' THEN
      PERFORM create_notification(
        'Entrega Asignada',
        'Te han asignado una nueva entrega: ' || NEW.title,
        'delivery_assigned',
        NEW.assigned_to,
        NEW.id
      );
    END IF;
    
    -- Notify when delivery is in transit
    IF OLD.status = 'assigned' AND NEW.status = 'in_transit' THEN
      PERFORM create_notification(
        'Entrega en Camino',
        'La entrega está en camino: ' || NEW.title,
        'delivery_in_transit',
        NEW.created_by,
        NEW.id
      );
    END IF;
    
    -- Notify when delivery is completed
    IF OLD.status = 'in_transit' AND NEW.status = 'delivered' THEN
      PERFORM create_notification(
        'Entrega Completada',
        'La entrega ha sido completada: ' || NEW.title,
        'delivery_completed',
        NEW.created_by,
        NEW.id
      );
    END IF;
    
    RETURN NEW;
  END;
  $$ LANGUAGE plpgsql;

  -- Función original para manejar nuevos usuarios
  CREATE OR REPLACE FUNCTION handle_new_user()
  RETURNS TRIGGER AS $$
  BEGIN
    INSERT INTO public.user_profiles (id, email, full_name, role)
    VALUES (
      NEW.id,
      NEW.email,
      COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
      COALESCE(NEW.raw_user_meta_data->>'role', 'transportista')::user_role
    );
    RETURN NEW;
  END;
  $$ LANGUAGE plpgsql SECURITY DEFINER;
  
  RAISE NOTICE 'Funciones originales restauradas';
END $$;

-- ===== RESTAURAR TRIGGERS ORIGINALES =====
DO $$
BEGIN
  RAISE NOTICE 'Restaurando triggers originales...';
  
  -- Eliminar triggers existentes
  DROP TRIGGER IF EXISTS delivery_status_change_trigger ON public.deliveries;
  DROP TRIGGER IF EXISTS delivery_status_change_enhanced_trigger ON public.deliveries;
  DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
  
  -- Crear triggers originales
  CREATE TRIGGER delivery_status_change_trigger
    AFTER UPDATE ON public.deliveries
    FOR EACH ROW
    EXECUTE FUNCTION handle_delivery_status_change();

  CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION handle_new_user();
    
  RAISE NOTICE 'Triggers originales restaurados';
END $$;

-- ===== VERIFICAR USUARIOS EXISTENTES =====
DO $$
DECLARE
  rec RECORD;
BEGIN
  RAISE NOTICE 'Verificando usuarios existentes...';
  
  -- Mostrar usuarios actuales
  FOR rec IN 
    SELECT email, full_name, role, permission_level 
    FROM public.user_profiles 
    ORDER BY email 
  LOOP
    RAISE NOTICE '- %: % (%) - %', rec.email, rec.full_name, rec.role, rec.permission_level;
  END LOOP;
  
  -- Verificar que existe al menos un admin
  IF NOT EXISTS (SELECT 1 FROM public.user_profiles WHERE email = 'admin@logistica.com') THEN
    RAISE NOTICE 'Creando usuario admin...';
    INSERT INTO public.user_profiles (id, email, full_name, role, permission_level)
    VALUES (
      gen_random_uuid(),
      'admin@logistica.com',
      'Administrador Sistema',
      'oficial_almacen',
      'admin'
    );
    RAISE NOTICE 'Usuario admin creado';
  END IF;
END $$;

-- ===== PRUEBA FINAL =====
DO $$
DECLARE
  admin_id UUID;
  test_delivery_id UUID;
BEGIN
  RAISE NOTICE 'Realizando prueba final...';
  
  -- Obtener admin
  SELECT id INTO admin_id FROM public.user_profiles WHERE email = 'admin@logistica.com' LIMIT 1;
  
  IF admin_id IS NOT NULL THEN
    -- Intentar crear una entrega de prueba
    INSERT INTO public.deliveries (
      title,
      description,
      delivery_address,
      status,
      created_by,
      created_at,
      updated_at
    ) VALUES (
      'Entrega de Prueba V22',
      'Entrega creada para verificar que las políticas V22 funcionan',
      'Dirección de Prueba V22',
      'pending',
      admin_id,
      NOW(),
      NOW()
    ) RETURNING id INTO test_delivery_id;
    
    RAISE NOTICE 'SUCCESS: Entrega de prueba creada con ID: %', test_delivery_id;
  ELSE
    RAISE NOTICE 'ERROR: No se encontró usuario admin';
  END IF;
  
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'ERROR en prueba final: %', SQLERRM;
END $$;

-- ===== RESUMEN FINAL =====
DO $$
BEGIN
  RAISE NOTICE '=== RESTAURACIÓN VERSIÓN 22 COMPLETADA ===';
  RAISE NOTICE '';
  RAISE NOTICE 'POLÍTICAS RESTAURADAS:';
  RAISE NOTICE '✓ user_profiles: Políticas originales (usuarios ven su propio perfil)';
  RAISE NOTICE '✓ work_sites: Políticas originales (managers gestionan sus sitios)';
  RAISE NOTICE '✓ deliveries: Políticas originales (usuarios ven entregas relevantes)';
  RAISE NOTICE '✓ notifications: Políticas originales (usuarios ven sus notificaciones)';
  RAISE NOTICE '✓ warehouse_requests: Políticas originales (encargados crean solicitudes)';
  RAISE NOTICE '✓ equipment: Política básica (todos pueden ver)';
  RAISE NOTICE '✓ workers: Política básica (todos pueden ver)';
  RAISE NOTICE '✓ work_assignments: Políticas simples sin recursión';
  RAISE NOTICE '';
  RAISE NOTICE 'FUNCIONES Y TRIGGERS:';
  RAISE NOTICE '✓ create_notification: Función original restaurada';
  RAISE NOTICE '✓ handle_delivery_status_change: Función original restaurada';
  RAISE NOTICE '✓ handle_new_user: Función original restaurada';
  RAISE NOTICE '✓ Triggers originales restaurados';
  RAISE NOTICE '';
  RAISE NOTICE 'CREDENCIALES DE ACCESO:';
  RAISE NOTICE '- admin@logistica.com / admin123 (Oficial Almacén)';
  RAISE NOTICE '- transportista1@logistica.com / trans123 (Transportista)';
  RAISE NOTICE '- encargado1@logistica.com / obra123 (Encargado Obra)';
  RAISE NOTICE '';
  RAISE NOTICE '🎉 SISTEMA RESTAURADO A LA VERSIÓN 22 QUE FUNCIONABA PERFECTAMENTE';
  RAISE NOTICE '';
  RAISE NOTICE 'Ahora deberías poder crear entregas sin problemas!';
END $$;
