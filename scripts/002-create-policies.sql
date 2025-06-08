-- Policies for user_profiles
CREATE POLICY "Users can view own profile" ON public.user_profiles
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON public.user_profiles
  FOR UPDATE USING (auth.uid() = id);

-- Policies for work_sites
CREATE POLICY "Site managers can manage their sites" ON public.work_sites
  FOR ALL USING (
    site_manager_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM public.user_profiles 
      WHERE id = auth.uid() AND role = 'oficial_almacen'
    )
  );

-- Policies for deliveries
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

-- Policies for notifications
CREATE POLICY "Users can view own notifications" ON public.notifications
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "Users can update own notifications" ON public.notifications
  FOR UPDATE USING (user_id = auth.uid());

-- Policies for warehouse_requests
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
