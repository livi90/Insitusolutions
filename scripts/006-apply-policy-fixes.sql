-- =====================================================
-- APLICAR CORRECCIONES DE POLÍTICAS
-- =====================================================

-- Ejecutar este script para aplicar las correcciones de políticas
-- que resuelven el problema de recursión infinita

-- Primero, ejecutar el script de políticas corregidas
\i scripts/002-security-policies-fixed.sql

-- Verificar que las políticas se aplicaron correctamente
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual 
FROM pg_policies 
WHERE schemaname = 'public' 
ORDER BY tablename, policyname;

-- Verificar que RLS está habilitado en todas las tablas
SELECT schemaname, tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public' 
AND rowsecurity = true;
