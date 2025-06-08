"use client"

import type React from "react"

import { useState, useEffect } from "react"
import { useRouter } from "next/navigation"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { Alert, AlertDescription } from "@/components/ui/alert"
import { Badge } from "@/components/ui/badge"
import { Truck, Warehouse, HardHat, Loader2, CheckCircle, Settings, Users, Zap, MapPin, Building } from "lucide-react"
import { supabase } from "@/lib/supabase"
import { getRoleColor, getRoleLabel, getRoleDescription } from "@/lib/theme"

export default function LoginPage() {
  const router = useRouter()
  const [loading, setLoading] = useState(false)
  const [authChecking, setAuthChecking] = useState(true)
  const [error, setError] = useState("")
  const [success, setSuccess] = useState("")

  const [loginData, setLoginData] = useState({
    email: "",
    password: "",
  })

  const [signupData, setSignupData] = useState({
    email: "",
    password: "",
    confirmPassword: "",
    full_name: "",
    role: "",
  })

  useEffect(() => {
    const checkSession = async () => {
      try {
        const {
          data: { session },
        } = await supabase.auth.getSession()
        if (session) {
          router.push("/dashboard")
        }
      } catch (err) {
        console.error("Error checking session:", err)
      } finally {
        setAuthChecking(false)
      }
    }

    checkSession()
  }, [router])

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true)
    setError("")
    setSuccess("")

    try {
      const { data, error } = await supabase.auth.signInWithPassword({
        email: loginData.email,
        password: loginData.password,
      })

      if (error) throw error

      // Verificar que el perfil existe
      const { data: profile, error: profileError } = await supabase
        .from("user_profiles")
        .select("*")
        .eq("id", data.user.id)
        .single()

      if (profileError && profileError.code === "PGRST116") {
        // El perfil no existe, crearlo
        const { error: createError } = await supabase.from("user_profiles").insert({
          id: data.user.id,
          email: data.user.email || "",
          full_name: data.user.user_metadata?.full_name || "Usuario",
          role: data.user.user_metadata?.role || "transportista",
          permission_level: data.user.user_metadata?.permission_level || "normal",
        })

        if (createError) {
          console.error("Error creating profile:", createError)
        }
      }

      router.push("/dashboard")
    } catch (err: any) {
      console.error("Error logging in:", err)
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }

  const handleSignup = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true)
    setError("")
    setSuccess("")

    // Validaciones
    if (signupData.password !== signupData.confirmPassword) {
      setError("Las contraseñas no coinciden")
      setLoading(false)
      return
    }

    if (signupData.password.length < 6) {
      setError("La contraseña debe tener al menos 6 caracteres")
      setLoading(false)
      return
    }

    if (!signupData.role) {
      setError("Por favor selecciona un rol")
      setLoading(false)
      return
    }

    try {
      // Primero crear el usuario en auth
      const { data: authData, error: authError } = await supabase.auth.signUp({
        email: signupData.email,
        password: signupData.password,
        options: {
          data: {
            full_name: signupData.full_name,
            role: signupData.role,
            permission_level: "normal",
          },
        },
      })

      if (authError) throw authError

      if (authData.user) {
        // Crear el perfil manualmente para asegurar que existe
        const { error: profileError } = await supabase.from("user_profiles").insert({
          id: authData.user.id,
          email: signupData.email,
          full_name: signupData.full_name,
          role: signupData.role as any,
          permission_level: "normal",
        })

        if (profileError) {
          console.error("Error creating profile:", profileError)
        }

        setSuccess("¡Cuenta creada exitosamente! Ya puedes iniciar sesión.")

        // Limpiar formulario
        setSignupData({
          email: "",
          password: "",
          confirmPassword: "",
          full_name: "",
          role: "",
        })

        // Cambiar a la pestaña de login después de 2 segundos
        setTimeout(() => {
          const loginTab = document.querySelector('[value="login"]') as HTMLElement
          loginTab?.click()
        }, 2000)
      }
    } catch (err: any) {
      console.error("Error signing up:", err)
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }

  const getRoleIcon = (role: string) => {
    switch (role) {
      case "oficial_almacen":
        return <Warehouse className="w-4 h-4 sm:w-5 sm:h-5" />
      case "transportista":
        return <Truck className="w-4 h-4 sm:w-5 sm:h-5" />
      case "encargado_obra":
        return <HardHat className="w-4 h-4 sm:w-5 sm:h-5" />
      case "operario_maquinaria":
        return <Settings className="w-4 h-4 sm:w-5 sm:h-5" />
      case "peon_logistica":
        return <Users className="w-4 h-4 sm:w-5 sm:h-5" />
      default:
        return null
    }
  }

  if (authChecking) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-blue-50 via-indigo-50 to-purple-50 p-4">
        <div className="text-center">
          <div className="relative">
            <Loader2 className="h-12 w-12 sm:h-16 sm:w-16 animate-spin mx-auto text-blue-600" />
            <div className="absolute inset-0 h-12 w-12 sm:h-16 sm:w-16 animate-ping mx-auto rounded-full bg-blue-400 opacity-20"></div>
          </div>
          <p className="mt-4 sm:mt-6 text-gray-700 font-medium text-sm sm:text-base">Verificando sesión...</p>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 via-indigo-50 to-purple-50 p-3 sm:p-4">
      {/* Header - Responsive */}
      <div className="text-center py-4 sm:py-8">
        <div className="flex items-center justify-center gap-2 sm:gap-3 mb-3 sm:mb-4">
          <div className="p-2 sm:p-3 bg-gradient-to-r from-blue-600 to-indigo-600 rounded-xl">
            <Building className="h-6 w-6 sm:h-8 sm:w-8 text-white" />
          </div>
          <h1 className="text-2xl sm:text-4xl font-bold bg-gradient-to-r from-blue-600 to-indigo-600 bg-clip-text text-transparent">
            In-Situ Solutions
          </h1>
        </div>
        <p className="text-gray-600 text-base sm:text-lg">Sistema Integral de Gestión Logística</p>
        <div className="flex items-center justify-center gap-2 mt-2">
          <MapPin className="h-3 w-3 sm:h-4 sm:w-4 text-gray-500" />
          <span className="text-xs sm:text-sm text-gray-500">Optimizando operaciones en tiempo real</span>
        </div>
      </div>

      <div className="max-w-7xl mx-auto grid grid-cols-1 lg:grid-cols-3 gap-4 sm:gap-8">
        {/* Formulario de Login/Registro - Responsive */}
        <div className="lg:col-span-2">
          <Card className="shadow-2xl border-0 bg-white/80 backdrop-blur-sm">
            <CardHeader className="text-center pb-4 sm:pb-6 p-4 sm:p-6">
              <CardTitle className="text-xl sm:text-2xl font-bold text-gray-900">Acceso al Sistema</CardTitle>
              <CardDescription className="text-gray-600 text-sm sm:text-base">
                Inicia sesión o crea una nueva cuenta para comenzar
              </CardDescription>
            </CardHeader>
            <CardContent className="p-4 sm:p-6">
              <Tabs defaultValue="login" className="w-full">
                <TabsList className="grid w-full grid-cols-2 mb-4 sm:mb-6">
                  <TabsTrigger
                    value="login"
                    className="data-[state=active]:bg-blue-600 data-[state=active]:text-white text-xs sm:text-sm"
                  >
                    Iniciar Sesión
                  </TabsTrigger>
                  <TabsTrigger
                    value="signup"
                    className="data-[state=active]:bg-indigo-600 data-[state=active]:text-white text-xs sm:text-sm"
                  >
                    Registrarse
                  </TabsTrigger>
                </TabsList>

                <TabsContent value="login">
                  <form onSubmit={handleLogin} className="space-y-4 sm:space-y-6">
                    <div className="space-y-2">
                      <Label htmlFor="email" className="text-gray-700 font-medium text-sm sm:text-base">
                        Email
                      </Label>
                      <Input
                        id="email"
                        type="email"
                        value={loginData.email}
                        onChange={(e) => setLoginData({ ...loginData, email: e.target.value })}
                        className="h-10 sm:h-12 border-gray-300 focus:border-blue-500 focus:ring-blue-500 text-sm sm:text-base"
                        placeholder="tu@email.com"
                        required
                      />
                    </div>
                    <div className="space-y-2">
                      <Label htmlFor="password" className="text-gray-700 font-medium text-sm sm:text-base">
                        Contraseña
                      </Label>
                      <Input
                        id="password"
                        type="password"
                        value={loginData.password}
                        onChange={(e) => setLoginData({ ...loginData, password: e.target.value })}
                        className="h-10 sm:h-12 border-gray-300 focus:border-blue-500 focus:ring-blue-500 text-sm sm:text-base"
                        placeholder="••••••••"
                        required
                      />
                    </div>
                    {error && (
                      <Alert variant="destructive" className="border-red-200 bg-red-50">
                        <AlertDescription className="text-red-700 text-sm">{error}</AlertDescription>
                      </Alert>
                    )}
                    {success && (
                      <Alert className="border-green-200 bg-green-50">
                        <CheckCircle className="h-4 w-4 text-green-600" />
                        <AlertDescription className="text-green-700 text-sm">{success}</AlertDescription>
                      </Alert>
                    )}
                    <Button
                      type="submit"
                      className="w-full h-10 sm:h-12 bg-blue-600 hover:bg-blue-700 text-white font-medium text-sm sm:text-base"
                      disabled={loading}
                    >
                      {loading ? (
                        <>
                          <Loader2 className="mr-2 h-4 w-4 sm:h-5 sm:w-5 animate-spin" />
                          Iniciando sesión...
                        </>
                      ) : (
                        "Iniciar Sesión"
                      )}
                    </Button>
                  </form>
                </TabsContent>

                <TabsContent value="signup">
                  <form onSubmit={handleSignup} className="space-y-4 sm:space-y-6">
                    <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                      <div className="space-y-2">
                        <Label htmlFor="signup-name" className="text-gray-700 font-medium text-sm sm:text-base">
                          Nombre Completo
                        </Label>
                        <Input
                          id="signup-name"
                          type="text"
                          value={signupData.full_name}
                          onChange={(e) => setSignupData({ ...signupData, full_name: e.target.value })}
                          className="h-10 sm:h-12 border-gray-300 focus:border-indigo-500 focus:ring-indigo-500 text-sm sm:text-base"
                          placeholder="Juan Pérez"
                          required
                        />
                      </div>
                      <div className="space-y-2">
                        <Label htmlFor="signup-email" className="text-gray-700 font-medium text-sm sm:text-base">
                          Email
                        </Label>
                        <Input
                          id="signup-email"
                          type="email"
                          value={signupData.email}
                          onChange={(e) => setSignupData({ ...signupData, email: e.target.value })}
                          className="h-10 sm:h-12 border-gray-300 focus:border-indigo-500 focus:ring-indigo-500 text-sm sm:text-base"
                          placeholder="juan@empresa.com"
                          required
                        />
                      </div>
                    </div>
                    <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                      <div className="space-y-2">
                        <Label htmlFor="signup-password" className="text-gray-700 font-medium text-sm sm:text-base">
                          Contraseña
                        </Label>
                        <Input
                          id="signup-password"
                          type="password"
                          value={signupData.password}
                          onChange={(e) => setSignupData({ ...signupData, password: e.target.value })}
                          className="h-10 sm:h-12 border-gray-300 focus:border-indigo-500 focus:ring-indigo-500 text-sm sm:text-base"
                          placeholder="••••••••"
                          required
                          minLength={6}
                        />
                      </div>
                      <div className="space-y-2">
                        <Label htmlFor="confirm-password" className="text-gray-700 font-medium text-sm sm:text-base">
                          Confirmar Contraseña
                        </Label>
                        <Input
                          id="confirm-password"
                          type="password"
                          value={signupData.confirmPassword}
                          onChange={(e) => setSignupData({ ...signupData, confirmPassword: e.target.value })}
                          className="h-10 sm:h-12 border-gray-300 focus:border-indigo-500 focus:ring-indigo-500 text-sm sm:text-base"
                          placeholder="••••••••"
                          required
                          minLength={6}
                        />
                      </div>
                    </div>
                    <div className="space-y-2">
                      <Label htmlFor="role" className="text-gray-700 font-medium text-sm sm:text-base">
                        Rol en la Empresa
                      </Label>
                      <Select
                        value={signupData.role}
                        onValueChange={(value) => setSignupData({ ...signupData, role: value })}
                      >
                        <SelectTrigger className="h-10 sm:h-12 border-gray-300 focus:border-indigo-500 focus:ring-indigo-500 text-sm sm:text-base">
                          <SelectValue placeholder="Selecciona tu rol" />
                        </SelectTrigger>
                        <SelectContent>
                          {[
                            "oficial_almacen",
                            "transportista",
                            "encargado_obra",
                            "operario_maquinaria",
                            "peon_logistica",
                          ].map((role) => {
                            const roleColor = getRoleColor(role)
                            return (
                              <SelectItem key={role} value={role}>
                                <div className="flex items-center gap-2 sm:gap-3">
                                  <div className={`p-1 rounded ${roleColor.css}`}>{getRoleIcon(role)}</div>
                                  <div>
                                    <div className="font-medium text-sm sm:text-base">{getRoleLabel(role)}</div>
                                    <div className="text-xs text-gray-500 hidden sm:block">
                                      {getRoleDescription(role)}
                                    </div>
                                  </div>
                                </div>
                              </SelectItem>
                            )
                          })}
                        </SelectContent>
                      </Select>
                    </div>
                    {error && (
                      <Alert variant="destructive" className="border-red-200 bg-red-50">
                        <AlertDescription className="text-red-700 text-sm">{error}</AlertDescription>
                      </Alert>
                    )}
                    {success && (
                      <Alert className="border-green-200 bg-green-50">
                        <CheckCircle className="h-4 w-4 text-green-600" />
                        <AlertDescription className="text-green-700 text-sm">{success}</AlertDescription>
                      </Alert>
                    )}
                    <Button
                      type="submit"
                      className="w-full h-10 sm:h-12 bg-purple-600 hover:bg-purple-700 text-white font-medium text-sm sm:text-base"
                      disabled={loading || !signupData.role}
                    >
                      {loading ? (
                        <>
                          <Loader2 className="mr-2 h-4 w-4 sm:h-5 sm:w-5 animate-spin" />
                          Creando cuenta...
                        </>
                      ) : (
                        "Crear Cuenta"
                      )}
                    </Button>
                  </form>
                </TabsContent>
              </Tabs>
            </CardContent>
          </Card>
        </div>

        {/* Panel de Usuarios de Ejemplo - Responsive */}
        <div className="space-y-4 sm:space-y-6">
          <Card className="shadow-xl border-0 bg-white/80 backdrop-blur-sm">
            <CardHeader className="p-4 sm:p-6">
              <CardTitle className="text-lg sm:text-xl font-bold flex items-center gap-2">
                <Users className="h-4 w-4 sm:h-5 sm:w-5 text-blue-600" />
                Usuarios de Prueba
              </CardTitle>
              <CardDescription className="text-sm sm:text-base">
                Accede con estas cuentas para explorar el sistema
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-3 sm:space-y-4 p-4 sm:p-6">
              {[
                { role: "oficial_almacen", email: "admin@logistica.com", password: "admin123", name: "Administrador" },
                {
                  role: "transportista",
                  email: "transportista1@logistica.com",
                  password: "trans123",
                  name: "Carlos Transportista",
                },
                {
                  role: "encargado_obra",
                  email: "encargado1@logistica.com",
                  password: "obra123",
                  name: "Luis Encargado",
                },
                {
                  role: "operario_maquinaria",
                  email: "operario1@logistica.com",
                  password: "maq123",
                  name: "Roberto Operario",
                },
                { role: "peon_logistica", email: "peon1@logistica.com", password: "log123", name: "Pedro Peón" },
              ].map((user, index) => {
                const roleColor = getRoleColor(user.role)
                return (
                  <div
                    key={index}
                    className="p-3 sm:p-4 border rounded-xl bg-gradient-to-r from-gray-50 to-gray-100 hover:from-gray-100 hover:to-gray-200 transition-all duration-200"
                  >
                    <div className="flex items-center gap-2 sm:gap-3 mb-2 sm:mb-3">
                      <div className={`p-1.5 sm:p-2 rounded-lg ${roleColor.css}`}>{getRoleIcon(user.role)}</div>
                      <div className="min-w-0 flex-1">
                        <div className="font-semibold text-gray-900 text-sm sm:text-base truncate">{user.name}</div>
                        <Badge variant="secondary" className="text-xs">
                          {getRoleLabel(user.role)}
                        </Badge>
                      </div>
                    </div>
                    <div className="space-y-1 text-xs sm:text-sm">
                      <div className="flex items-center gap-2">
                        <span className="font-medium text-gray-600">Email:</span>
                        <code className="bg-gray-200 px-1.5 py-0.5 rounded text-xs flex-1 truncate">{user.email}</code>
                      </div>
                      <div className="flex items-center gap-2">
                        <span className="font-medium text-gray-600">Contraseña:</span>
                        <code className="bg-gray-200 px-1.5 py-0.5 rounded text-xs">{user.password}</code>
                      </div>
                    </div>
                    <p className="text-xs text-gray-500 mt-2 hidden sm:block">{getRoleDescription(user.role)}</p>
                  </div>
                )
              })}
            </CardContent>
          </Card>

          <Card className="shadow-xl border-0 bg-gradient-to-br from-blue-50 to-indigo-50">
            <CardContent className="pt-4 sm:pt-6 p-4 sm:p-6">
              <div className="text-center">
                <div className="p-2 sm:p-3 bg-gradient-to-r from-blue-600 to-indigo-600 rounded-full w-fit mx-auto mb-3 sm:mb-4">
                  <CheckCircle className="h-4 w-4 sm:h-6 sm:w-6 text-white" />
                </div>
                <h3 className="font-semibold text-gray-900 mb-2 text-sm sm:text-base">¿Nuevo en el sistema?</h3>
                <p className="text-xs sm:text-sm text-gray-600 mb-3 sm:mb-4">
                  Crea tu propia cuenta usando el formulario de registro para acceder con tu rol específico.
                </p>
                <div className="flex items-center justify-center gap-2 text-xs text-gray-500">
                  <Zap className="h-3 w-3" />
                  <span>Configuración automática de permisos</span>
                </div>
              </div>
            </CardContent>
          </Card>
        </div>
      </div>

      {/* Footer - Responsive */}
      <div className="mt-8 sm:mt-12 text-center text-xs sm:text-sm text-gray-500 px-4">
        <p>© 2025 In-Situ Solutions. Todos los derechos reservados.</p>
      </div>
    </div>
  )
}
