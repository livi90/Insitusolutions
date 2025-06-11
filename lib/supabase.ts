import { createClient } from "@supabase/supabase-js"

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!

export const supabase = createClient(supabaseUrl, supabaseAnonKey)

// Types - Versión 23 restaurada
export type Database = {
  public: {
    Tables: {
      user_profiles: {
        Row: {
          id: string
          email: string
          full_name: string
          role: "oficial_almacen" | "transportista" | "encargado_obra"
          permission_level: "admin" | "normal"
          created_at: string
          updated_at: string
        }
        Insert: {
          id: string
          email: string
          full_name: string
          role: "oficial_almacen" | "transportista" | "encargado_obra"
          permission_level?: "admin" | "normal"
        }
        Update: {
          full_name?: string
          role?: "oficial_almacen" | "transportista" | "encargado_obra"
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
        }
        Insert: {
          title: string
          description?: string
          quantity: number
          requested_by: string
          work_site_id?: string
        }
        Update: {
          title?: string
          description?: string
          quantity?: number
          status?: string
        }
      }
      equipment: {
        Row: {
          id: string
          name: string
          description: string | null
          status: "available" | "in_use" | "maintenance"
          work_site_id: string | null
          created_at: string
          updated_at: string
        }
      }
      workers: {
        Row: {
          id: string
          full_name: string
          position: string
          work_site_id: string | null
          supervisor_id: string | null
          created_at: string
          updated_at: string
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
export type Equipment = Database["public"]["Tables"]["equipment"]["Row"]
export type Worker = Database["public"]["Tables"]["workers"]["Row"]
