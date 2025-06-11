-- Corregir dependencias y restaurar a versión 23
-- Eliminar triggers primero, luego funciones

-- ===== ELIMINAR TRIGGERS PROBLEMÁTICOS PRIMERO =====
DROP TRIGGER IF EXISTS delivery_status_change_enhanced_trigger ON public.deliveries;
DROP TRIGGER IF EXISTS delivery_status_change_trigger ON public.deliveries;
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- ===== AHORA ELIMINAR FUNCIONES PROBLEMÁTICAS =====
DROP FUNCTION IF EXISTS create_notification_enhanced(TEXT, TEXT, TEXT, UUID, UUID);
DROP FUNCTION IF EXISTS handle_delivery_status_change_enhanced();
DROP FUNCTION IF EXISTS get_user_role(UUID);

-- ===== LIMPIAR TODAS LAS POLÍTICAS EXISTENTES =====
-- user_profiles
DROP POLICY IF EXISTS "Users can view own profile" ON public.user_profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.user_profiles;
DROP POLICY IF EXISTS "Allow users to view profiles" ON public.user_profiles;
DROP POLICY IF EXISTS "Allow users to update own profile" ON public.user_profiles;
DROP POLICY IF EXISTS "Allow users to insert own profile" ON public.user_profiles;
DROP POLICY IF EXISTS "View user profiles" ON public.user_profiles;
DROP POLICY IF EXISTS "Update own profile" ON public.user_profiles;
DROP POLICY IF EXISTS "Allow read access to user profiles" ON public.user_profiles;
DROP POLICY IF EXISTS "Allow insert for new users" ON public.user_profiles;

-- work_sites
DROP POLICY IF EXISTS "Site managers can manage their sites" ON public.work_sites;
DROP POLICY IF EXISTS "Allow users to view work sites" ON public.work_sites;
DROP POLICY IF EXISTS "Allow users to manage work sites" ON public.work_sites;
DROP POLICY IF EXISTS "Allow read work sites" ON public.work_sites;
DROP POLICY IF EXISTS "Allow manage work sites" ON public.work_sites;

-- deliveries
DROP POLICY IF EXISTS "Users can view relevant deliveries" ON public.deliveries;
DROP POLICY IF EXISTS "Warehouse officials can manage deliveries" ON public.deliveries;
DROP POLICY IF EXISTS "Enhanced delivery visibility" ON public.deliveries;
DROP POLICY IF EXISTS "Allow users to view deliveries" ON public.deliveries;
DROP POLICY IF EXISTS "Allow users to manage deliveries" ON public.deliveries;
DROP POLICY IF EXISTS "Allow read deliveries" ON public.deliveries;

-- notifications
DROP POLICY IF EXISTS "Users can view own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users can update own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Enhanced notification visibility" ON public.notifications;
DROP POLICY IF EXISTS "Allow users to view notifications" ON public.notifications;
DROP POLICY IF EXISTS "Allow users to update notifications" ON public.notifications;
DROP POLICY IF EXISTS "Allow system to create notifications" ON public.notifications;
DROP POLICY IF EXISTS "Allow read notifications" ON public.notifications;

-- warehouse_requests
DROP POLICY IF EXISTS "Site managers can create requests" ON public.warehouse_requests;
DROP POLICY IF EXISTS "Users can view relevant requests" ON public.warehouse_requests;
DROP POLICY IF EXISTS "Allow users to view warehouse requests" ON public.warehouse_requests;
DROP POLICY IF EXISTS "Allow users to create warehouse requests" ON public.warehouse_requests;
DROP POLICY IF EXISTS "Allow users to update warehouse requests" ON public.warehouse_requests;
DROP POLICY IF EXISTS "Allow read warehouse requests" ON public.warehouse_requests;
DROP POLICY IF EXISTS "Allow create warehouse requests" ON public.warehouse_requests;

-- ===== ELIMINAR TABLA WORK_ASSIGNMENTS =====
DROP TABLE IF EXISTS public.work_assignments CASCADE;

-- ===== RESTAURAR FUNCIONES ORIGINALES =====

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

