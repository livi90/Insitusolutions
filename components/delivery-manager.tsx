"use client"

import type React from "react"

import { useState, useEffect } from "react"
import { supabase, type Delivery, type UserProfile } from "@/lib/supabase"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Textarea } from "@/components/ui/textarea"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog"
import { useToast } from "@/hooks/use-toast"
import { Plus, Package, Clock, CheckCircle, Truck, Calendar, MapPin, Users, RefreshCw } from "lucide-react"
import { theme, getStatusColor } from "@/lib/theme"
import { WorkerSelector } from "./worker-selector"

interface DeliveryManagerProps {
  deliveries: Delivery[]
  userProfile: UserProfile
  onUpdate: () => void
}

export function DeliveryManager({ deliveries, userProfile, onUpdate }: DeliveryManagerProps) {
  const { toast } = useToast()
  const [showCreateDialog, setShowCreateDialog] = useState(false)
  const [showWorkerSelector, setShowWorkerSelector] = useState(false)
  const [selectedDeliveryId, setSelectedDeliveryId] = useState<string | null>(null)
  const [loading, setLoading] = useState(false)
  const [transporters, setTransporters] = useState<UserProfile[]>([])
  const [loadingTransporters, setLoadingTransporters] = useState(false)
  const [newDelivery, setNewDelivery] = useState({
    title: "",
    description: "",
    delivery_address: "",
    scheduled_date: "",
  })

  const roleColor = theme.roles[userProfile.role as keyof typeof theme.roles] || theme.roles.transportista

  const fetchTransporters = async () => {
    setLoadingTransporters(true)
    try {
      console.log("Fetching transporters...")

      // Intentar obtener transportistas
      const { data: transportersData, error } = await supabase
        .from("user_profiles")
        .select("*")
        .eq("role", "transportista")
        .order("full_name")

      if (error) {
        console.error("Error fetching transporters:", error)
        throw error
      }

      console.log("Transporters found:", transportersData)
      setTransporters(transportersData || [])

      if (!transportersData || transportersData.length === 0) {
        toast({
          title: "Sin transportistas",
          description:
            "No se encontraron transportistas disponibles. Verifica que existan usuarios con rol 'transportista'.",
          variant: "destructive",
        })
      }
    } catch (error: any) {
      console.error("Error fetching transporters:", error)
      toast({
        title: "Error",
        description: `Error al cargar transportistas: ${error.message}`,
        variant: "destructive",
      })
    } finally {
      setLoadingTransporters(false)
    }
  }

  // Cargar transportistas al montar el componente
  useEffect(() => {
    fetchTransporters()
  }, [])

  const handleCreateDelivery = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true)

    try {
      const { data: deliveryData, error } = await supabase
        .from("deliveries")
        .insert({
          ...newDelivery,
          created_by: userProfile.id,
          scheduled_date: newDelivery.scheduled_date || null,
        })
        .select()
        .single()

      if (error) throw error

      toast({
        title: "Entrega creada",
        description: "La entrega ha sido creada exitosamente",
      })

      setNewDelivery({
        title: "",
        description: "",
        delivery_address: "",
        scheduled_date: "",
      })
      setShowCreateDialog(false)

      // Si es oficial de almacén o encargado de obra, preguntar si quiere asignar trabajadores
      if (userProfile.role === "oficial_almacen" || userProfile.role === "encargado_obra") {
        setSelectedDeliveryId(deliveryData.id)
        setShowWorkerSelector(true)
      }

      onUpdate()
    } catch (error: any) {
      toast({
        title: "Error",
        description: error.message,
        variant: "destructive",
      })
    } finally {
      setLoading(false)
    }
  }

  const handleStatusUpdate = async (deliveryId: string, newStatus: string, assignedTo?: string) => {
    try {
      const updateData: any = { status: newStatus }
      if (assignedTo) {
        updateData.assigned_to = assignedTo
      }
      if (newStatus === "completed") {
        updateData.completed_date = new Date().toISOString()
      }

      const { error } = await supabase.from("deliveries").update(updateData).eq("id", deliveryId)

      if (error) throw error

      toast({
        title: "Estado actualizado",
        description: "El estado de la entrega ha sido actualizado",
      })
      onUpdate()
    } catch (error: any) {
      toast({
        title: "Error",
        description: error.message,
        variant: "destructive",
      })
    }
  }

  const handleAssignWorkers = (deliveryId: string) => {
    setSelectedDeliveryId(deliveryId)
    setShowWorkerSelector(true)
  }

  const handleWorkersAssigned = () => {
    toast({
      title: "Trabajadores asignados",
      description: "Los trabajadores han sido asignados exitosamente a la entrega",
    })
    onUpdate()
  }

  const getStatusIcon = (status: string) => {
    switch (status) {
      case "pending":
        return <Clock className="h-4 w-4" />
      case "assigned":
        return <Package className="h-4 w-4" />
      case "in_transit":
        return <Truck className="h-4 w-4" />
      case "delivered":
      case "completed":
        return <CheckCircle className="h-4 w-4" />
      default:
        return <Clock className="h-4 w-4" />
    }
  }

  const getStatusLabel = (status: string) => {
    switch (status) {
      case "pending":
        return "Pendiente"
      case "assigned":
        return "Asignada"
      case "in_transit":
        return "En Tránsito"
      case "delivered":
        return "Entregada"
      case "completed":
        return "Completada"
      default:
        return status
    }
  }

  const canCreateDelivery = ["oficial_almacen", "encargado_obra"].includes(userProfile.role)
  const canAssignDelivery = userProfile.role === "oficial_almacen" && userProfile.permission_level === "admin"
  const canAssignWorkers = ["oficial_almacen", "encargado_obra"].includes(userProfile.role)

  return (
    <div className="space-y-4">
      <div className="flex justify-between items-center">
        <div>
          <h2 className="text-2xl font-bold text-gray-900">Gestión de Entregas</h2>
          <p className="text-gray-600">Administra las entregas y su estado</p>
        </div>
        <div className="flex gap-2">
          <Button variant="outline" onClick={fetchTransporters} disabled={loadingTransporters} className="gap-2">
            <RefreshCw className={`h-4 w-4 ${loadingTransporters ? "animate-spin" : ""}`} />
            Actualizar Usuarios
          </Button>
          {canCreateDelivery && (
            <Dialog open={showCreateDialog} onOpenChange={setShowCreateDialog}>
              <DialogTrigger asChild>
                <Button
                  className="text-white"
                  style={{
                    background: `linear-gradient(to right, ${roleColor.primary}, ${roleColor.secondary})`,
                  }}
                >
                  <Plus className="h-4 w-4 mr-2" />
                  Nueva Entrega
                </Button>
              </DialogTrigger>
              <DialogContent className="max-w-md">
                <DialogHeader>
                  <DialogTitle>Crear Nueva Entrega</DialogTitle>
                  <DialogDescription>Completa los detalles de la nueva entrega</DialogDescription>
                </DialogHeader>
                <form onSubmit={handleCreateDelivery} className="space-y-4">
                  <div className="space-y-2">
                    <Label htmlFor="title">Título</Label>
                    <Input
                      id="title"
                      value={newDelivery.title}
                      onChange={(e) => setNewDelivery({ ...newDelivery, title: e.target.value })}
                      placeholder="ej. Entrega de materiales para obra"
                      required
                    />
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="description">Descripción</Label>
                    <Textarea
                      id="description"
                      value={newDelivery.description}
                      onChange={(e) => setNewDelivery({ ...newDelivery, description: e.target.value })}
                      placeholder="ej. Cemento, varillas y grúa para construcción"
                      rows={3}
                    />
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="address">Dirección de Entrega</Label>
                    <Input
                      id="address"
                      value={newDelivery.delivery_address}
                      onChange={(e) => setNewDelivery({ ...newDelivery, delivery_address: e.target.value })}
                      placeholder="ej. Av. Principal 123, Lima"
                      required
                    />
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="scheduled_date">Fecha Programada (Opcional)</Label>
                    <Input
                      id="scheduled_date"
                      type="datetime-local"
                      value={newDelivery.scheduled_date}
                      onChange={(e) => setNewDelivery({ ...newDelivery, scheduled_date: e.target.value })}
                    />
                  </div>
                  <Button
                    type="submit"
                    disabled={loading}
                    className="w-full text-white"
                    style={{
                      background: `linear-gradient(to right, ${roleColor.primary}, ${roleColor.secondary})`,
                    }}
                  >
                    {loading ? "Creando..." : "Crear Entrega"}
                  </Button>
                </form>
              </DialogContent>
            </Dialog>
          )}
        </div>
      </div>

      {/* Mostrar información de usuarios disponibles */}
      {canAssignDelivery && (
        <Card className="bg-blue-50 border-blue-200">
          <CardContent className="pt-4">
            <div className="flex items-center gap-2 text-sm text-blue-800">
              <Users className="h-4 w-4" />
              <span>
                Transportistas disponibles: {transporters.length} |
                {transporters.length > 0 && ` ${transporters.map((t) => t.full_name).join(", ")}`}
              </span>
            </div>
          </CardContent>
        </Card>
      )}

      {/* Dialog para seleccionar trabajadores */}
      <Dialog open={showWorkerSelector} onOpenChange={setShowWorkerSelector}>
        <DialogContent className="max-w-4xl max-h-[80vh] overflow-hidden">
          <DialogHeader>
            <DialogTitle>Asignar Trabajadores a la Entrega</DialogTitle>
            <DialogDescription>
              Selecciona los operarios y personal de logística que participarán en esta entrega
            </DialogDescription>
          </DialogHeader>
          {selectedDeliveryId && (
            <WorkerSelector
              deliveryId={selectedDeliveryId}
              onWorkersAssigned={handleWorkersAssigned}
              onClose={() => setShowWorkerSelector(false)}
            />
          )}
        </DialogContent>
      </Dialog>

      <div className="grid gap-4">
        {deliveries.length === 0 ? (
          <Card className="border-0 shadow-md">
            <CardContent className="pt-6">
              <div className="text-center py-8">
                <div
                  className={`p-4 rounded-full w-fit mx-auto mb-4 bg-gradient-to-r ${roleColor.gradient} text-white`}
                >
                  <Package className="h-8 w-8" />
                </div>
                <h3 className="mt-2 text-lg font-medium text-gray-900">No hay entregas</h3>
                <p className="mt-1 text-gray-500">
                  {canCreateDelivery ? "Comienza creando una nueva entrega." : "No tienes entregas asignadas."}
                </p>
              </div>
            </CardContent>
          </Card>
        ) : (
          deliveries.map((delivery) => {
            const statusColor = getStatusColor(delivery.status)

            return (
              <Card key={delivery.id} className="border-0 shadow-md hover:shadow-lg transition-shadow">
                <CardHeader>
                  <div className="flex justify-between items-start">
                    <div>
                      <CardTitle className="text-lg">{delivery.title}</CardTitle>
                      <CardDescription className="mt-1">{delivery.description}</CardDescription>
                    </div>
                    <Badge className={`${statusColor.bg} ${statusColor.text} border ${statusColor.border}`}>
                      <div className="flex items-center gap-1">
                        {getStatusIcon(delivery.status)}
                        {getStatusLabel(delivery.status)}
                      </div>
                    </Badge>
                  </div>
                </CardHeader>
                <CardContent>
                  <div className="space-y-2">
                    <p className="text-sm flex items-center gap-1">
                      <MapPin className="h-4 w-4 text-gray-500" />
                      <strong>Dirección:</strong> {delivery.delivery_address}
                    </p>
                    {delivery.scheduled_date && (
                      <p className="text-sm flex items-center gap-1">
                        <Calendar className="h-4 w-4 text-gray-500" />
                        <strong>Fecha programada:</strong> {new Date(delivery.scheduled_date).toLocaleString()}
                      </p>
                    )}
                    {delivery.completed_date && (
                      <p className="text-sm flex items-center gap-1">
                        <CheckCircle className="h-4 w-4 text-green-500" />
                        <strong>Completada:</strong> {new Date(delivery.completed_date).toLocaleString()}
                      </p>
                    )}
                  </div>

                  <div className="flex gap-2 mt-4 flex-wrap">
                    {/* Transportista actions */}
                    {userProfile.role === "transportista" && delivery.assigned_to === userProfile.id && (
                      <>
                        {delivery.status === "assigned" && (
                          <Button
                            size="sm"
                            onClick={() => handleStatusUpdate(delivery.id, "in_transit")}
                            className="text-white"
                            style={{
                              background: `linear-gradient(to right, ${roleColor.primary}, ${roleColor.secondary})`,
                            }}
                          >
                            <Truck className="h-4 w-4 mr-2" />
                            Iniciar Transporte
                          </Button>
                        )}
                        {delivery.status === "in_transit" && (
                          <Button
                            size="sm"
                            onClick={() => handleStatusUpdate(delivery.id, "delivered")}
                            className="text-white"
                            style={{
                              background: `linear-gradient(to right, ${roleColor.primary}, ${roleColor.secondary})`,
                            }}
                          >
                            <CheckCircle className="h-4 w-4 mr-2" />
                            Marcar como Entregada
                          </Button>
                        )}
                      </>
                    )}

                    {/* Oficial de almacén actions */}
                    {userProfile.role === "oficial_almacen" && (
                      <>
                        {delivery.status === "pending" && canAssignDelivery && (
                          <div className="flex items-center gap-2">
                            <Select onValueChange={(value) => handleStatusUpdate(delivery.id, "assigned", value)}>
                              <SelectTrigger className="w-[200px]">
                                <SelectValue
                                  placeholder={
                                    loadingTransporters
                                      ? "Cargando..."
                                      : transporters.length === 0
                                        ? "Sin transportistas"
                                        : "Asignar transportista"
                                  }
                                />
                              </SelectTrigger>
                              <SelectContent>
                                {transporters.map((transporter) => (
                                  <SelectItem key={transporter.id} value={transporter.id}>
                                    {transporter.full_name} ({transporter.email})
                                  </SelectItem>
                                ))}
                              </SelectContent>
                            </Select>
                            {transporters.length === 0 && (
                              <Button size="sm" variant="outline" onClick={fetchTransporters}>
                                <RefreshCw className="h-4 w-4" />
                              </Button>
                            )}
                          </div>
                        )}

                        {delivery.status === "delivered" && (
                          <Button
                            size="sm"
                            onClick={() => handleStatusUpdate(delivery.id, "completed")}
                            className="text-white"
                            style={{
                              background: `linear-gradient(to right, ${roleColor.primary}, ${roleColor.secondary})`,
                            }}
                          >
                            <CheckCircle className="h-4 w-4 mr-2" />
                            Completar Entrega
                          </Button>
                        )}
                      </>
                    )}

                    {/* Botón para asignar trabajadores - disponible para oficial de almacén y encargado de obra */}
                    {canAssignWorkers && ["pending", "assigned"].includes(delivery.status) && (
                      <Button
                        size="sm"
                        variant="outline"
                        onClick={() => handleAssignWorkers(delivery.id)}
                        className="gap-2 border-2"
                        style={{
                          borderColor: roleColor.primary,
                          color: roleColor.primary,
                        }}
                      >
                        <Users className="h-4 w-4" />
                        Asignar Trabajadores
                      </Button>
                    )}
                  </div>
                </CardContent>
              </Card>
            )
          })
        )}
      </div>
    </div>
  )
}
