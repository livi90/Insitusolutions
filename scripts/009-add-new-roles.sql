-- =====================================================
-- AGREGAR NUEVOS ROLES: OPERARIO DE MAQUINARIA Y PEÓN DE LOGÍSTICA
-- =====================================================

-- Agregar nuevos valores al enum de roles
ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'operario_maquinaria';
ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'peon_logistica';

-- Crear tabla para asignaciones de trabajo específicas
CREATE TABLE IF NOT EXISTS public.work_assignments (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT,
  assigned_to UUID REFERENCES public.user_profiles(id) NOT NULL,
  delivery_id UUID REFERENCES public.deliveries(id),
  work_site_id UUID REFERENCES public.work_sites(id),
  assignment_type TEXT NOT NULL, -- 'machinery', 'logistics', 'loading', 'signaling'
  priority TEXT DEFAULT 'normal', -- 'low', 'normal', 'high', 'urgent'
  status TEXT DEFAULT 'pending', -- 'pending', 'in_progress', 'completed', 'cancelled'
  scheduled_start TIMESTAMP WITH TIME ZONE,
  scheduled_end TIMESTAMP WITH TIME ZONE,
  actual_start TIMESTAMP WITH TIME ZONE,
  actual_end TIMESTAMP WITH TIME ZONE,
  equipment_needed TEXT,
  special_instructions TEXT,
  safety_requirements TEXT,
  created_by UUID REFERENCES public.user_profiles(id) NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Crear tabla para reportes de trabajo
CREATE TABLE IF NOT EXISTS public.work_reports (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  assignment_id UUID REFERENCES public.work_assignments(id) NOT NULL,
  reported_by UUID REFERENCES public.user_profiles(id) NOT NULL,
  report_type TEXT NOT NULL, -- 'progress', 'completion', 'issue', 'delay'
  description TEXT NOT NULL,
  photos TEXT[], -- URLs de fotos
  location_notes TEXT,
  equipment_status TEXT,
  next_steps TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Habilitar RLS para las nuevas tablas
ALTER TABLE public.work_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.work_reports ENABLE ROW LEVEL SECURITY;

-- Políticas para work_assignments
CREATE POLICY "Users can view their assignments" ON public.work_assignments
  FOR SELECT USING (
    assigned_to = auth.uid() OR
    created_by = auth.uid() OR
    auth.uid() IN (
      SELECT id FROM public.user_profiles 
      WHERE role IN ('oficial_almacen', 'encargado_obra')
    )
  );

CREATE POLICY "Supervisors can create assignments" ON public.work_assignments
  FOR INSERT WITH CHECK (
    auth.uid() IN (
      SELECT id FROM public.user_profiles 
      WHERE role IN ('oficial_almacen', 'encargado_obra')
    )
  );

CREATE POLICY "Assigned users can update their assignments" ON public.work_assignments
  FOR UPDATE USING (
    assigned_to = auth.uid() OR
    created_by = auth.uid() OR
    auth.uid() IN (
      SELECT id FROM public.user_profiles 
      WHERE role IN ('oficial_almacen', 'encargado_obra')
    )
  );

-- Políticas para work_reports
CREATE POLICY "Users can view relevant reports" ON public.work_reports
  FOR SELECT USING (
    reported_by = auth.uid() OR
    assignment_id IN (
      SELECT id FROM public.work_assignments 
      WHERE assigned_to = auth.uid() OR created_by = auth.uid()
    ) OR
    auth.uid() IN (
      SELECT id FROM public.user_profiles 
      WHERE role IN ('oficial_almacen', 'encargado_obra')
    )
  );

CREATE POLICY "Workers can create reports" ON public.work_reports
  FOR INSERT WITH CHECK (
    reported_by = auth.uid() AND
    assignment_id IN (
      SELECT id FROM public.work_assignments 
      WHERE assigned_to = auth.uid()
    )
  );

-- Crear índices para optimización
CREATE INDEX idx_work_assignments_assigned_to ON public.work_assignments(assigned_to);
CREATE INDEX idx_work_assignments_status ON public.work_assignments(status);
CREATE INDEX idx_work_assignments_delivery_id ON public.work_assignments(delivery_id);
CREATE INDEX idx_work_reports_assignment_id ON public.work_reports(assignment_id);

-- Función para crear asignaciones automáticas cuando se crea una entrega
CREATE OR REPLACE FUNCTION create_work_assignments_for_delivery()
RETURNS TRIGGER AS $$
BEGIN
  -- Si la entrega requiere maquinaria, crear asignación para operario
  IF NEW.description ILIKE '%grúa%' OR NEW.description ILIKE '%excavadora%' OR NEW.description ILIKE '%maquinaria%' THEN
    INSERT INTO public.work_assignments (
      title,
      description,
      assigned_to,
      delivery_id,
      assignment_type,
      priority,
      equipment_needed,
      created_by
    )
    SELECT 
      'Operación de Maquinaria - ' || NEW.title,
      'Se requiere operación de maquinaria para: ' || NEW.description,
      up.id,
      NEW.id,
      'machinery',
      'normal',
      'Según especificaciones de la entrega',
      NEW.created_by
    FROM public.user_profiles up
    WHERE up.role = 'operario_maquinaria'
    LIMIT 1;
  END IF;

  -- Siempre crear asignación para peón de logística
  INSERT INTO public.work_assignments (
    title,
    description,
    assigned_to,
    delivery_id,
    assignment_type,
    priority,
    special_instructions,
    created_by
  )
  SELECT 
    'Apoyo Logístico - ' || NEW.title,
    'Apoyo en descarga, señalización y logística para: ' || NEW.description,
    up.id,
    NEW.id,
    'logistics',
    'normal',
    'Coordinar con transportista y supervisar descarga',
    NEW.created_by
  FROM public.user_profiles up
  WHERE up.role = 'peon_logistica'
  LIMIT 1;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Crear trigger para asignaciones automáticas
CREATE TRIGGER create_assignments_on_delivery
  AFTER INSERT ON public.deliveries
  FOR EACH ROW
  EXECUTE FUNCTION create_work_assignments_for_delivery();

-- Función para notificar cambios en asignaciones
CREATE OR REPLACE FUNCTION notify_assignment_changes()
RETURNS TRIGGER AS $$
BEGIN
  -- Notificar cuando se crea una nueva asignación
  IF TG_OP = 'INSERT' THEN
    PERFORM create_notification(
      'Nueva Asignación de Trabajo',
      'Te han asignado: ' || NEW.title,
      'work_assignment',
      NEW.assigned_to
    );
  END IF;

  -- Notificar cuando cambia el estado
  IF TG_OP = 'UPDATE' AND OLD.status != NEW.status THEN
    CASE NEW.status
      WHEN 'in_progress' THEN
        PERFORM create_notification(
          'Trabajo Iniciado',
          'Has iniciado: ' || NEW.title,
          'work_started',
          NEW.created_by
        );
      WHEN 'completed' THEN
        PERFORM create_notification(
          'Trabajo Completado',
          'Se ha completado: ' || NEW.title,
          'work_completed',
          NEW.created_by
        );
    END CASE;
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Crear trigger para notificaciones de asignaciones
CREATE TRIGGER notify_assignment_changes_trigger
  AFTER INSERT OR UPDATE ON public.work_assignments
  FOR EACH ROW
  EXECUTE FUNCTION notify_assignment_changes();

-- Trigger para actualizar timestamps
CREATE TRIGGER update_work_assignments_updated_at
  BEFORE UPDATE ON public.work_assignments
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
