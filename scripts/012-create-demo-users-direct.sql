-- =====================================================
-- CREAR USUARIOS DE DEMOSTRACIÓN DIRECTAMENTE
-- =====================================================

-- Eliminar usuarios de ejemplo existentes si existen
DELETE FROM public.user_profiles WHERE email LIKE '%@logistica.com';

-- Crear usuarios directamente en user_profiles (sin auth.users)
-- Esto es para demostración, en producción se crearían a través del sistema de auth

INSERT INTO public.user_profiles (
  id, 
  email, 
  full_name, 
  role, 
  permission_level,
  created_at,
  updated_at
) VALUES 
-- Administrador/Oficial de Almacén
(
  '11111111-1111-1111-1111-111111111111',
  'admin@logistica.com',
  'Administrador Sistema',
  'oficial_almacen',
  'admin',
  NOW(),
  NOW()
),
-- Transportistas
(
  '22222222-2222-2222-2222-222222222222',
  'transportista1@logistica.com',
  'Carlos Transportista',
  'transportista',
  'normal',
  NOW(),
  NOW()
),
(
  '22222222-2222-2222-2222-222222222223',
  'transportista2@logistica.com',
  'Ana Transportista',
  'transportista',
  'normal',
  NOW(),
  NOW()
),
-- Encargados de Obra
(
  '33333333-3333-3333-3333-333333333333',
  'encargado1@logistica.com',
  'Luis Encargado Obra',
  'encargado_obra',
  'normal',
  NOW(),
  NOW()
),
(
  '33333333-3333-3333-3333-333333333334',
  'encargado2@logistica.com',
  'María Encargada Obra',
  'encargado_obra',
  'normal',
  NOW(),
  NOW()
),
-- Operarios de Maquinaria
(
  '44444444-4444-4444-4444-444444444444',
  'operario1@logistica.com',
  'Roberto Operario Grúa',
  'operario_maquinaria',
  'normal',
  NOW(),
  NOW()
),
(
  '44444444-4444-4444-4444-444444444445',
  'operario2@logistica.com',
  'Miguel Operario Excavadora',
  'operario_maquinaria',
  'normal',
  NOW(),
  NOW()
),
-- Peones de Logística
(
  '55555555-5555-5555-5555-555555555555',
  'peon1@logistica.com',
  'Pedro Peón Logística',
  'peon_logistica',
  'normal',
  NOW(),
  NOW()
),
(
  '55555555-5555-5555-5555-555555555556',
  'peon2@logistica.com',
  'Sandra Peón Señalización',
  'peon_logistica',
  'normal',
  NOW(),
  NOW()
)
ON CONFLICT (id) DO UPDATE SET
  email = EXCLUDED.email,
  full_name = EXCLUDED.full_name,
  role = EXCLUDED.role,
  permission_level = EXCLUDED.permission_level,
  updated_at = NOW();

-- Verificar que se crearon correctamente
SELECT 
  role,
  COUNT(*) as cantidad,
  STRING_AGG(full_name || ' (' || email || ')', ', ') as usuarios
FROM public.user_profiles 
GROUP BY role 
ORDER BY role;

-- Mostrar todos los usuarios creados
SELECT id, email, full_name, role, permission_level 
FROM public.user_profiles 
ORDER BY role, full_name;
