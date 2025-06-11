"use client"

import type React from "react"

import { createContext, useContext, useEffect, useState } from "react"
import type { User } from "@supabase/supabase-js"
import { supabase, type UserProfile } from "@/lib/supabase"

interface AuthContextType {
  user: User | null
  profile: UserProfile | null
  loading: boolean
  signIn: (email: string, password: string) => Promise<{ error: any }>
  signUp: (email: string, password: string, userData: { full_name: string; role: string }) => Promise<{ error: any }>
  signOut: () => Promise<void>
}

const AuthContext = createContext<AuthContextType | undefined>(undefined)

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User | null>(null)
  const [profile, setProfile] = useState<UserProfile | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    // Get initial session
    supabase.auth.getSession().then(({ data: { session } }) => {
      setUser(session?.user ?? null)
      if (session?.user) {
        fetchProfile(session.user.id)
      } else {
        setLoading(false)
      }
    })

    // Listen for auth changes
    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange(async (event, session) => {
      setUser(session?.user ?? null)
      if (session?.user) {
        await fetchProfile(session.user.id)
      } else {
        setProfile(null)
        setLoading(false)
      }
    })

    return () => subscription.unsubscribe()
  }, [])

  const fetchProfile = async (userId: string) => {
    try {
      console.log("Fetching profile for user:", userId)

      // Consulta directa sin políticas complejas
      const { data, error } = await supabase.from("user_profiles").select("*").eq("id", userId).maybeSingle() // Usar maybeSingle en lugar de single para evitar errores si no existe

      if (error) {
        console.error("Error fetching profile:", error)
        throw error
      }

      if (!data) {
        console.log("Profile not found, creating fallback profile")
        // Crear perfil de fallback si no existe
        const fallbackProfile: UserProfile = {
          id: userId,
          email: user?.email || "",
          full_name: user?.user_metadata?.full_name || "Usuario",
          role: (user?.user_metadata?.role as any) || "transportista",
          permission_level: (user?.user_metadata?.permission_level as any) || "normal",
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        }

        // Intentar crear el perfil en la base de datos
        try {
          const { error: insertError } = await supabase.from("user_profiles").insert(fallbackProfile)
          if (insertError) {
            console.error("Error creating profile:", insertError)
          }
        } catch (insertErr) {
          console.error("Failed to insert profile:", insertErr)
        }

        setProfile(fallbackProfile)
      } else {
        console.log("Profile loaded successfully:", data)
        setProfile(data)
      }
    } catch (error: any) {
      console.error("Error in fetchProfile:", error)

      // Crear perfil de emergencia sin intentar guardar en BD
      const emergencyProfile: UserProfile = {
        id: userId,
        email: user?.email || "",
        full_name: user?.user_metadata?.full_name || "Usuario",
        role: "transportista", // Rol por defecto
        permission_level: "normal",
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      }
      setProfile(emergencyProfile)
    } finally {
      setLoading(false)
    }
  }

  const signIn = async (email: string, password: string) => {
    const { error } = await supabase.auth.signInWithPassword({
      email,
      password,
    })
    return { error }
  }

  const signUp = async (email: string, password: string, userData: { full_name: string; role: string }) => {
    const { error } = await supabase.auth.signUp({
      email,
      password,
      options: {
        data: userData,
      },
    })
    return { error }
  }

  const signOut = async () => {
    await supabase.auth.signOut()
  }

  const value = {
    user,
    profile,
    loading,
    signIn,
    signUp,
    signOut,
  }

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

export function useAuth() {
  const context = useContext(AuthContext)
  if (context === undefined) {
    throw new Error("useAuth must be used within an AuthProvider")
  }
  return context
}
