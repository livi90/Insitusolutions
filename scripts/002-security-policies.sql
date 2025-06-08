-- =====================================================
-- POLÍTICAS DE SEGURIDAD (ROW LEVEL SECURITY)
-- =====================================================

-- =====================================================
-- POLÍTICAS PARA USER_PROFILES
-- =====================================================

-- Los usuarios pueden ver su propio perfil
CREATE POLICY "Users can view own profile" ON public.user_profiles
  FOR SELECT USING (auth.uid() = id);

-- Los usuarios pueden actualizar su propio perfil
CREATE POLICY "Users can update own profile" ON public.user_profiles
  FOR UPDATE USING (auth.uid() = id);

-- Los oficiales de almacén pueden ver todos los perfiles
CREATE POLICY "Warehouse officials can view all profiles" ON public.user_profiles
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.user_profiles 
      WHERE id = auth.uid() AND role = 'oficial_almacen' AND permission_level = 'admin'
    )
  );

-- =====================================================
-- POLÍTICAS PARA WORK_SITES
-- =====================================================

-- Los encargados de obra pueden gestionar sus sitios
CREATE POLICY "Site managers can manage their sites" ON public.work_sites
  FOR ALL USING (
    site_manager_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM public.user_profiles 
      WHERE id = auth.uid() AND role = 'oficial_almacen'
    )
  );

-- Los encargados de obra pueden crear nuevos sitios
CREATE POLICY "Site managers can create sites" ON public.work_sites
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.user_profiles 
      WHERE id = auth.uid() AND role = 'encargado_obra'
    )
  );

-- =====================================================
-- POLÍTICAS PARA DELIVERIES
-- =====================================================

-- Los usuarios pueden ver entregas relevantes
CREATE POLICY "Users can view relevant deliveries" ON public.deliveries
  FOR SELECT USING (
    created_by = auth.uid() OR
    assigned_to = auth.uid() OR
    EXISTS (
      SELECT 1 FROM public.user_profiles 
      WHERE id = auth.uid() AND role IN ('oficial_almacen', 'encargado_obra')
    )
  );

-- Los oficiales de almacén pueden gestionar todas las entregas
CREATE POLICY "Warehouse officials can manage deliveries" ON public.deliveries
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.user_profiles 
      WHERE id = auth.uid() AND role = 'oficial_almacen'
    )
  );

-- Los transportistas pueden actualizar sus entregas asignadas
CREATE POLICY "Transporters can update assigned deliveries" ON public.deliveries
  FOR UPDATE USING (
    assigned_to = auth.uid() AND
    EXISTS (
      SELECT 1 FROM public.user_profiles 
      WHERE id = auth.uid() AND role = 'transportista'
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

-- El sistema puede insertar notificaciones
CREATE POLICY "System can insert notifications" ON public.notifications
  FOR INSERT WITH CHECK (true);

-- =====================================================
-- POLÍTICAS PARA WAREHOUSE_REQUESTS
-- =====================================================

-- Los encargados de obra pueden crear solicitudes
CREATE POLICY "Site managers can create requests" ON public.warehouse_requests
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.user_profiles 
      WHERE id = auth.uid() AND role = 'encargado_obra'
    )
  );

-- Los usuarios pueden ver solicitudes relevantes
CREATE POLICY "Users can view relevant requests" ON public.warehouse_requests
  FOR SELECT USING (
    requested_by = auth.uid() OR
    EXISTS (
      SELECT 1 FROM public.user_profiles 
      WHERE id = auth.uid() AND role = 'oficial_almacen'
    )
  );

-- Los oficiales de almacén pueden actualizar solicitudes
CREATE POLICY "Warehouse officials can update requests" ON public.warehouse_requests
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM public.user_profiles 
      WHERE id = auth.uid() AND role = 'oficial_almacen'
    )
  );

-- =====================================================
-- POLÍTICAS PARA EQUIPMENT
-- =====================================================

-- Los usuarios pueden ver equipos de sus sitios
CREATE POLICY "Users can view site equipment" ON public.equipment
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.work_sites ws
      JOIN public.user_profiles up ON ws.site_manager_id = up.id
      WHERE ws.id = equipment.work_site_id AND up.id = auth.uid()
    ) OR
    EXISTS (
      SELECT 1 FROM public.user_profiles 
      WHERE id = auth.uid() AND role = 'oficial_almacen'
    )
  );

-- Los encargados de obra pueden gestionar equipos de sus sitios
CREATE POLICY "Site managers can manage site equipment" ON public.equipment
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.work_sites ws
      WHERE ws.id = equipment.work_site_id AND ws.site_manager_id = auth.uid()
    ) OR
    EXISTS (
      SELECT 1 FROM public.user_profiles 
      WHERE id = auth.uid() AND role = 'oficial_almacen'
    )
  );

-- =====================================================
-- POLÍTICAS PARA WORKERS
-- =====================================================

-- Los encargados de obra pueden gestionar trabajadores de sus sitios
CREATE POLICY "Site managers can manage site workers" ON public.workers
  FOR ALL USING (
    supervisor_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM public.work_sites ws
      WHERE ws.id = workers.work_site_id AND ws.site_manager_id = auth.uid()
    ) OR
    EXISTS (
      SELECT 1 FROM public.user_profiles 
      WHERE id = auth.uid() AND role = 'oficial_almacen'
    )
  );

-- =====================================================
-- POLÍTICAS PARA MAINTENANCE_TASKS
-- =====================================================

-- Los usuarios pueden ver tareas de mantenimiento relevantes
CREATE POLICY "Users can view relevant maintenance tasks" ON public.maintenance_tasks
  FOR SELECT USING (
    assigned_to = auth.uid() OR
    EXISTS (
      SELECT 1 FROM public.user_profiles 
      WHERE id = auth.uid() AND role IN ('oficial_almacen', 'encargado_obra')
    )
  );

-- Los oficiales de almacén pueden gestionar tareas de mantenimiento
CREATE POLICY "Warehouse officials can manage maintenance tasks" ON public.maintenance_tasks
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.user_profiles 
      WHERE id = auth.uid() AND role = 'oficial_almacen'
    )
  );
