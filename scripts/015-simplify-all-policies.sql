-- =====================================================
-- SIMPLIFICAR TODAS LAS POLÍTICAS PARA EVITAR RECURSIÓN
-- =====================================================

-- Para deliveries - simplificar políticas
DROP POLICY IF EXISTS "Users can view relevant deliveries" ON public.deliveries;
DROP POLICY IF EXISTS "Warehouse officials can create deliveries" ON public.deliveries;
DROP POLICY IF EXISTS "Warehouse officials can update deliveries" ON public.deliveries;
DROP POLICY IF EXISTS "Transporters can update assigned deliveries" ON public.deliveries;

-- Políticas más simples para deliveries
CREATE POLICY "Allow delivery access" ON public.deliveries
  FOR ALL USING (
    created_by = auth.uid() OR
    assigned_to = auth.uid() OR
    is_supervisor(auth.uid())
  );

-- Para work_assignments - simplificar políticas
DROP POLICY IF EXISTS "Users can view their assignments" ON public.work_assignments;
DROP POLICY IF EXISTS "Supervisors can create assignments" ON public.work_assignments;
DROP POLICY IF EXISTS "Assigned users can update their assignments" ON public.work_assignments;

CREATE POLICY "Allow assignment access" ON public.work_assignments
  FOR ALL USING (
    assigned_to = auth.uid() OR
    created_by = auth.uid() OR
    is_supervisor(auth.uid())
  );

-- Para warehouse_requests - simplificar políticas
DROP POLICY IF EXISTS "Site managers can create requests" ON public.warehouse_requests;
DROP POLICY IF EXISTS "Users can view relevant requests" ON public.warehouse_requests;
DROP POLICY IF EXISTS "Warehouse officials can update requests" ON public.warehouse_requests;

CREATE POLICY "Allow request access" ON public.warehouse_requests
  FOR ALL USING (
    requested_by = auth.uid() OR
    is_supervisor(auth.uid())
  );

-- Para work_sites - simplificar políticas
DROP POLICY IF EXISTS "Users can view relevant sites" ON public.work_sites;
DROP POLICY IF EXISTS "Site managers can create sites" ON public.work_sites;
DROP POLICY IF EXISTS "Site managers can update their sites" ON public.work_sites;

CREATE POLICY "Allow worksite access" ON public.work_sites
  FOR ALL USING (
    site_manager_id = auth.uid() OR
    is_supervisor(auth.uid())
  );

-- Para notifications - mantener simple
DROP POLICY IF EXISTS "Users can view own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users can update own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Allow notification creation" ON public.notifications;

CREATE POLICY "Allow notification access" ON public.notifications
  FOR ALL USING (user_id = auth.uid());

CREATE POLICY "Allow notification creation" ON public.notifications
  FOR INSERT WITH CHECK (true);

-- Para equipment y workers - políticas simples
DROP POLICY IF EXISTS "Users can view relevant equipment" ON public.equipment;
DROP POLICY IF EXISTS "Warehouse officials can manage equipment" ON public.equipment;

CREATE POLICY "Allow equipment access" ON public.equipment
  FOR ALL USING (
    assigned_to = auth.uid() OR
    is_supervisor(auth.uid())
  );

DROP POLICY IF EXISTS "Users can view relevant workers" ON public.workers;
DROP POLICY IF EXISTS "Supervisors can manage workers" ON public.workers;

CREATE POLICY "Allow worker access" ON public.workers
  FOR ALL USING (
    supervisor_id = auth.uid() OR
    is_supervisor(auth.uid())
  );

-- Para work_reports
DROP POLICY IF EXISTS "Users can view relevant reports" ON public.work_reports;
DROP POLICY IF EXISTS "Workers can create reports" ON public.work_reports;

CREATE POLICY "Allow report access" ON public.work_reports
  FOR ALL USING (
    reported_by = auth.uid() OR
    is_supervisor(auth.uid())
  );
