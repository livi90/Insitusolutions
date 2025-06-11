-- Diagnóstico del problema de asignación de trabajadores
-- Verificar datos en ambas tablas y políticas

DO $$
DECLARE
    user_profiles_count INTEGER;
    workers_count INTEGER;
    admin_id UUID;
    rec RECORD;
BEGIN
    -- Obtener un admin para las pruebas
    SELECT id INTO admin_id FROM auth.users LIMIT 1;
    
    RAISE NOTICE '=== DIAGNÓSTICO DE TRABAJADORES ===';
    
    -- 1. Verificar user_profiles
    SELECT COUNT(*) INTO user_profiles_count 
    FROM user_profiles 
    WHERE role IN ('operario_maquinaria', 'peon_logistica');
    
    RAISE NOTICE 'Trabajadores en user_profiles: %', user_profiles_count;
    
    -- Mostrar detalles de user_profiles
    RAISE NOTICE '--- Detalles de user_profiles ---';
    FOR rec IN 
        SELECT id, full_name, role, email 
        FROM user_profiles 
        WHERE role IN ('operario_maquinaria', 'peon_logistica')
        ORDER BY role, full_name
    LOOP
        RAISE NOTICE 'ID: %, Nombre: %, Rol: %, Email: %', 
            rec.id, rec.full_name, rec.role, rec.email;
    END LOOP;
    
    -- 2. Verificar workers
    SELECT COUNT(*) INTO workers_count FROM workers;
    
    RAISE NOTICE 'Trabajadores en tabla workers: %', workers_count;
    
    -- Mostrar detalles de workers
    RAISE NOTICE '--- Detalles de workers ---';
    FOR rec IN 
        SELECT id, full_name, position 
        FROM workers 
        ORDER BY position, full_name
    LOOP
        RAISE NOTICE 'ID: %, Nombre: %, Posición: %', 
            rec.id, rec.full_name, rec.position;
    END LOOP;
    
    -- 3. Verificar políticas RLS
    RAISE NOTICE '--- Verificando políticas RLS ---';
    
    -- Verificar si RLS está habilitado
    FOR rec IN 
        SELECT schemaname, tablename, rowsecurity 
        FROM pg_tables 
        WHERE tablename IN ('user_profiles', 'workers')
        AND schemaname = 'public'
    LOOP
        RAISE NOTICE 'Tabla: %.%, RLS habilitado: %', 
            rec.schemaname, rec.tablename, rec.rowsecurity;
    END LOOP;
    
    -- 4. Probar consulta como lo haría el frontend
    RAISE NOTICE '--- Simulando consulta del frontend ---';
    
    -- Simular consulta con usuario admin
    IF admin_id IS NOT NULL THEN
        -- Establecer contexto de usuario
        PERFORM set_config('request.jwt.claims', 
            json_build_object('sub', admin_id::text)::text, true);
        
        -- Probar consulta
        FOR rec IN 
            SELECT id, full_name, role 
            FROM user_profiles 
            WHERE role IN ('operario_maquinaria', 'peon_logistica')
            ORDER BY full_name
        LOOP
            RAISE NOTICE 'Consulta exitosa - ID: %, Nombre: %, Rol: %', 
                rec.id, rec.full_name, rec.role;
        END LOOP;
    END IF;
    
    -- 5. Verificar si necesitamos crear trabajadores de prueba
    IF user_profiles_count = 0 THEN
        RAISE NOTICE '--- CREANDO TRABAJADORES DE PRUEBA ---';
        
        -- Crear trabajadores de prueba
        INSERT INTO user_profiles (id, email, full_name, role, permission_level, created_at, updated_at)
        VALUES 
            (gen_random_uuid(), 'operario1@test.com', 'Juan Pérez - Operario', 'operario_maquinaria', 'normal', NOW(), NOW()),
            (gen_random_uuid(), 'operario2@test.com', 'María García - Operario', 'operario_maquinaria', 'normal', NOW(), NOW()),
            (gen_random_uuid(), 'peon1@test.com', 'Carlos López - Peón', 'peon_logistica', 'normal', NOW(), NOW()),
            (gen_random_uuid(), 'peon2@test.com', 'Ana Martínez - Peón', 'peon_logistica', 'normal', NOW(), NOW());
        
        RAISE NOTICE 'Trabajadores de prueba creados exitosamente';
        
        -- Verificar creación
        SELECT COUNT(*) INTO user_profiles_count 
        FROM user_profiles 
        WHERE role IN ('operario_maquinaria', 'peon_logistica');
        
        RAISE NOTICE 'Total trabajadores después de crear: %', user_profiles_count;
    END IF;
    
    RAISE NOTICE '=== FIN DEL DIAGNÓSTICO ===';
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error durante diagnóstico: %', SQLERRM;
END $$;
