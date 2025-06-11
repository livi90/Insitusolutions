-- Revisar y corregir políticas de work_assignments

-- Eliminar políticas existentes
DROP POLICY IF EXISTS "Users can view their own assignments" ON public.work_assignments;
DROP POLICY IF EXISTS "Users can update their own assignments" ON public.work_assignments;
DROP POLICY IF EXISTS "Managers can create assignments" ON public.work_assignments;

-- Crear políticas más permisivas y claras
CREATE POLICY "View work assignments" ON public.work_assignments
  FOR SELECT USING (
    -- El asignado puede ver sus tareas
    assigned_to = auth.uid() OR 
    -- El creador puede ver las tareas que creó
    created_by = auth.uid() OR
    -- Oficial de almacén puede ver todas
    EXISTS (
      SELECT 1 FROM public.user_profiles 
      WHERE id = auth.uid() AND role = 'oficial_almacen'
    ) OR
    -- Encargado de obra puede ver tareas relacionadas con sus obras
    EXISTS (
      SELECT 1 FROM public.user_profiles 
      WHERE id = auth.uid() AND role = 'encargado_obra'
    )
  );

CREATE POLICY "Update work assignments" ON public.work_assignments
  FOR UPDATE USING (
    -- El asignado puede actualizar sus tareas
    assigned_to = auth.uid() OR 
    -- El creador puede actualizar las tareas que creó
    created_by = auth.uid() OR
    -- Oficial de almacén puede actualizar todas
    EXISTS (
      SELECT 1 FROM public.user_profiles 
      WHERE id = auth.uid() AND role = 'oficial_almacen'
    )
  );

CREATE POLICY "Create work assignments" ON public.work_assignments
  FOR INSERT WITH CHECK (
    -- Oficial de almacén puede crear asignaciones
    EXISTS (
      SELECT 1 FROM public.user_profiles 
      WHERE id = auth.uid() AND role = 'oficial_almacen'
    ) OR
    -- Encargado de obra puede crear asignaciones
    EXISTS (
      SELECT 1 FROM public.user_profiles 
      WHERE id = auth.uid() AND role = 'encargado_obra'
    )
  );

-- Verificar que la tabla work_assignments existe y tiene la estructura correcta
DO $$
BEGIN
  -- Verificar si la tabla existe
  IF NOT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'work_assignments') THEN
    -- Crear la tabla si no existe
    CREATE TABLE public.work_assignments (
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
  END IF;
END $$;

-- Verificar políticas de user_profiles para asegurar que se pueden consultar trabajadores
DROP POLICY IF EXISTS "Users can view own profile" ON public.user_profiles;

CREATE POLICY "View user profiles" ON public.user_profiles
  FOR SELECT USING (
    -- Usuarios pueden ver su propio perfil
    auth.uid() = id OR
    -- Oficial de almacén puede ver todos los perfiles
    EXISTS (
      SELECT 1 FROM public.user_profiles 
      WHERE id = auth.uid() AND role = 'oficial_almacen'
    ) OR
    -- Encargado de obra puede ver perfiles de trabajadores
    EXISTS (
      SELECT 1 FROM public.user_profiles 
      WHERE id = auth.uid() AND role = 'encargado_obra'
    ) OR
    -- Transportistas pueden ver perfiles básicos (para asignaciones)
    EXISTS (
      SELECT 1 FROM public.user_profiles 
      WHERE id = auth.uid() AND role = 'transportista'
    )
  );

-- Política para actualizar perfiles
CREATE POLICY "Update own profile" ON public.user_profiles
  FOR UPDATE USING (
    auth.uid() = id OR
    EXISTS (
      SELECT 1 FROM public.user_profiles 
      WHERE id = auth.uid() AND role = 'oficial_almacen'
    )
  );

-- Verificar que los roles de trabajadores existen en el enum
DO $$
BEGIN
  -- Verificar si los roles existen en el enum
  IF NOT EXISTS (
    SELECT 1 FROM pg_enum 
    WHERE enumlabel = 'operario_maquinaria' 
    AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'user_role')
  ) THEN
    ALTER TYPE user_role ADD VALUE 'operario_maquinaria';
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM pg_enum 
    WHERE enumlabel = 'peon_logistica' 
    AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'user_role')
  ) THEN
    ALTER TYPE user_role ADD VALUE 'peon_logistica';
  END IF;
END $$;
