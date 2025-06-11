"use client"

import type React from "react"

import { useState } from "react"
import { supabase, type WarehouseRequest, type UserProfile, type WorkSite } from "@/lib/supabase"
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
import { Plus, Package, Clock, CheckCircle } from "lucide-react"
import { useEffect } from "react"

interface WarehouseRequestManagerProps {
  requests: WarehouseRequest[]
  userProfile: UserProfile
  onUpdate: () => void
}

export function WarehouseRequestManager({ requests, userProfile, onUpdate }: WarehouseRequestManagerProps) {
  const { toast } = useToast()
  const [showCreateDialog, setShowCreateDialog] = useState(false)
  const [loading, setLoading] = useState(false)
  const [workSites, setWorkSites] = useState<WorkSite[]>([])
  const [newRequest, setNewRequest] = useState({
    title: "",
    description: "",
    quantity: "",
    work_site_id: "",
  })

  useEffect(() => {
    fetchWorkSites()
  }, [userProfile])

  const fetchWorkSites = async () => {
    try {
      // Con políticas V22, solo podemos ver nuestras propias obras
      if (userProfile.role === "encargado_obra") {
        const { data, error } = await supabase.from("work_sites").select("*").eq("site_manager_id", userProfile.id)

        if (error) {
          console.error("Error fetching work sites:", error)
          setWorkSites([])
        } else {
          setWorkSites(data || [])
        }
      }
    } catch (error) {
      console.error("Error fetching work sites:", error)
      setWorkSites([])
    }
  }

  const handleCreateRequest = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true)

    try {
      // Con políticas V22, solo encargados de obra pueden crear solicitudes
      const { error } = await supabase.from("warehouse_requests").insert({
        title: newRequest.title,
        description: newRequest.description,
        quantity: Number.parseInt(newRequest.quantity),
        work_site_id: newRequest.work_site_id || null,
        requested_by: userProfile.id,
      })

      if (error) throw error

      toast({
        title: "Solicitud creada",
        description: "La solicitud de almacén ha sido creada exitosamente",
      })

      setNewRequest({
        title: "",
        description: "",
        quantity: "",
        work_site_id: "",
      })
      setShowCreateDialog(false)
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

  const handleStatusUpdate = async (requestId: string, newStatus: string) => {
    try {
      // Con políticas V22, solo oficial_almacen puede actualizar solicitudes
      const { error } = await supabase.from("warehouse_requests").update({ status: newStatus }).eq("id", requestId)

      if (error) throw error

      toast({
        title: "Estado actualizado",
        description: "El estado de la solicitud ha sido actualizado",
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

  const getStatusIcon = (status: string) => {
    switch (status) {
      case "pending":
        return <Clock className="h-4 w-4" />
      case "approved":
        return <CheckCircle className="h-4 w-4" />
      case "completed":
        return <Package className="h-4 w-4" />
      default:
        return <Clock className="h-4 w-4" />
    }
  }

  const getStatusColor = (status: string) => {
    switch (status) {
      case "pending":
        return "bg-yellow-100 text-yellow-800"
      case "approved":
        return "bg-blue-100 text-blue-800"
      case "completed":
        return "bg-green-100 text-green-800"
      case "rejected":
        return "bg-red-100 text-red-800"
      default:
        return "bg-gray-100 text-gray-800"
    }
  }

  const getStatusLabel = (status: string) => {
    switch (status) {
      case "pending":
        return "Pendiente"
      case "approved":
        return "Aprobada"
      case "completed":
        return "Completada"
      case "rejected":
        return "Rechazada"
      default:
        return status
    }
  }

  // Con políticas V22, verificar permisos
  const canCreateRequest = userProfile.role === "encargado_obra"
  const canUpdateRequest = userProfile.role === "oficial_almacen"

  return (
    <div className="space-y-4">
      <div className="flex justify-between items-center">
        <div>
          <h2 className="text-lg font-semibold">Solicitudes de Almacén</h2>
          <p className="text-sm text-muted-foreground">
            {userProfile.role === "encargado_obra"
              ? "Gestiona las solicitudes de materiales y equipos"
              : "Revisa y aprueba solicitudes de almacén"}
          </p>
        </div>
        {canCreateRequest && (
          <Dialog open={showCreateDialog} onOpenChange={setShowCreateDialog}>
            <DialogTrigger asChild>
              <Button>
                <Plus className="h-4 w-4 mr-2" />
                Nueva Solicitud
              </Button>
            </DialogTrigger>
            <DialogContent>
              <DialogHeader>
                <DialogTitle>Crear Solicitud de Almacén</DialogTitle>
                <DialogDescription>Completa los detalles de lo que necesitas del almacén</DialogDescription>
              </DialogHeader>
              <form onSubmit={handleCreateRequest} className="space-y-4">
                <div className="space-y-2">
                  <Label htmlFor="title">Título de la Solicitud</Label>
                  <Input
                    id="title"
                    value={newRequest.title}
                    onChange={(e) => setNewRequest({ ...newRequest, title: e.target.value })}
                    placeholder="ej. Materiales para construcción"
                    required
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="description">Descripción</Label>
                  <Textarea
                    id="description"
                    value={newRequest.description}
                    onChange={(e) => setNewRequest({ ...newRequest, description: e.target.value })}
                    placeholder="Detalla qué materiales o equipos necesitas"
                    rows={3}
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="quantity">Cantidad</Label>
                  <Input
                    id="quantity"
                    type="number"
                    min="1"
                    value={newRequest.quantity}
                    onChange={(e) => setNewRequest({ ...newRequest, quantity: e.target.value })}
                    required
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="work_site">Obra (Opcional)</Label>
                  <Select
                    value={newRequest.work_site_id}
                    onValueChange={(value) => setNewRequest({ ...newRequest, work_site_id: value })}
                  >
                    <SelectTrigger>
                      <SelectValue placeholder="Selecciona una obra" />
                    </SelectTrigger>
                    <SelectContent>
                      {workSites.map((site) => (
                        <SelectItem key={site.id} value={site.id}>
                          {site.name}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
                <Button type="submit" disabled={loading} className="w-full">
                  {loading ? "Creando..." : "Crear Solicitud"}
                </Button>
              </form>
            </DialogContent>
          </Dialog>
        )}
      </div>

      <div className="grid gap-4">
        {requests.length === 0 ? (
          <Card>
            <CardContent className="pt-6">
              <div className="text-center py-8">
                <Package className="mx-auto h-12 w-12 text-gray-400" />
                <h3 className="mt-2 text-sm font-medium text-gray-900">No hay solicitudes</h3>
                <p className="mt-1 text-sm text-gray-500">
                  {canCreateRequest
                    ? "Comienza creando una nueva solicitud de almacén."
                    : "No hay solicitudes pendientes de revisión."}
                </p>
              </div>
            </CardContent>
          </Card>
        ) : (
          requests.map((request) => (
            <Card key={request.id}>
              <CardHeader>
                <div className="flex justify-between items-start">
                  <div>
                    <CardTitle className="text-lg">{request.title}</CardTitle>
                    <CardDescription className="mt-1">{request.description}</CardDescription>
                  </div>
                  <Badge className={getStatusColor(request.status)}>
                    <div className="flex items-center gap-1">
                      {getStatusIcon(request.status)}
                      {getStatusLabel(request.status)}
                    </div>
                  </Badge>
                </div>
              </CardHeader>
              <CardContent>
                <div className="space-y-2">
                  <p className="text-sm">
                    <strong>Cantidad:</strong> {request.quantity}
                  </p>
                  <p className="text-sm">
                    <strong>Solicitado:</strong> {new Date(request.created_at).toLocaleString()}
                  </p>
                </div>

                {canUpdateRequest && request.status === "pending" && (
                  <div className="flex gap-2 mt-4">
                    <Button size="sm" variant="outline" onClick={() => handleStatusUpdate(request.id, "approved")}>
                      Aprobar
                    </Button>
                    <Button size="sm" variant="destructive" onClick={() => handleStatusUpdate(request.id, "rejected")}>
                      Rechazar
                    </Button>
                  </div>
                )}

                {canUpdateRequest && request.status === "approved" && (
                  <div className="flex gap-2 mt-4">
                    <Button size="sm" onClick={() => handleStatusUpdate(request.id, "completed")}>
                      Marcar como Completada
                    </Button>
                  </div>
                )}
              </CardContent>
            </Card>
          ))
        )}
      </div>
    </div>
  )
}
