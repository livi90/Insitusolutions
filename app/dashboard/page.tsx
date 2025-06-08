"use client"

import { useEffect, useState } from "react"
import { useRouter } from "next/navigation"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { Bell, Package, Truck, LogOut, Loader2, Building, Settings, Clipboard } from "lucide-react"
import {
  supabase,
  type UserProfile,
  type Delivery,
  type Notification,
  type WarehouseRequest,
  type WorkAssignment,
} from "@/lib/supabase"
import { DeliveryManager } from "@/components/delivery-manager"
import { NotificationCenter } from "@/components/notification-center"
import { WorkSiteManager } from "@/components/worksite-manager"
import { WarehouseRequestManager } from "@/components/warehouse-request-manager"
import { WorkAssignmentManager } from "@/components/work-assignment-manager"
import { getRoleLabel, getRoleColor } from "@/lib/theme"
import { DeliveryAssignmentsView } from "@/components/delivery-assignments-view"

export default function Dashboard() {
  const router = useRouter()
  const [user, setUser] = useState<any>(null)
  const [profile, setProfile] = useState<UserProfile | null>(null)
  const [loading, setLoading] = useState(true)
  const [deliveries, setDeliveries] = useState<Delivery[]>([])
  const [notifications, setNotifications] = useState<Notification[]>([])
  const [warehouseRequests, setWarehouseRequests] = useState<WarehouseRequest[]>([])
  const [workAssignments, setWorkAssignments] = useState<WorkAssignment[]>([])
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false)
  const [stats, setStats] = useState({
    totalDeliveries: 0,
    pendingDeliveries: 0,
    completedDeliveries: 0,
    unreadNotifications: 0,
    pendingAssignments: 0,
  })
  const [error, setError] = useState<string | null>(null)

  // Función para obtener el estilo del header según el rol
  const getHeaderStyle = (role: string) => {
    switch (role) {
      case "oficial_almacen":
        return {
          background: "linear-gradient(to right, #2563eb, #1d4ed8)",
        }
      case "transportista":
        return {
          background: "linear-gradient(to right, #059669, #047857)",
        }
      case "encargado_obra":
        return {
          background: "linear-gradient(to right, #f97316, #ea580c)",
        }
      case "operario_maquinaria":
        return {
          background: "linear-gradient(to right, #7c3aed, #6d28d9)",
        }
      case "peon_logistica":
        return {
          background: "linear-gradient(to right, #0ea5e9, #0284c7)",
        }
      default:
        return {
          background: "linear-gradient(to right, #2563eb, #1d4ed8)",
        }
    }
  }

  useEffect(() => {
    const checkUser = async () => {
      try {
        const {
          data: { session },
          error: sessionError,
        } = await supabase.auth.getSession()

        if (sessionError) throw sessionError

        if (!session) {
          router.push("/login")
          return
        }

        setUser(session.user)
        await fetchUserProfile(session.user.id)
      } catch (err: any) {
        console.error("Error checking authentication:", err)
        setError(err.message)
        if (err.message.includes("infinite recursion") || err.message.includes("policy")) {
          console.log("Policy error detected, redirecting to login...")
          router.push("/login")
          return
        }
      } finally {
        setLoading(false)
      }
    }

    checkUser()

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange(async (event, session) => {
      if (event === "SIGNED_OUT") {
        router.push("/login")
      }
    })

    return () => {
      subscription?.unsubscribe()
    }
  }, [router])

  const fetchUserProfile = async (userId: string) => {
    try {
      const { data: profileData, error: profileError } = await supabase
        .from("user_profiles")
        .select("*")
        .eq("id", userId)
        .single()

      if (profileError) {
        if (profileError.code === "PGRST116") {
          const { data: newProfile, error: createError } = await supabase
            .from("user_profiles")
            .insert({
              id: userId,
              email: user?.email || "",
              full_name: user?.user_metadata?.full_name || "Usuario",
              role: user?.user_metadata?.role || "transportista",
              permission_level: user?.user_metadata?.permission_level || "normal",
            })
            .select()
            .single()

          if (createError) {
            console.error("Error creating profile:", createError)
            setProfile({
              id: userId,
              email: user?.email || "",
              full_name: user?.user_metadata?.full_name || "Usuario",
              role: user?.user_metadata?.role || "transportista",
              permission_level: user?.user_metadata?.permission_level || "normal",
              created_at: new Date().toISOString(),
              updated_at: new Date().toISOString(),
            })
          } else {
            setProfile(newProfile)
          }
        } else {
          throw profileError
        }
      } else {
        setProfile(profileData)
      }

      if (profileData || profile) {
        await fetchData(userId, profileData || profile)
      }
    } catch (err: any) {
      console.error("Error fetching user profile:", err)
      if (err.message.includes("policy") || err.message.includes("recursion")) {
        setProfile({
          id: userId,
          email: user?.email || "",
          full_name: user?.user_metadata?.full_name || "Usuario",
          role: user?.user_metadata?.role || "transportista",
          permission_level: user?.user_metadata?.permission_level || "normal",
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        })
      } else {
        throw err
      }
    }
  }

  const fetchData = async (userId: string, userProfile: UserProfile) => {
    try {
      if (!userId || !userProfile) return

      // Fetch deliveries with error handling
      try {
        let deliveriesQuery = supabase.from("deliveries").select("*")

        if (userProfile.role === "transportista") {
          deliveriesQuery = deliveriesQuery.or(`assigned_to.eq.${userId},created_by.eq.${userId}`)
        } else if (userProfile.role === "encargado_obra") {
          deliveriesQuery = deliveriesQuery.eq("created_by", userId)
        }

        const { data: deliveriesData, error: deliveriesError } = await deliveriesQuery.order("created_at", {
          ascending: false,
        })

        if (deliveriesError) {
          console.error("Error fetching deliveries:", deliveriesError)
        } else {
          setDeliveries(deliveriesData || [])
        }
      } catch (err) {
        console.error("Error in deliveries fetch:", err)
        setDeliveries([])
      }

      // Calculate stats
      const totalDeliveries = deliveries?.length || 0
      const pendingDeliveries = deliveries?.filter((d) => d.status === "pending" || d.status === "assigned").length || 0
      const completedDeliveries = deliveries?.filter((d) => d.status === "completed").length || 0
      const unreadNotifications = notifications?.filter((n) => !n.read).length || 0
      const pendingAssignments =
        workAssignments?.filter((a) => a.status === "pending" || a.status === "in_progress").length || 0

      setStats({
        totalDeliveries,
        pendingDeliveries,
        completedDeliveries,
        unreadNotifications,
        pendingAssignments,
      })
    } catch (err: any) {
      console.error("Error fetching data:", err)
    }
  }

  const handleSignOut = async () => {
    try {
      await supabase.auth.signOut()
      router.push("/login")
    } catch (err: any) {
      console.error("Error signing out:", err)
      router.push("/login")
    }
  }

  const handleRefresh = () => {
    if (user && profile) {
      fetchData(user.id, profile)
    }
  }

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-blue-50 to-indigo-50 p-4">
        <div className="text-center">
          <div className="relative">
            <Loader2 className="h-12 w-12 sm:h-16 sm:w-16 animate-spin mx-auto text-blue-600" />
            <div className="absolute inset-0 h-12 w-12 sm:h-16 sm:w-16 animate-ping mx-auto rounded-full bg-blue-400 opacity-20"></div>
          </div>
          <p className="mt-4 sm:mt-6 text-gray-700 font-medium text-sm sm:text-base">Cargando dashboard...</p>
        </div>
      </div>
    )
  }

  if (error) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-blue-50 to-indigo-50 p-4">
        <div className="text-center max-w-sm sm:max-w-md p-6 sm:p-8 bg-white rounded-lg shadow-xl">
          <div className="p-3 bg-red-100 rounded-full w-fit mx-auto mb-4">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              className="h-6 w-6 text-red-600"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
              />
            </svg>
          </div>
          <h2 className="text-lg sm:text-xl font-bold text-red-600 mb-4">Error de Configuración</h2>
          <p className="text-gray-700 mb-6 text-sm sm:text-base">
            Hay un problema con la configuración de la base de datos. Por favor ejecuta los scripts de corrección.
          </p>
          <div className="space-y-3">
            <Button onClick={() => router.push("/login")} className="w-full bg-blue-600 hover:bg-blue-700">
              Volver al Login
            </Button>
            <Button variant="outline" onClick={() => window.location.reload()} className="w-full">
              Reintentar
            </Button>
          </div>
        </div>
      </div>
    )
  }

  if (!user || !profile) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-blue-50 to-indigo-50 p-4">
        <div className="text-center max-w-sm sm:max-w-md p-6 sm:p-8 bg-white rounded-lg shadow-xl">
          <h2 className="text-lg sm:text-xl font-bold mb-4">Sesión no encontrada</h2>
          <p className="text-gray-700 mb-6 text-sm sm:text-base">Por favor inicia sesión para continuar.</p>
          <Button onClick={() => router.push("/login")} className="bg-blue-600 hover:bg-blue-700 w-full">
            Iniciar sesión
          </Button>
        </div>
      </div>
    )
  }

  // Determinar qué pestañas mostrar según el rol
  const showDeliveries = ["oficial_almacen", "transportista", "encargado_obra"].includes(profile.role)
  const showWorkSites = profile.role === "encargado_obra"
  const showRequests = profile.role === "encargado_obra"
  const showAssignments = ["operario_maquinaria", "peon_logistica"].includes(profile.role)
  const showAssignmentsView = ["oficial_almacen", "encargado_obra"].includes(profile.role)

  // Obtener el color del rol
  const roleColor = getRoleColor(profile.role)

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header Responsive con estilo inline */}
      <div style={getHeaderStyle(profile.role)} className="text-white shadow-md">
        <div className="max-w-7xl mx-auto px-3 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center py-3 sm:py-4">
            <div className="flex items-center gap-2 sm:gap-3 min-w-0 flex-1">
              <div className="p-1.5 sm:p-2 bg-white/20 rounded-lg flex-shrink-0">
                <Building className="h-4 w-4 sm:h-6 sm:w-6" />
              </div>
              <div className="min-w-0 flex-1">
                <h1 className="text-lg sm:text-2xl font-bold truncate">In-Situ Solutions</h1>
                <div className="flex flex-col sm:flex-row sm:items-center gap-1 sm:gap-2">
                  <p className="text-xs sm:text-sm text-white/80 truncate">
                    {profile.full_name} - {getRoleLabel(profile.role)}
                  </p>
                  {profile.permission_level === "admin" && (
                    <Badge className="bg-white/30 text-white hover:bg-white/40 text-xs w-fit">Admin</Badge>
                  )}
                </div>
              </div>
            </div>
            <div className="flex items-center gap-2 sm:gap-4 flex-shrink-0">
              <div className="relative">
                <Button variant="ghost" size="sm" className="text-white hover:bg-white/20 hover:text-white p-2">
                  <Bell className="h-4 w-4 sm:h-5 sm:w-5" />
                  {stats.unreadNotifications > 0 && (
                    <Badge className="absolute -top-1 -right-1 px-1 py-0.5 text-xs bg-red-500 min-w-[1.25rem] h-5">
                      {stats.unreadNotifications}
                    </Badge>
                  )}
                </Button>
              </div>
              <Button
                variant="ghost"
                size="sm"
                onClick={handleSignOut}
                className="text-white hover:bg-white/20 hover:text-white hidden sm:flex"
              >
                <LogOut className="h-4 w-4 sm:h-5 sm:w-5 mr-1 sm:mr-2" />
                <span className="hidden sm:inline">Salir</span>
              </Button>
              <Button
                variant="ghost"
                size="sm"
                onClick={handleSignOut}
                className="text-white hover:bg-white/20 hover:text-white sm:hidden p-2"
              >
                <LogOut className="h-4 w-4" />
              </Button>
            </div>
          </div>
        </div>
      </div>

      {/* Main Content */}
      <div className="max-w-7xl mx-auto px-3 sm:px-6 lg:px-8 py-4 sm:py-8">
        {/* Stats Cards - Responsive Grid */}
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-3 sm:gap-6 mb-6 sm:mb-8">
          {showDeliveries && (
            <>
              <Card className="border-0 shadow-md hover:shadow-lg transition-shadow bg-gradient-to-br from-white to-gray-50">
                <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2 p-3 sm:p-6">
                  <CardTitle className="text-xs sm:text-sm font-medium">Total Entregas</CardTitle>
                  <Package className="h-4 w-4 sm:h-5 sm:w-5 text-blue-600" />
                </CardHeader>
                <CardContent className="p-3 sm:p-6 pt-0">
                  <div className="text-xl sm:text-2xl font-bold">{stats.totalDeliveries}</div>
                  <p className="text-xs text-gray-500 mt-1 hidden sm:block">Entregas registradas en el sistema</p>
                </CardContent>
              </Card>

              <Card className="border-0 shadow-md hover:shadow-lg transition-shadow bg-gradient-to-br from-white to-gray-50">
                <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2 p-3 sm:p-6">
                  <CardTitle className="text-xs sm:text-sm font-medium">Pendientes</CardTitle>
                  <Truck className="h-4 w-4 sm:h-5 sm:w-5 text-blue-600" />
                </CardHeader>
                <CardContent className="p-3 sm:p-6 pt-0">
                  <div className="text-xl sm:text-2xl font-bold">{stats.pendingDeliveries}</div>
                  <p className="text-xs text-gray-500 mt-1 hidden sm:block">Esperando ser completadas</p>
                </CardContent>
              </Card>
            </>
          )}

          {showAssignments && (
            <Card className="border-0 shadow-md hover:shadow-lg transition-shadow bg-gradient-to-br from-white to-gray-50">
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2 p-3 sm:p-6">
                <CardTitle className="text-xs sm:text-sm font-medium">Tareas</CardTitle>
                <Clipboard className="h-4 w-4 sm:h-5 sm:w-5 text-blue-600" />
              </CardHeader>
              <CardContent className="p-3 sm:p-6 pt-0">
                <div className="text-xl sm:text-2xl font-bold">{stats.pendingAssignments}</div>
                <p className="text-xs text-gray-500 mt-1 hidden sm:block">Por completar</p>
              </CardContent>
            </Card>
          )}

          {profile.role === "operario_maquinaria" && (
            <Card className="border-0 shadow-md hover:shadow-lg transition-shadow bg-gradient-to-br from-white to-gray-50">
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2 p-3 sm:p-6">
                <CardTitle className="text-xs sm:text-sm font-medium">Equipos</CardTitle>
                <Settings className="h-4 w-4 sm:h-5 sm:w-5 text-purple-600" />
              </CardHeader>
              <CardContent className="p-3 sm:p-6 pt-0">
                <div className="text-xl sm:text-2xl font-bold">2</div>
                <p className="text-xs text-gray-500 mt-1 hidden sm:block">Bajo tu responsabilidad</p>
              </CardContent>
            </Card>
          )}

          <Card className="border-0 shadow-md hover:shadow-lg transition-shadow bg-gradient-to-br from-white to-gray-50">
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2 p-3 sm:p-6">
              <CardTitle className="text-xs sm:text-sm font-medium">Notificaciones</CardTitle>
              <Bell className="h-4 w-4 sm:h-5 sm:w-5 text-blue-600" />
            </CardHeader>
            <CardContent className="p-3 sm:p-6 pt-0">
              <div className="text-xl sm:text-2xl font-bold">{stats.unreadNotifications}</div>
              <p className="text-xs text-gray-500 mt-1 hidden sm:block">Mensajes sin leer</p>
            </CardContent>
          </Card>
        </div>

        {/* Main Tabs - Responsive */}
        <Tabs defaultValue={showAssignments ? "assignments" : "deliveries"} className="space-y-4 sm:space-y-6">
          <div className="overflow-x-auto">
            <TabsList className="bg-white shadow-sm border w-full sm:w-auto">
              {showDeliveries && (
                <TabsTrigger
                  value="deliveries"
                  className="data-[state=active]:bg-blue-600 data-[state=active]:text-white text-xs sm:text-sm px-2 sm:px-4"
                >
                  Entregas
                </TabsTrigger>
              )}
              <TabsTrigger
                value="notifications"
                className="data-[state=active]:bg-blue-600 data-[state=active]:text-white text-xs sm:text-sm px-2 sm:px-4"
              >
                Notificaciones
              </TabsTrigger>
              {showWorkSites && (
                <TabsTrigger
                  value="worksites"
                  className="data-[state=active]:bg-blue-600 data-[state=active]:text-white text-xs sm:text-sm px-2 sm:px-4"
                >
                  Obras
                </TabsTrigger>
              )}
              {showRequests && (
                <TabsTrigger
                  value="requests"
                  className="data-[state=active]:bg-blue-600 data-[state=active]:text-white text-xs sm:text-sm px-2 sm:px-4"
                >
                  Solicitudes
                </TabsTrigger>
              )}
              {showAssignments && (
                <TabsTrigger
                  value="assignments"
                  className="data-[state=active]:bg-blue-600 data-[state=active]:text-white text-xs sm:text-sm px-2 sm:px-4"
                >
                  Mis Tareas
                </TabsTrigger>
              )}
              {showAssignmentsView && (
                <TabsTrigger
                  value="worker-assignments"
                  className="data-[state=active]:bg-blue-600 data-[state=active]:text-white text-xs sm:text-sm px-2 sm:px-4"
                >
                  Personal
                </TabsTrigger>
              )}
            </TabsList>
          </div>

          {showDeliveries && (
            <TabsContent value="deliveries">
              <DeliveryManager deliveries={deliveries} userProfile={profile} onUpdate={handleRefresh} />
            </TabsContent>
          )}

          <TabsContent value="notifications">
            <NotificationCenter notifications={notifications} onUpdate={handleRefresh} />
          </TabsContent>

          {showWorkSites && (
            <TabsContent value="worksites">
              <WorkSiteManager userProfile={profile} />
            </TabsContent>
          )}

          {showRequests && (
            <TabsContent value="requests">
              <WarehouseRequestManager requests={warehouseRequests} userProfile={profile} onUpdate={handleRefresh} />
            </TabsContent>
          )}

          {showAssignments && (
            <TabsContent value="assignments">
              <WorkAssignmentManager assignments={workAssignments} userProfile={profile} onUpdate={handleRefresh} />
            </TabsContent>
          )}

          {showAssignmentsView && (
            <TabsContent value="worker-assignments">
              <DeliveryAssignmentsView userProfile={profile} />
            </TabsContent>
          )}
        </Tabs>
      </div>

      {/* Footer - Responsive */}
      <div className="bg-white border-t py-3 sm:py-4 mt-6 sm:mt-8">
        <div className="max-w-7xl mx-auto px-3 sm:px-6 lg:px-8">
          <div className="flex flex-col sm:flex-row justify-between items-center gap-2">
            <div className="flex items-center gap-2">
              <Building className="h-3 w-3 sm:h-4 sm:w-4 text-blue-600" />
              <span className="text-xs sm:text-sm font-medium text-gray-700">In-Situ Solutions</span>
            </div>
            <div className="text-xs sm:text-sm text-gray-500">
              © 2025 In-Situ Solutions. Todos los derechos reservados.
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
