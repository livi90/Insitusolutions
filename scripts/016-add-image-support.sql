-- Agregar columna para imagen en warehouse_requests
ALTER TABLE public.warehouse_requests 
ADD COLUMN image_url TEXT;

-- Crear bucket para imágenes de solicitudes de almacén
INSERT INTO storage.buckets (id, name, public) 
VALUES ('warehouse-images', 'warehouse-images', true);

-- Política para permitir subir imágenes (usuarios autenticados)
CREATE POLICY "Users can upload warehouse images" ON storage.objects
FOR INSERT WITH CHECK (
  bucket_id = 'warehouse-images' 
  AND auth.role() = 'authenticated'
);

-- Política para permitir ver imágenes (público)
CREATE POLICY "Anyone can view warehouse images" ON storage.objects
FOR SELECT USING (bucket_id = 'warehouse-images');

-- Política para permitir eliminar imágenes (solo el propietario)
CREATE POLICY "Users can delete their warehouse images" ON storage.objects
FOR DELETE USING (
  bucket_id = 'warehouse-images' 
  AND auth.uid()::text = (storage.foldername(name))[1]
);
