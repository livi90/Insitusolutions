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
import { Plus, Package, Clock, CheckCircle, Truck, Calendar, MapPin, RefreshCw, Users } from "lucide-react"
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
      console.log("Fetching transporters for role:", userProfile.role)

      if (userProfile.role === "oficial_almacen") {
        // Primero intentar con la función personalizada
        try {
          const { data: functionData, error: functionError } = await supabase.rpc(
            "get_available_workers_for_assignment",
          )

          if (functionError) {
            console.warn("Function call failed, trying direct query:", functionError)
            throw functionError
          }

          // Filtrar solo transportistas de la función
          const transportersFromFunction = functionData?.filter((worker) => worker.role === "transportista") || []

          if (transportersFromFunction.length > 0) {
            console.log("Transporters from function:", transportersFromFunction)
            setTransporters(transportersFromFunction)
            return
          }
        } catch (funcError) {
          console.warn("Function approach failed, trying direct query:", funcError)
        }

        // Si la función falla, intentar consulta directa
        const { data: transportersData, error } = await supabase
          .from("user_profiles")
          .select("*")
          .eq("role", "transportista")
          .order("full_name")

        if (error) {
          console.error("Error fetching transporters:", error)
          setTransporters([])
        } else {
          console.log("Transporters from direct query:", transportersData)
          setTransporters(transportersData || [])
        }
      }
    } catch (error: any) {
      console.error("Error fetching transporters:", error)
      setTransporters([])
      toast({
        title: "Advertencia",
        description: "No se pudieron cargar los transportistas. Verifica los permisos.",
        variant: "destructive",
      })
    } finally {
      setLoadingTransporters(false)
    }
  }

  // Cargar transportistas al montar el componente
  useEffect(() => {
    if (userProfile.role === "oficial_almacen") {
      fetchTransporters()
    }
  }, [userProfile.role])

  const handleCreateDelivery = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true)

    try {
      console.log("Creating delivery:", newDelivery)

      const deliveryData = {
        title: newDelivery.title,
        description: newDelivery.description,
        delivery_address: newDelivery.delivery_address,
        created_by: userProfile.id,
        scheduled_date: newDelivery.scheduled_date || null,
        status: "pending",
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      }

      console.log("Inserting delivery with data:", deliveryData)

      const { data, error } = await supabase.from("deliveries").insert(deliveryData).select().single()

      if (error) {
        console.error("Error creating delivery:", error)
        throw error
      }

      console.log("Delivery created successfully:", data)

      toast({
        title: "Entrega creada",
        description: "La entrega ha sido creada exitosamente. Ahora puedes asignar transportista y personal.",
      })

      setNewDelivery({
        title: "",
        description: "",
        delivery_address: "",
        scheduled_date: "",
      })
      setShowCreateDialog(false)
      onUpdate()
    } catch (error: any) {
      console.error("Error in handleCreateDelivery:", error)
      toast({
        title: "Error",
        description: `Error al crear entrega: ${error.message}`,
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

  const handleAssignTransporter = async (deliveryId: string, transporterId: string) => {
    try {
      console.log("Assigning transporter:", { deliveryId, transporterId })

      // Usar la función personalizada para asignar transportista
      const { data, error } = await supabase.rpc("assign_transporter_to_delivery", {
        delivery_id: deliveryId,
        transporter_id: transporterId,
      })

      if (error) {
        console.error("Error with function, trying direct update:", error)
        // Si la función falla, intentar actualización directa
        await handleStatusUpdate(deliveryId, "assigned", transporterId)
      } else {
        console.log("Transporter assigned successfully via function")
        toast({
          title: "Transportista asignado",
          description: "El transportista ha sido asignado exitosamente",
        })
        onUpdate()
      }
    } catch (error: any) {
      console.error("Error assigning transporter:", error)
      toast({
        title: "Error",
        description: `Error al asignar transportista: ${error.message}`,
        variant: "destructive",
      })
    }
  }

  const handleAssignWorkers = (deliveryId: string) => {
    setSelectedDeliveryId(deliveryId)
    setShowWorkerSelector(true)
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

  // Con políticas V22 restauradas, verificar permisos según el rol
  const canCreateDelivery = userProfile.role === "oficial_almacen"
  const canAssignDelivery = userProfile.role === "oficial_almacen"
  const canAssignWorkers = userProfile.role === "oficial_almacen" || userProfile.role === "encargado_obra"

  return (
    <div className="space-y-4 sm:space-y-6">
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <h2 className="text-lg sm:text-xl font-semibold">Gestión de Entregas</h2>
          <p className="text-sm text-muted-foreground">
            {userProfile.role === "oficial_almacen"
              ? "Administra las entregas, asigna transportistas y personal"
              : userProfile.role === "transportista"
                ? "Entregas asignadas a ti"
                : "Entregas relacionadas con tus obras"}
          </p>
        </div>
        <div className="flex flex-col sm:flex-row gap-2 w-full sm:w-auto">
          <Button variant="outline" size="sm" onClick={onUpdate} className="w-full sm:w-auto">
            <RefreshCw className="h-4 w-4 mr-2" />
            Actualizar
          </Button>
          {canCreateDelivery && (
            <Dialog open={showCreateDialog} onOpenChange={setShowCreateDialog}>
              <DialogTrigger asChild>
                <Button className="w-full sm:w-auto" style={{ backgroundColor: roleColor.primary }}>
                  <Plus className="h-4 w-4 mr-2" />
                  Nueva Entrega
                </Button>
              </DialogTrigger>
              <DialogContent className="max-w-md sm:max-w-lg mx-auto">
                <DialogHeader>
                  <DialogTitle>Crear Nueva Entrega</DialogTitle>
                  <DialogDescription>
                    Completa los detalles de la nueva entrega. Después podrás asignar transportista y personal.
                  </DialogDescription>
                </DialogHeader>
                <form onSubmit={handleCreateDelivery} className="space-y-4">
                  <div className="space-y-2">
                    <Label htmlFor="title">Título</Label>
                    <Input
                      id="title"
                      value={newDelivery.title}
                      onChange={(e) => setNewDelivery({ ...newDelivery, title: e.target.value })}
                      placeholder="ej. Entrega de materiales"
                      required
                    />
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="description">Descripción</Label>
                    <Textarea
                      id="description"
                      value={newDelivery.description}
                      onChange={(e) => setNewDelivery({ ...newDelivery, description: e.target.value })}
                      placeholder="Describe los detalles de la entrega"
                      rows={3}
                    />
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="address">Dirección de Entrega</Label>
                    <Input
                      id="address"
                      value={newDelivery.delivery_address}
                      onChange={(e) => setNewDelivery({ ...newDelivery, delivery_address: e.target.value })}
                      placeholder="Dirección completa de entrega"
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
                  <Button type="submit" disabled={loading} className="w-full">
                    {loading ? "Creando..." : "Crear Entrega"}
                  </Button>
                </form>
              </DialogContent>
            </Dialog>
          )}
        </div>
      </div>

      <div className="grid gap-4 sm:gap-6">
        {deliveries.length === 0 ? (
          <Card>
            <CardContent className="pt-6">
              <div className="text-center py-8">
                <Package className="mx-auto h-12 w-12 text-gray-400" />
                <h3 className="mt-2 text-sm font-medium text-gray-900">No hay entregas</h3>
                <p className="mt-1 text-sm text-gray-500">
                  {canCreateDelivery ? "Comienza creando una nueva entrega." : "No tienes entregas asignadas."}
                </p>
              </div>
            </CardContent>
          </Card>
        ) : (
          deliveries.map((delivery) => (
            <Card key={delivery.id} className="hover:shadow-lg transition-shadow">
              <CardHeader className="pb-3">
                <div className="flex flex-col sm:flex-row justify-between items-start gap-3">
                  <div className="min-w-0 flex-1">
                    <CardTitle className="text-base sm:text-lg">{delivery.title}</CardTitle>
                    <CardDescription className="mt-1">{delivery.description}</CardDescription>
                  </div>
                  <Badge className={`${getStatusColor(delivery.status)} flex-shrink-0`}>
                    <div className="flex items-center gap-1">
                      {getStatusIcon(delivery.status)}
                      {getStatusLabel(delivery.status)}
                    </div>
                  </Badge>
                </div>
              </CardHeader>
              <CardContent>
                <div className="space-y-2 sm:space-y-3">
                  <div className="flex items-start gap-2">
                    <MapPin className="h-4 w-4 text-gray-500 mt-0.5 flex-shrink-0" />
                    <p className="text-sm break-words">
                      <strong>Dirección:</strong> {delivery.delivery_address}
                    </p>
                  </div>
                  {delivery.scheduled_date && (
                    <div className="flex items-center gap-2">
                      <Calendar className="h-4 w-4 text-gray-500 flex-shrink-0" />
                      <p className="text-sm">
                        <strong>Fecha programada:</strong> {new Date(delivery.scheduled_date).toLocaleString()}
                      </p>
                    </div>
                  )}
                  {delivery.completed_date && (
                    <div className="flex items-center gap-2">
                      <CheckCircle className="h-4 w-4 text-green-500 flex-shrink-0" />
                      <p className="text-sm">
                        <strong>Completada:</strong> {new Date(delivery.completed_date).toLocaleString()}
                      </p>
                    </div>
                  )}
                </div>

                <div className="flex flex-col sm:flex-row gap-2 mt-4">
                  {/* Transportista actions */}
                  {userProfile.role === "transportista" && delivery.assigned_to === userProfile.id && (
                    <>
                      {delivery.status === "assigned" && (
                        <Button
                          size="sm"
                          onClick={() => handleStatusUpdate(delivery.id, "in_transit")}
                          className="w-full sm:w-auto"
                        >
                          <Truck className="h-4 w-4 mr-2" />
                          Iniciar Transporte
                        </Button>
                      )}
                      {delivery.status === "in_transit" && (
                        <Button
                          size="sm"
                          onClick={() => handleStatusUpdate(delivery.id, "delivered")}
                          className="w-full sm:w-auto"
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
                        <div className="flex flex-col sm:flex-row gap-2">
                          {/* Asignar transportista */}
                          {transporters.length > 0 ? (
                            <Select
                              onValueChange={(value) => handleAssignTransporter(delivery.id, value)}
                              disabled={loadingTransporters}
                            >
                              <SelectTrigger className="w-full sm:w-[200px]">
                                <SelectValue
                                  placeholder={loadingTransporters ? "Cargando..." : "Asignar transportista"}
                                />
                              </SelectTrigger>
                              <SelectContent>
                                {transporters.map((transporter) => (
                                  <SelectItem key={transporter.id} value={transporter.id}>
                                    <div className="flex items-center gap-2">
                                      <Truck className="h-4 w-4" />
                                      {transporter.full_name}
                                    </div>
                                  </SelectItem>
                                ))}
                              </SelectContent>
                            </Select>
                          ) : (
                            <Button
                              size="sm"
                              variant="outline"
                              onClick={fetchTransporters}
                              disabled={loadingTransporters}
                              className="w-full sm:w-auto"
                            >
                              <RefreshCw className="h-4 w-4 mr-2" />
                              {loadingTransporters ? "Cargando..." : "Cargar Transportistas"}
                            </Button>
                          )}

                          {/* Asignar personal */}
                          <Button
                            size="sm"
                            variant="outline"
                            onClick={() => handleAssignWorkers(delivery.id)}
                            className="w-full sm:w-auto"
                          >
                            <Users className="h-4 w-4 mr-2" />
                            Asignar Personal
                          </Button>
                        </div>
                      )}
                      {delivery.status === "delivered" && (
                        <Button
                          size="sm"
                          onClick={() => handleStatusUpdate(delivery.id, "completed")}
                          className="w-full sm:w-auto"
                        >
                          <CheckCircle className="h-4 w-4 mr-2" />
                          Completar Entrega
                        </Button>
                      )}
                    </>
                  )}

                  {/* Asignar trabajadores - disponible para encargado de obra */}
                  {userProfile.role === "encargado_obra" && canAssignWorkers && delivery.status === "pending" && (
                    <Button
                      size="sm"
                      variant="outline"
                      onClick={() => handleAssignWorkers(delivery.id)}
                      className="w-full sm:w-auto"
                    >
                      <Users className="h-4 w-4 mr-2" />
                      Asignar Personal
                    </Button>
                  )}
                </div>
              </CardContent>
            </Card>
          ))
        )}
      </div>

      {/* Worker Selector Dialog */}
      <WorkerSelector
        open={showWorkerSelector}
        onOpenChange={setShowWorkerSelector}
        deliveryId={selectedDeliveryId}
        userProfile={userProfile}
        onWorkersAssigned={onUpdate}
      />
    </div>
  )
}
