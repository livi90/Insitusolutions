-- =====================================================
-- ACTUALIZAR POLÍTICAS PARA PERMITIR SELECCIÓN DE USUARIOS
-- =====================================================

-- Eliminar política restrictiva existente
DROP POLICY IF EXISTS "Warehouse officials can view all profiles" ON public.user_profiles;

-- Crear política más permisiva para que los oficiales de almacén y encargados de obra
-- puedan ver otros usuarios para asignaciones
CREATE POLICY "Supervisors can view worker profiles" ON public.user_profiles
  FOR SELECT USING (
    -- Los usuarios pueden ver su propio perfil
    auth.uid() = id OR
    -- Los oficiales de almacén pueden ver todos los perfiles
    auth.uid() IN (
      SELECT id FROM public.user_profiles 
      WHERE role = 'oficial_almacen'
    ) OR
    -- Los encargados de obra pueden ver perfiles de trabajadores
    (auth.uid() IN (
      SELECT id FROM public.user_profiles 
      WHERE role = 'encargado_obra'
    ) AND role IN ('transportista', 'operario_maquinaria', 'peon_logistica'))
  );

-- Verificar las políticas actuales
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual 
FROM pg_policies 
WHERE schemaname = 'public' AND tablename = 'user_profiles'
ORDER BY policyname;
