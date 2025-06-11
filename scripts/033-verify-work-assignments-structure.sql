-- Verificar la estructura actual de la tabla work_assignments

DO $$
DECLARE
  table_exists BOOLEAN;
  rec RECORD;
BEGIN
  -- Verificar si la tabla work_assignments existe
  SELECT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_name = 'work_assignments' 
    AND table_schema = 'public'
  ) INTO table_exists;
  
  IF table_exists THEN
    RAISE NOTICE 'La tabla work_assignments existe';
    
    -- Mostrar estructura actual de la tabla
    RAISE NOTICE 'Estructura actual de work_assignments:';
    FOR rec IN 
      SELECT column_name, data_type, is_nullable 
      FROM information_schema.columns 
      WHERE table_name = 'work_assignments' 
      AND table_schema = 'public'
      ORDER BY ordinal_position
    LOOP
      RAISE NOTICE '- %: % (%)', rec.column_name, rec.data_type, 
        CASE WHEN rec.is_nullable = 'YES' THEN 'nullable' ELSE 'not null' END;
    END LOOP;
    
    -- Verificar si la columna assignment_type existe
    IF EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_name = 'work_assignments' 
      AND column_name = 'assignment_type' 
      AND table_schema = 'public'
    ) THEN
      RAISE NOTICE 'ADVERTENCIA: La columna assignment_type todavía existe en la tabla';
    ELSE
      RAISE NOTICE 'CORRECTO: La columna assignment_type no existe en la tabla';
    END IF;
    
    -- Verificar triggers en la tabla deliveries
    RAISE NOTICE '';
    RAISE NOTICE 'Triggers en la tabla deliveries:';
    FOR rec IN 
      SELECT trigger_name, event_manipulation, action_statement
      FROM information_schema.triggers
      WHERE event_object_table = 'deliveries'
      AND trigger_schema = 'public'
    LOOP
      RAISE NOTICE '- %: % - %', rec.trigger_name, rec.event_manipulation, rec.action_statement;
    END LOOP;
    
    -- Verificar funciones relacionadas
    RAISE NOTICE '';
    RAISE NOTICE 'Función create_worker_assignments_for_delivery:';
    FOR rec IN 
      SELECT prosrc
      FROM pg_proc
      WHERE proname = 'create_worker_assignments_for_delivery'
      AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
    LOOP
      RAISE NOTICE 'Código de la función:';
      RAISE NOTICE '%', rec.prosrc;
    END LOOP;
    
  ELSE
    RAISE NOTICE 'La tabla work_assignments no existe';
  END IF;
END $$;
