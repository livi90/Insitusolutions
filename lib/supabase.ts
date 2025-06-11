import { createClient } from "@supabase/supabase-js"

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!

export const supabase = createClient(supabaseUrl, supabaseAnonKey)

// Types
export type Database = {
  public: {
    Tables: {
      user_profiles: {
        Row: {
          id: string
          email: string
          full_name: string
          role: "oficial_almacen" | "transportista" | "encargado_obra" | "operario_maquinaria" | "peon_logistica"
          permission_level: "admin" | "normal"
          created_at: string
          updated_at: string
        }
        Insert: {
          id: string
          email: string
          full_name: string
          role: "oficial_almacen" | "transportista" | "encargado_obra" | "operario_maquinaria" | "peon_logistica"
          permission_level?: "admin" | "normal"
        }
        Update: {
          full_name?: string
          role?: "oficial_almacen" | "transportista" | "encargado_obra" | "operario_maquinaria" | "peon_logistica"
          permission_level?: "admin" | "normal"
        }
      }
      deliveries: {
        Row: {
          id: string
          title: string
          description: string | null
          delivery_address: string
          status: "pending" | "assigned" | "in_transit" | "delivered" | "completed"
          created_by: string
          assigned_to: string | null
          work_site_id: string | null
          scheduled_date: string | null
          completed_date: string | null
          created_at: string
          updated_at: string
        }
        Insert: {
          title: string
          description?: string
          delivery_address: string
          created_by: string
          work_site_id?: string
          scheduled_date?: string
        }
        Update: {
          title?: string
          description?: string
          delivery_address?: string
          status?: "pending" | "assigned" | "in_transit" | "delivered" | "completed"
          assigned_to?: string
          scheduled_date?: string
          completed_date?: string
        }
      }
      notifications: {
        Row: {
          id: string
          title: string
          message: string
          type: string
          user_id: string
          delivery_id: string | null
          read: boolean
          created_at: string
        }
      }
      work_sites: {
        Row: {
          id: string
          name: string
          address: string
          description: string | null
          site_manager_id: string | null
          created_at: string
          updated_at: string
        }
        Insert: {
          name: string
          address: string
          description?: string
          site_manager_id?: string
        }
        Update: {
          name?: string
          address?: string
          description?: string
          site_manager_id?: string
        }
      }
      warehouse_requests: {
        Row: {
          id: string
          title: string
          description: string | null
          quantity: number
          status: string
          requested_by: string
          work_site_id: string | null
          created_at: string
          updated_at: string
          image_url: string | null
        }
        Insert: {
          title: string
          description?: string
          quantity: number
          requested_by: string
          work_site_id?: string
          image_url?: string
        }
        Update: {
          title?: string
          description?: string
          quantity?: number
          status?: string
          image_url?: string
        }
      }
      work_assignments: {
        Row: {
          id: string
          title: string
          description: string | null
          status: "pending" | "in_progress" | "completed" | "cancelled"
          created_by: string
          assigned_to: string
          delivery_id: string | null
          work_site_id: string | null
          scheduled_date: string | null
          completed_date: string | null
          created_at: string
          updated_at: string
        }
        Insert: {
          title: string
          description?: string
          status?: "pending" | "in_progress" | "completed" | "cancelled"
          created_by: string
          assigned_to: string
          delivery_id?: string
          work_site_id?: string
          scheduled_date?: string
        }
        Update: {
          title?: string
          description?: string
          status?: "pending" | "in_progress" | "completed" | "cancelled"
          completed_date?: string
        }
      }
    }
  }
}

export type UserProfile = Database["public"]["Tables"]["user_profiles"]["Row"]
export type Delivery = Database["public"]["Tables"]["deliveries"]["Row"]
export type Notification = Database["public"]["Tables"]["notifications"]["Row"]
export type WorkSite = Database["public"]["Tables"]["work_sites"]["Row"]
export type WarehouseRequest = Database["public"]["Tables"]["warehouse_requests"]["Row"]
export type WorkAssignment = Database["public"]["Tables"]["work_assignments"]["Row"]
