-- Crear tabla de asignaciones de trabajo
CREATE TABLE IF NOT EXISTS public.work_assignments (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT,
  status TEXT DEFAULT 'pending',
  created_by UUID REFERENCES public.user_profiles(id) NOT NULL,
  assigned_to UUID REFERENCES public.user_profiles(id) NOT NULL,
  delivery_id UUID REFERENCES public.deliveries(id),
  work_site_id UUID REFERENCES public.work_sites(id),
  scheduled_date TIMESTAMP WITH TIME ZONE,
  completed_date TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Habilitar RLS
ALTER TABLE public.work_assignments ENABLE ROW LEVEL SECURITY;

-- Políticas para work_assignments
CREATE POLICY "Users can view their own assignments" ON public.work_assignments
  FOR SELECT USING (
    assigned_to = auth.uid() OR 
    created_by = auth.uid() OR
    EXISTS (
      SELECT 1 FROM public.user_profiles 
      WHERE id = auth.uid() AND role = 'oficial_almacen'
    )
  );

CREATE POLICY "Users can update their own assignments" ON public.work_assignments
  FOR UPDATE USING (
    assigned_to = auth.uid() OR 
    created_by = auth.uid() OR
    EXISTS (
      SELECT 1 FROM public.user_profiles 
      WHERE id = auth.uid() AND role = 'oficial_almacen'
    )
  );

CREATE POLICY "Managers can create assignments" ON public.work_assignments
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.user_profiles 
      WHERE id = auth.uid() AND (role = 'oficial_almacen' OR role = 'encargado_obra')
    )
  );
