-- =====================================================
-- SCRIPT DE LIMPIEZA (USAR CON PRECAUCIÓN)
-- =====================================================
-- Este script elimina todos los datos y estructuras
-- Úsalo solo si necesitas empezar desde cero

-- ADVERTENCIA: Este script eliminará TODOS los datos
-- Descomenta las líneas siguientes solo si estás seguro

/*
-- Eliminar triggers
DROP TRIGGER IF EXISTS delivery_status_change_trigger ON public.deliveries;
DROP TRIGGER IF EXISTS warehouse_request_change_trigger ON public.warehouse_requests;
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP TRIGGER IF EXISTS update_user_profiles_updated_at ON public.user_profiles;
DROP TRIGGER IF EXISTS update_work_sites_updated_at ON public.work_sites;
DROP TRIGGER IF EXISTS update_equipment_updated_at ON public.equipment;
DROP TRIGGER IF EXISTS update_workers_updated_at ON public.workers;
DROP TRIGGER IF EXISTS update_maintenance_tasks_updated_at ON public.maintenance_tasks;

-- Eliminar funciones
DROP FUNCTION IF EXISTS create_notification(TEXT, TEXT, TEXT, UUID, UUID, UUID);
DROP FUNCTION IF EXISTS handle_delivery_status_change();
DROP FUNCTION IF EXISTS handle_warehouse_request_change();
DROP FUNCTION IF EXISTS handle_new_user();
DROP FUNCTION IF EXISTS update_updated_at_column();
DROP FUNCTION IF EXISTS create_sample_data();

-- Eliminar tablas (en orden para evitar errores de foreign key)
DROP TABLE IF EXISTS public.maintenance_tasks;
DROP TABLE IF EXISTS public.notifications;
DROP TABLE IF EXISTS public.warehouse_requests;
DROP TABLE IF EXISTS public.deliveries;
DROP TABLE IF EXISTS public.workers;
DROP TABLE IF EXISTS public.equipment;
DROP TABLE IF EXISTS public.work_sites;
DROP TABLE IF EXISTS public.user_profiles;

-- Eliminar tipos enumerados
DROP TYPE IF EXISTS request_status;
DROP TYPE IF EXISTS equipment_status;
DROP TYPE IF EXISTS delivery_status;
DROP TYPE IF EXISTS permission_level;
DROP TYPE IF EXISTS user_role;
*/

-- Para ver todas las tablas creadas:
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
ORDER BY table_name;

-- Para ver todos los tipos enumerados:
SELECT typname 
FROM pg_type 
WHERE typtype = 'e' 
ORDER BY typname;
