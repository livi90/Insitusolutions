-- =====================================================
-- POLÍTICAS DE SEGURIDAD CORREGIDAS (ROW LEVEL SECURITY)
-- =====================================================

-- Eliminar políticas existentes que causan recursión
DROP POLICY IF EXISTS "Users can view own profile" ON public.user_profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.user_profiles;
DROP POLICY IF EXISTS "Warehouse officials can view all profiles" ON public.user_profiles;
DROP POLICY IF EXISTS "Site managers can manage their sites" ON public.work_sites;
DROP POLICY IF EXISTS "Site managers can create sites" ON public.work_sites;
DROP POLICY IF EXISTS "Users can view relevant deliveries" ON public.deliveries;
DROP POLICY IF EXISTS "Warehouse officials can manage deliveries" ON public.deliveries;
DROP POLICY IF EXISTS "Transporters can update assigned deliveries" ON public.deliveries;
DROP POLICY IF EXISTS "Users can view own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users can update own notifications" ON public.notifications;
DROP POLICY IF EXISTS "System can insert notifications" ON public.notifications;
DROP POLICY IF EXISTS "Site managers can create requests" ON public.warehouse_requests;
DROP POLICY IF EXISTS "Users can view relevant requests" ON public.warehouse_requests;
DROP POLICY IF EXISTS "Warehouse officials can update requests" ON public.warehouse_requests;

-- =====================================================
-- POLÍTICAS SIMPLIFICADAS PARA USER_PROFILES
-- =====================================================

-- Los usuarios pueden ver su propio perfil
CREATE POLICY "Users can view own profile" ON public.user_profiles
  FOR SELECT USING (auth.uid() = id);

-- Los usuarios pueden actualizar su propio perfil
CREATE POLICY "Users can update own profile" ON public.user_profiles
  FOR UPDATE USING (auth.uid() = id);

-- Permitir inserción de perfiles (para el trigger de nuevos usuarios)
CREATE POLICY "Allow profile creation" ON public.user_profiles
  FOR INSERT WITH CHECK (true);

-- =====================================================
-- POLÍTICAS PARA WORK_SITES
-- =====================================================

-- Los usuarios pueden ver sitios donde son managers o si son oficiales de almacén
CREATE POLICY "Users can view relevant sites" ON public.work_sites
  FOR SELECT USING (
    site_manager_id = auth.uid() OR
    auth.uid() IN (
      SELECT id FROM public.user_profiles 
      WHERE role = 'oficial_almacen'
    )
  );

-- Los encargados de obra pueden crear sitios
CREATE POLICY "Site managers can create sites" ON public.work_sites
  FOR INSERT WITH CHECK (
    auth.uid() IN (
      SELECT id FROM public.user_profiles 
      WHERE role = 'encargado_obra'
    )
  );

-- Los managers pueden actualizar sus sitios
CREATE POLICY "Site managers can update their sites" ON public.work_sites
  FOR UPDATE USING (site_manager_id = auth.uid());

-- =====================================================
-- POLÍTICAS PARA DELIVERIES
-- =====================================================

-- Los usuarios pueden ver entregas relevantes
CREATE POLICY "Users can view relevant deliveries" ON public.deliveries
  FOR SELECT USING (
    created_by = auth.uid() OR
    assigned_to = auth.uid() OR
    auth.uid() IN (
      SELECT id FROM public.user_profiles 
      WHERE role IN ('oficial_almacen', 'encargado_obra')
    )
  );

-- Los oficiales de almacén pueden crear entregas
CREATE POLICY "Warehouse officials can create deliveries" ON public.deliveries
  FOR INSERT WITH CHECK (
    auth.uid() IN (
      SELECT id FROM public.user_profiles 
      WHERE role = 'oficial_almacen'
    )
  );

-- Los oficiales de almacén pueden actualizar entregas
CREATE POLICY "Warehouse officials can update deliveries" ON public.deliveries
  FOR UPDATE USING (
    auth.uid() IN (
      SELECT id FROM public.user_profiles 
      WHERE role = 'oficial_almacen'
    )
  );

