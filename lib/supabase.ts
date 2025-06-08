import { createClient } from "@supabase/supabase-js"

// Get environment variables
const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY

// Validate environment variables
if (!supabaseUrl) {
  console.error("Missing environment variable: NEXT_PUBLIC_SUPABASE_URL")
}

if (!supabaseAnonKey) {
  console.error("Missing environment variable: NEXT_PUBLIC_SUPABASE_ANON_KEY")
}

// Create Supabase client
export const supabase = createClient(supabaseUrl || "", supabaseAnonKey || "", {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: true,
  },
})

// Types for database tables
export type UserRole = "oficial_almacen" | "transportista" | "encargado_obra" | "operario_maquinaria" | "peon_logistica"

export type UserProfile = {
  id: string
  email: string
  full_name: string
  role: UserRole
  permission_level: "admin" | "normal"
  phone?: string
  avatar_url?: string
  created_at: string
  updated_at: string
}

export type Delivery = {
  id: string
  title: string
  description?: string
  delivery_address: string
  status: "pending" | "assigned" | "in_transit" | "delivered" | "completed"
  priority?: string
  created_by: string
  assigned_to?: string
  work_site_id?: string
  scheduled_date?: string
  started_at?: string
  completed_date?: string
  notes?: string
  created_at: string
  updated_at: string
}

export type Notification = {
  id: string
  title: string
  message: string
  type: string
  user_id: string
  delivery_id?: string
  work_site_id?: string
  read: boolean
  created_at: string
}

export type WorkSite = {
  id: string
  name: string
  address: string
  description?: string
  site_manager_id?: string
  status?: string
  created_at: string
  updated_at: string
}

export type WarehouseRequest = {
  id: string
  title: string
  description?: string
  quantity: number
  unit?: string
  status: "pending" | "approved" | "rejected" | "completed"
  priority?: string
  requested_by: string
  approved_by?: string
  work_site_id?: string
  image_url?: string
  approved_at?: string
  completed_at?: string
  notes?: string
  created_at: string
  updated_at: string
}

export type WorkAssignment = {
  id: string
  title: string
  description?: string
  assigned_to: string
  delivery_id?: string
  work_site_id?: string
  assignment_type: "machinery" | "logistics" | "loading" | "signaling"
  priority: "low" | "normal" | "high" | "urgent"
  status: "pending" | "in_progress" | "completed" | "cancelled"
  scheduled_start?: string
  scheduled_end?: string
  actual_start?: string
  actual_end?: string
  equipment_needed?: string
  special_instructions?: string
  safety_requirements?: string
  created_by: string
  created_at: string
  updated_at: string
}

export type WorkReport = {
  id: string
  assignment_id: string
  reported_by: string
  report_type: "progress" | "completion" | "issue" | "delay"
  description: string
  photos?: string[]
  location_notes?: string
  equipment_status?: string
  next_steps?: string
  created_at: string
}

export type Equipment = {
  id: string
  name: string
  description?: string
  serial_number?: string
  status: "available" | "in_use" | "maintenance"
  work_site_id?: string
  assigned_to?: string
  created_at: string
  updated_at: string
}

export type Worker = {
  id: string
  full_name: string
  position: string
  phone?: string
  work_site_id?: string
  supervisor_id?: string
  status?: string
  created_at: string
  updated_at: string
}