-- ===== CREAR TRIGGERS ORIGINALES =====
CREATE TRIGGER delivery_status_change_trigger
  AFTER UPDATE ON public.deliveries
  FOR EACH ROW
  EXECUTE FUNCTION handle_delivery_status_change();

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_user();

-- ===== RESTAURAR POLÍTICAS ORIGINALES DE LA VERSIÓN 23 =====

-- Políticas para user_profiles (versión original)
CREATE POLICY "Users can view own profile" ON public.user_profiles
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON public.user_profiles
  FOR UPDATE USING (auth.uid() = id);

-- Políticas para work_sites (versión original)
CREATE POLICY "Site managers can manage their sites" ON public.work_sites
  FOR ALL USING (
    site_manager_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM public.user_profiles 
      WHERE id = auth.uid() AND role = 'oficial_almacen'
    )
  );

-- Políticas para deliveries (versión original)
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

-- Políticas para notifications (versión original)
CREATE POLICY "Users can view own notifications" ON public.notifications
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "Users can update own notifications" ON public.notifications
  FOR UPDATE USING (user_id = auth.uid());

-- Políticas para warehouse_requests (versión original)
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

-- ===== VERIFICAR QUE RLS ESTÁ HABILITADO =====
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.work_sites ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.deliveries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.warehouse_requests ENABLE ROW LEVEL SECURITY;

-- ===== VERIFICAR ESTRUCTURA DE TABLAS BÁSICAS =====
-- Asegurar que las tablas básicas existen

-- Verificar que la tabla equipment existe
CREATE TABLE IF NOT EXISTS public.equipment (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  status equipment_status DEFAULT 'available',
  work_site_id UUID REFERENCES public.work_sites(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Verificar que la tabla workers existe
CREATE TABLE IF NOT EXISTS public.workers (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  full_name TEXT NOT NULL,
  position TEXT NOT NULL,
  work_site_id UUID REFERENCES public.work_sites(id),
  supervisor_id UUID REFERENCES public.user_profiles(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Habilitar RLS en las tablas adicionales
ALTER TABLE public.equipment ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workers ENABLE ROW LEVEL SECURITY;

-- Políticas básicas para equipment y workers
DROP POLICY IF EXISTS "Users can view equipment" ON public.equipment;
DROP POLICY IF EXISTS "Users can view workers" ON public.workers;

CREATE POLICY "Users can view equipment" ON public.equipment
  FOR SELECT USING (true);

CREATE POLICY "Users can view workers" ON public.workers
  FOR SELECT USING (true);

-- ===== VERIFICAR TIPOS ENUM =====
-- Asegurar que solo existen los tipos correctos
DO $$
BEGIN
  -- Verificar que el tipo user_role existe con los valores correctos
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_role') THEN
    CREATE TYPE user_role AS ENUM ('oficial_almacen', 'transportista', 'encargado_obra');
  END IF;
  
  -- Verificar que el tipo permission_level existe
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'permission_level') THEN
    CREATE TYPE permission_level AS ENUM ('admin', 'normal');
  END IF;
  
  -- Verificar que el tipo delivery_status existe
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'delivery_status') THEN
    CREATE TYPE delivery_status AS ENUM ('pending', 'assigned', 'in_transit', 'delivered', 'completed');
  END IF;
  
  -- Verificar que el tipo equipment_status existe
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'equipment_status') THEN
    CREATE TYPE equipment_status AS ENUM ('available', 'in_use', 'maintenance');
  END IF;
END $$;

-- ===== MENSAJE DE CONFIRMACIÓN =====
DO $$
BEGIN
  RAISE NOTICE '=== RESTAURACIÓN COMPLETADA ===';
  RAISE NOTICE 'Triggers eliminados correctamente';
  RAISE NOTICE 'Funciones problemáticas eliminadas';
  RAISE NOTICE 'Políticas restauradas a versión 23';
  RAISE NOTICE 'Roles válidos: oficial_almacen, transportista, encargado_obra';
  RAISE NOTICE 'Tabla work_assignments eliminada';
  RAISE NOTICE 'Funciones y triggers originales restaurados';
  RAISE NOTICE 'Sistema listo para usar';
END $$;