-- Los transportistas pueden actualizar sus entregas asignadas
CREATE POLICY "Transporters can update assigned deliveries" ON public.deliveries
  FOR UPDATE USING (
    assigned_to = auth.uid() AND
    auth.uid() IN (
      SELECT id FROM public.user_profiles 
      WHERE role = 'transportista'
    )
  );

-- =====================================================
-- POLÍTICAS PARA NOTIFICATIONS
-- =====================================================

-- Los usuarios pueden ver sus propias notificaciones
CREATE POLICY "Users can view own notifications" ON public.notifications
  FOR SELECT USING (user_id = auth.uid());

-- Los usuarios pueden actualizar sus propias notificaciones
CREATE POLICY "Users can update own notifications" ON public.notifications
  FOR UPDATE USING (user_id = auth.uid());

-- Permitir inserción de notificaciones (para triggers y funciones)
CREATE POLICY "Allow notification creation" ON public.notifications
  FOR INSERT WITH CHECK (true);

-- =====================================================
-- POLÍTICAS PARA WAREHOUSE_REQUESTS
-- =====================================================

-- Los encargados de obra pueden crear solicitudes
CREATE POLICY "Site managers can create requests" ON public.warehouse_requests
  FOR INSERT WITH CHECK (
    auth.uid() IN (
      SELECT id FROM public.user_profiles 
      WHERE role = 'encargado_obra'
    )
  );

-- Los usuarios pueden ver solicitudes relevantes
CREATE POLICY "Users can view relevant requests" ON public.warehouse_requests
  FOR SELECT USING (
    requested_by = auth.uid() OR
    auth.uid() IN (
      SELECT id FROM public.user_profiles 
      WHERE role = 'oficial_almacen'
    )
  );

-- Los oficiales de almacén pueden actualizar solicitudes
CREATE POLICY "Warehouse officials can update requests" ON public.warehouse_requests
  FOR UPDATE USING (
    auth.uid() IN (
      SELECT id FROM public.user_profiles 
      WHERE role = 'oficial_almacen'
    )
  );

-- =====================================================
-- POLÍTICAS PARA EQUIPMENT
-- =====================================================

-- Los usuarios pueden ver equipos relevantes
CREATE POLICY "Users can view relevant equipment" ON public.equipment
  FOR SELECT USING (
    assigned_to = auth.uid() OR
    work_site_id IN (
      SELECT id FROM public.work_sites 
      WHERE site_manager_id = auth.uid()
    ) OR
    auth.uid() IN (
      SELECT id FROM public.user_profiles 
      WHERE role = 'oficial_almacen'
    )
  );

-- Los oficiales de almacén pueden gestionar equipos
CREATE POLICY "Warehouse officials can manage equipment" ON public.equipment
  FOR ALL USING (
    auth.uid() IN (
      SELECT id FROM public.user_profiles 
      WHERE role = 'oficial_almacen'
    )
  );

-- =====================================================
-- POLÍTICAS PARA WORKERS
-- =====================================================

-- Los usuarios pueden ver trabajadores relevantes
CREATE POLICY "Users can view relevant workers" ON public.workers
  FOR SELECT USING (
    supervisor_id = auth.uid() OR
    work_site_id IN (
      SELECT id FROM public.work_sites 
      WHERE site_manager_id = auth.uid()
    ) OR
    auth.uid() IN (
      SELECT id FROM public.user_profiles 
      WHERE role = 'oficial_almacen'
    )
  );

-- Los supervisores pueden gestionar trabajadores
CREATE POLICY "Supervisors can manage workers" ON public.workers
  FOR ALL USING (
    supervisor_id = auth.uid() OR
    work_site_id IN (
      SELECT id FROM public.work_sites 
      WHERE site_manager_id = auth.uid()
    ) OR
    auth.uid() IN (
      SELECT id FROM public.user_profiles 
      WHERE role = 'oficial_almacen'
    )
  );
