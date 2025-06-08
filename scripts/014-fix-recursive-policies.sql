-- =====================================================
-- CORREGIR POLÍTICAS RECURSIVAS
-- =====================================================

-- Eliminar todas las políticas problemáticas de user_profiles
DROP POLICY IF EXISTS "Users can view own profile" ON public.user_profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.user_profiles;
DROP POLICY IF EXISTS "Supervisors can view worker profiles" ON public.user_profiles;
DROP POLICY IF EXISTS "Allow profile creation" ON public.user_profiles;

-- Deshabilitar RLS temporalmente para user_profiles
ALTER TABLE public.user_profiles DISABLE ROW LEVEL SECURITY;

-- Crear una función que verifique permisos sin recursión
CREATE OR REPLACE FUNCTION check_user_role(user_id UUID)
RETURNS TEXT AS $$
DECLARE
  user_role TEXT;
BEGIN
  SELECT role INTO user_role 
  FROM public.user_profiles 
  WHERE id = user_id;
  
  RETURN COALESCE(user_role, 'none');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Crear una función que verifique si el usuario es supervisor
CREATE OR REPLACE FUNCTION is_supervisor(user_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  user_role TEXT;
BEGIN
  SELECT role INTO user_role 
  FROM public.user_profiles 
  WHERE id = user_id;
  
  RETURN user_role IN ('oficial_almacen', 'encargado_obra');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Habilitar RLS nuevamente
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;

-- Crear políticas más simples sin recursión
CREATE POLICY "Allow own profile access" ON public.user_profiles
  FOR ALL USING (auth.uid() = id);

-- Política para permitir que supervisores vean otros perfiles
-- Usamos una función que no causa recursión
CREATE POLICY "Allow supervisor access" ON public.user_profiles
  FOR SELECT USING (
    auth.uid() = id OR 
    is_supervisor(auth.uid())
  );

-- Política para permitir inserción de perfiles (para nuevos usuarios)
CREATE POLICY "Allow profile creation" ON public.user_profiles
  FOR INSERT WITH CHECK (true);

-- Verificar las políticas
SELECT schemaname, tablename, policyname, permissive, roles, cmd 
FROM pg_policies 
WHERE schemaname = 'public' AND tablename = 'user_profiles'
ORDER BY policyname;
