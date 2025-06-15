-- Script de verificación para analizar el impacto antes de hacer cambios

-- 1. Verificar funciones existentes que podrían verse afectadas
SELECT 'FUNCIONES EXISTENTES QUE PODRÍAN VERSE AFECTADAS:' as info;
SELECT 
    routine_name,
    routine_type,
    routine_definition
FROM information_schema.routines 
WHERE routine_schema = 'public' 
AND (
    routine_name ILIKE '%notification%' OR
    routine_name ILIKE '%delivery%' OR
    routine_name ILIKE '%transporter%' OR
    routine_name ILIKE '%assign%'
)
ORDER BY routine_name;

-- 2. Verificar políticas existentes en deliveries
SELECT 'POLÍTICAS EXISTENTES EN DELIVERIES:' as info;
SELECT 
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE tablename = 'deliveries' 
ORDER BY policyname;

-- 3. Verificar triggers existentes
SELECT 'TRIGGERS EXISTENTES:' as info;
SELECT 
    trigger_name,
    event_manipulation,
    event_object_table,
    action_statement
FROM information_schema.triggers 
WHERE event_object_schema = 'public'
AND (
    event_object_table = 'deliveries' OR
    event_object_table = 'notifications' OR
    trigger_name ILIKE '%delivery%' OR
    trigger_name ILIKE '%notification%'
)
ORDER BY trigger_name;

-- 4. Verificar estructura de tabla notifications
SELECT 'ESTRUCTURA DE TABLA NOTIFICATIONS:' as info;
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'notifications' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- 5. Verificar estructura de tabla deliveries
SELECT 'ESTRUCTURA DE TABLA DELIVERIES:' as info;
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'deliveries' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- 6. Probar funcionalidad actual de creación de entregas
SELECT 'PROBANDO FUNCIONALIDAD ACTUAL:' as info;

-- Verificar si podemos crear una entrega de prueba (sin ejecutar)
EXPLAIN (FORMAT TEXT) 
INSERT INTO deliveries (
    id, title, description, delivery_address, status, created_by, created_at, updated_at
) VALUES (
    gen_random_uuid(),
    'Test Delivery',
    'Test Description',
    'Test Address',
    'pending',
    (SELECT id FROM user_profiles WHERE role::TEXT = 'oficial_almacen' LIMIT 1),
    NOW(),
    NOW()
);

-- 7. Verificar si podemos crear notificaciones (sin ejecutar)
EXPLAIN (FORMAT TEXT)
INSERT INTO notifications (
    id, title, message, type, user_id, read, created_at
) VALUES (
    gen_random_uuid(),
    'Test Notification',
    'Test Message',
    'test',
    (SELECT id FROM user_profiles WHERE role::TEXT = 'transportista' LIMIT 1),
    false,
    NOW()
);

-- 8. Verificar usuarios existentes por rol
SELECT 'USUARIOS EXISTENTES POR ROL:' as info;
SELECT 
    role::TEXT as rol,
    COUNT(*) as cantidad,
    STRING_AGG(full_name, ', ' ORDER BY full_name) as nombres
FROM user_profiles 
GROUP BY role::TEXT
ORDER BY role::TEXT;

-- 9. Verificar entregas existentes y sus estados
SELECT 'ENTREGAS EXISTENTES:' as info;
SELECT 
    status,
    COUNT(*) as cantidad,
    COUNT(assigned_to) as con_transportista_asignado
FROM deliveries 
GROUP BY status
ORDER BY status;

-- 10. Verificar notificaciones existentes
SELECT 'NOTIFICACIONES EXISTENTES:' as info;
SELECT 
    type,
    COUNT(*) as cantidad,
    COUNT(CASE WHEN read = false THEN 1 END) as no_leidas
FROM notifications 
GROUP BY type
ORDER BY type;

-- 11. Verificar permisos actuales
SELECT 'PERMISOS ACTUALES EN TABLAS:' as info;
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd
FROM pg_policies 
WHERE schemaname = 'public'
AND tablename IN ('deliveries', 'notifications', 'user_profiles')
ORDER BY tablename, policyname;

-- 12. Resumen de lo que funcionaría vs lo que podría fallar
SELECT 'RESUMEN DE VERIFICACIÓN:' as info;

-- Verificar si existen conflictos potenciales
SELECT 
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.routines 
            WHERE routine_name = 'create_notification' 
            AND routine_schema = 'public'
        ) THEN 'CONFLICTO: Función create_notification ya existe'
        ELSE 'OK: No hay conflicto con create_notification'
    END as check_create_notification,
    
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM pg_policies 
            WHERE policyname ILIKE '%transportista%update%' 
            AND tablename = 'deliveries'
        ) THEN 'CONFLICTO: Ya existe política de update para transportistas'
        ELSE 'OK: No hay conflicto con políticas de transportista'
    END as check_transporter_policy,
    
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.routines 
            WHERE routine_name = 'assign_transporter_to_delivery' 
            AND routine_schema = 'public'
        ) THEN 'INFO: Función assign_transporter_to_delivery ya existe (se actualizará)'
        ELSE 'OK: Función assign_transporter_to_delivery no existe'
    END as check_assign_function;
