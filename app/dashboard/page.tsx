"use client"

import { useEffect, useState } from "react"
import { useRouter } from "next/navigation"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { Bell, Package, Truck, LogOut, Loader2, Building, AlertCircle, Users, Settings } from "lucide-react"
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
import { getRoleLabel } from "@/lib/theme"
import { useToast } from "@/hooks/use-toast"

export default function Dashboard() {
  const router = useRouter()
  const { toast } = useToast()

  // Estados principales
  const [user, setUser] = useState<any>(null)
  const [profile, setProfile] = useState<UserProfile | null>(null)
  const [loading, setLoading] = useState(true)
  const [signingOut, setSigningOut] = useState(false)
  const [error, setError] = useState<string | null>(null)

  // Estados de datos
  const [deliveries, setDeliveries] = useState<Delivery[]>([])
  const [notifications, setNotifications] = useState<Notification[]>([])
  const [warehouseRequests, setWarehouseRequests] = useState<WarehouseRequest[]>([])
  const [workAssignments, setWorkAssignments] = useState<WorkAssignment[]>([])

  // Estados de UI
  const [activeTab, setActiveTab] = useState("deliveries")
  const [stats, setStats] = useState({
    totalDeliveries: 0,
    pendingDeliveries: 0,
    completedDeliveries: 0,
    unreadNotifications: 0,
    pendingAssignments: 0,
  })

  // Estados de visibilidad de pestañas
  const [showDeliveries, setShowDeliveries] = useState(false)
  const [showWorkSites, setShowWorkSites] = useState(false)
  const [showRequests, setShowRequests] = useState(false)
  const [showAssignments, setShowAssignments] = useState(false)

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
      case "peon_logistica":
        return {
          background: "linear-gradient(to right, #0891b2, #0e7490)",
        }
      case "operario_maquinaria":
        return {
          background: "linear-gradient(to right, #7c3aed, #6d28d9)",
        }
      default:
        return {
          background: "linear-gradient(to right, #2563eb, #1d4ed8)",
        }
    }
  }

  // Efecto principal para verificar autenticación
  useEffect(() => {
    const checkUser = async () => {
      try {
        const {
          data: { session },
          error: sessionError,
        } = await supabase.auth.getSession()

        if (sessionError) {
          console.error("Session error:", sessionError)
          throw sessionError
        }

        if (!session) {
          console.log("No session found, redirecting to login")
          router.push("/login")
          return
        }

        console.log("Session found for user:", session.user.id)
        setUser(session.user)
        await fetchUserProfile(session.user.id)
      } catch (err: any) {
        console.error("Error checking authentication:", err)
        setError(err.message)
        router.push("/login")
      } finally {
        setLoading(false)
      }
    }

    checkUser()

    // Escuchar cambios en el estado de autenticación
    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange(async (event, session) => {
      console.log("Auth state changed:", event, session?.user?.id)

      if (event === "SIGNED_OUT" || !session) {
        console.log("User signed out, redirecting to login...")
        setUser(null)
        setProfile(null)
        router.push("/login")
      } else if (event === "SIGNED_IN" && session) {
        console.log("User signed in:", session.user.id)
        setUser(session.user)
        await fetchUserProfile(session.user.id)
      }
    })

    return () => {
      subscription?.unsubscribe()
    }
  }, [router])

  // Efecto para determinar qué pestañas mostrar según el rol
  useEffect(() => {
    if (profile) {
      const newShowDeliveries = ["oficial_almacen", "transportista", "encargado_obra"].includes(profile.role)
      const newShowWorkSites = profile.role === "encargado_obra"
      const newShowRequests = profile.role === "encargado_obra"
      const newShowAssignments = profile.role === "operario_maquinaria" || profile.role === "peon_logistica"

      setShowDeliveries(newShowDeliveries)
      setShowWorkSites(newShowWorkSites)
      setShowRequests(newShowRequests)
      setShowAssignments(newShowAssignments)

      // Establecer pestaña activa por defecto
      if (newShowAssignments) {
        setActiveTab("assignments")
      } else if (newShowDeliveries) {
        setActiveTab("deliveries")
      } else {
        setActiveTab("notifications")
      }
    }
  }, [profile])

  const fetchUserProfile = async (userId: string) => {
    try {
      console.log("Fetching profile for user:", userId)

      // Con las políticas V22, solo podemos ver nuestro propio perfil
      const { data: profileData, error: profileError } = await supabase
        .from("user_profiles")
        .select("*")
        .eq("id", userId)
        .single()

      if (profileError) {
        console.error("Profile error:", profileError)
        throw profileError
      }

      console.log("Profile found:", profileData)
      setProfile(profileData)

      // Cargar datos después de obtener el perfil
      await fetchData(userId, profileData)
    } catch (err: any) {
      console.error("Error fetching user profile:", err)
      setError(err.message)
    }
  }

  const fetchData = async (userId: string, userProfile: UserProfile) => {
    console.log("Fetching data for user:", userId, "with role:", userProfile.role)

    try {
      // Fetch deliveries - Con políticas V22, solo vemos entregas relevantes
      try {
        console.log("Fetching deliveries...")
        const { data: deliveriesData, error: deliveriesError } = await supabase
          .from("deliveries")
          .select("*")
          .order("created_at", { ascending: false })
          .limit(50)

        if (deliveriesError) {
          console.error("Error fetching deliveries:", deliveriesError)
          setDeliveries([])
        } else {
          console.log("Deliveries loaded:", deliveriesData?.length || 0)
          setDeliveries(deliveriesData || [])
        }
      } catch (err) {
        console.error("Error in deliveries fetch:", err)
        setDeliveries([])
      }

      // Fetch notifications - Con políticas V22, solo vemos nuestras notificaciones
      try {
        console.log("Fetching notifications...")
        const { data: notificationsData, error: notificationsError } = await supabase
          .from("notifications")
          .select("*")
          .eq("user_id", userId)
          .order("created_at", { ascending: false })
          .limit(20)

        if (notificationsError) {
          console.error("Error fetching notifications:", notificationsError)
          setNotifications([])
        } else {
          console.log("Notifications loaded:", notificationsData?.length || 0)
          setNotifications(notificationsData || [])
        }
      } catch (err) {
        console.error("Error in notifications fetch:", err)
        setNotifications([])
      }

      // Fetch work assignments para trabajadores
      try {
        console.log("Fetching work assignments...")
        if (userProfile.role === "operario_maquinaria" || userProfile.role === "peon_logistica") {
          const { data: assignmentsData, error: assignmentsError } = await supabase
            .from("work_assignments")
            .select("*")
            .eq("assigned_to", userId)
            .order("created_at", { ascending: false })

          if (assignmentsError) {
            console.error("Error fetching work assignments:", assignmentsError)
            setWorkAssignments([])
          } else {
            console.log("Work assignments loaded:", assignmentsData?.length || 0)
            setWorkAssignments(assignmentsData || [])
          }
        }
      } catch (err) {
        console.error("Error in work assignments fetch:", err)
        setWorkAssignments([])
      }

      // Fetch warehouse requests - Con políticas V22, solo encargados y oficiales
      try {
        console.log("Fetching warehouse requests...")
        if (userProfile.role === "encargado_obra" || userProfile.role === "oficial_almacen") {
          const { data: requestsData, error: requestsError } = await supabase
            .from("warehouse_requests")
            .select("*")
            .order("created_at", { ascending: false })
            .limit(20)

          if (requestsError) {
            console.error("Error fetching warehouse requests:", requestsError)
            setWarehouseRequests([])
          } else {
            console.log("Warehouse requests loaded:", requestsData?.length || 0)
            setWarehouseRequests(requestsData || [])
          }
        }
      } catch (err) {
        console.error("Error in warehouse requests fetch:", err)
        setWarehouseRequests([])
      }

      console.log("Data fetch completed successfully")
    } catch (err: any) {
      console.error("Error fetching data:", err)
      setError(`Error al cargar datos: ${err.message}`)
    }
  }

  // Efecto para calcular estadísticas cuando cambian los datos
  useEffect(() => {
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
  }, [deliveries, notifications, workAssignments])

  const handleSignOut = async () => {
    if (signingOut) return

    setSigningOut(true)

    try {
      console.log("Iniciando proceso de cierre de sesión...")

      // Limpiar estado local inmediatamente
      setUser(null)
      setProfile(null)
      setDeliveries([])
      setNotifications([])
      setWarehouseRequests([])
      setWorkAssignments([])

      // Cerrar sesión en Supabase
      const { error } = await supabase.auth.signOut()

      if (error) {
        console.error("Error during sign out:", error)
        toast({
          title: "Error al cerrar sesión",
          description: error.message,
          variant: "destructive",
        })
      } else {
        console.log("Sign out successful")
        toast({
          title: "Sesión cerrada",
          description: "Has cerrado sesión exitosamente",
        })
      }

      // Redirigir al login independientemente del resultado
      router.push("/login")
    } catch (err: any) {
      console.error("Unexpected error during sign out:", err)
      toast({
        title: "Error inesperado",
        description: "Ocurrió un error al cerrar sesión",
        variant: "destructive",
      })

      // Forzar redirección incluso si hay error
      router.push("/login")
    } finally {
      setSigningOut(false)
    }
  }

  const handleRefresh = () => {
    if (user && profile) {
      fetchData(user.id, profile)
    }
  }

  // Función para manejar el cambio de pestaña en móvil
  const handleTabChange = (value: string) => {
    setActiveTab(value)
    // Scroll al inicio en móvil cuando se cambia de pestaña
    if (window.innerWidth < 768) {
      window.scrollTo(0, 0)
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
            <AlertCircle className="h-6 w-6 text-red-600" />
          </div>
          <h2 className="text-lg sm:text-xl font-bold text-red-600 mb-4">Error de Configuración</h2>
          <p className="text-gray-700 mb-6 text-sm sm:text-base">{error}</p>
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

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header Responsive */}
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
                disabled={signingOut}
                className="text-white hover:bg-white/20 hover:text-white hidden sm:flex"
              >
                {signingOut ? (
                  <Loader2 className="h-4 w-4 sm:h-5 sm:w-5 mr-1 sm:mr-2 animate-spin" />
                ) : (
                  <LogOut className="h-4 w-4 sm:h-5 sm:w-5 mr-1 sm:mr-2" />
                )}
                <span className="hidden sm:inline">{signingOut ? "Saliendo..." : "Salir"}</span>
              </Button>
              <Button
                variant="ghost"
                size="sm"
                onClick={handleSignOut}
                disabled={signingOut}
                className="text-white hover:bg-white/20 hover:text-white sm:hidden p-2"
              >
                {signingOut ? <Loader2 className="h-4 w-4 animate-spin" /> : <LogOut className="h-4 w-4" />}
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
                  <p className="text-xs text-gray-500 mt-1 hidden sm:block">
                    {profile.role === "encargado_obra"
                      ? "Entregas para tus obras"
                      : "Entregas registradas en el sistema"}
                  </p>
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
                <CardTitle className="text-xs sm:text-sm font-medium">Mis Tareas</CardTitle>
                {profile.role === "operario_maquinaria" ? (
                  <Settings className="h-4 w-4 sm:h-5 sm:w-5 text-purple-600" />
                ) : (
                  <Users className="h-4 w-4 sm:h-5 sm:w-5 text-cyan-600" />
                )}
              </CardHeader>
              <CardContent className="p-3 sm:p-6 pt-0">
                <div className="text-xl sm:text-2xl font-bold">{stats.pendingAssignments}</div>
                <p className="text-xs text-gray-500 mt-1 hidden sm:block">Tareas pendientes</p>
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
        <Tabs
          defaultValue={showAssignments ? "assignments" : "deliveries"}
          value={activeTab}
          onValueChange={handleTabChange}
          className="space-y-4 sm:space-y-6"
        >
          <div className="overflow-x-auto">
            <TabsList className="bg-white shadow-sm border w-full sm:w-auto">
              {showAssignments && (
                <TabsTrigger
                  value="assignments"
                  className="data-[state=active]:bg-purple-600 data-[state=active]:text-white text-xs sm:text-sm px-2 sm:px-4"
                >
                  Mis Tareas
                </TabsTrigger>
              )}
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
            </TabsList>
          </div>

          {showAssignments && (
            <TabsContent value="assignments">
              <WorkAssignmentManager assignments={workAssignments} userProfile={profile} onUpdate={handleRefresh} />
            </TabsContent>
          )}

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
