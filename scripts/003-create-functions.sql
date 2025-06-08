-- Function to create notification
CREATE OR REPLACE FUNCTION create_notification(
  p_title TEXT,
  p_message TEXT,
  p_type TEXT,
  p_user_id UUID,
  p_delivery_id UUID DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  notification_id UUID;
BEGIN
  INSERT INTO public.notifications (title, message, type, user_id, delivery_id)
  VALUES (p_title, p_message, p_type, p_user_id, p_delivery_id)
  RETURNING id INTO notification_id;
  
  RETURN notification_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to handle delivery status changes
CREATE OR REPLACE FUNCTION handle_delivery_status_change()
RETURNS TRIGGER AS $$
BEGIN
  -- Notify when delivery is assigned
  IF OLD.status = 'pending' AND NEW.status = 'assigned' THEN
    PERFORM create_notification(
      'Entrega Asignada',
      'Te han asignado una nueva entrega: ' || NEW.title,
      'delivery_assigned',
      NEW.assigned_to,
      NEW.id
    );
  END IF;
  
  -- Notify when delivery is in transit
  IF OLD.status = 'assigned' AND NEW.status = 'in_transit' THEN
    PERFORM create_notification(
      'Entrega en Camino',
      'La entrega está en camino: ' || NEW.title,
      'delivery_in_transit',
      NEW.created_by,
      NEW.id
    );
  END IF;
  
  -- Notify when delivery is completed
  IF OLD.status = 'in_transit' AND NEW.status = 'delivered' THEN
    PERFORM create_notification(
      'Entrega Completada',
      'La entrega ha sido completada: ' || NEW.title,
      'delivery_completed',
      NEW.created_by,
      NEW.id
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for delivery status changes
CREATE TRIGGER delivery_status_change_trigger
  AFTER UPDATE ON public.deliveries
  FOR EACH ROW
  EXECUTE FUNCTION handle_delivery_status_change();

-- Function to handle new user signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.user_profiles (id, email, full_name, role)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    COALESCE(NEW.raw_user_meta_data->>'role', 'transportista')::user_role
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for new user signup
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_user();
