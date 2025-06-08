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
import { Plus, Package, Clock, CheckCircle, Upload, X, Eye } from "lucide-react"
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
  const [uploadingImage, setUploadingImage] = useState(false)
  const [workSites, setWorkSites] = useState<WorkSite[]>([])
  const [selectedImage, setSelectedImage] = useState<File | null>(null)
  const [imagePreview, setImagePreview] = useState<string | null>(null)
  const [showImageModal, setShowImageModal] = useState<string | null>(null)
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
      const { data, error } = await supabase.from("work_sites").select("*").eq("site_manager_id", userProfile.id)

      if (error) throw error
      setWorkSites(data || [])
    } catch (error) {
      console.error("Error fetching work sites:", error)
    }
  }

  const handleImageSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (file) {
      // Validar tipo de archivo
      if (!file.type.startsWith("image/")) {
        toast({
          title: "Error",
          description: "Por favor selecciona un archivo de imagen válido",
          variant: "destructive",
        })
        return
      }

      // Validar tamaño (máximo 5MB)
      if (file.size > 5 * 1024 * 1024) {
        toast({
          title: "Error",
          description: "La imagen debe ser menor a 5MB",
          variant: "destructive",
        })
        return
      }

      setSelectedImage(file)

      // Crear preview
      const reader = new FileReader()
      reader.onload = (e) => {
        setImagePreview(e.target?.result as string)
      }
      reader.readAsDataURL(file)
    }
  }

  const uploadImage = async (file: File): Promise<string | null> => {
    try {
      setUploadingImage(true)

      // Generar nombre único para el archivo
      const fileExt = file.name.split(".").pop()
      const fileName = `${Date.now()}-${Math.random().toString(36).substring(2)}.${fileExt}`
      const filePath = `warehouse-requests/${fileName}`

      // Subir archivo a Supabase Storage
      const { data, error } = await supabase.storage.from("warehouse-images").upload(filePath, file)

      if (error) {
        console.error("Error uploading image:", error)
        return null
      }

      // Obtener URL pública
      const {
        data: { publicUrl },
      } = supabase.storage.from("warehouse-images").getPublicUrl(filePath)

      return publicUrl
    } catch (error) {
      console.error("Error uploading image:", error)
      return null
    } finally {
      setUploadingImage(false)
    }
  }

  const handleCreateRequest = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true)

    try {
      let imageUrl = null

      // Subir imagen si hay una seleccionada
      if (selectedImage) {
        imageUrl = await uploadImage(selectedImage)
        if (!imageUrl) {
          toast({
            title: "Error",
            description: "No se pudo subir la imagen. Intenta de nuevo.",
            variant: "destructive",
          })
          setLoading(false)
          return
        }
      }

      const { error } = await supabase.from("warehouse_requests").insert({
        title: newRequest.title,
        description: newRequest.description,
        quantity: Number.parseInt(newRequest.quantity),
        work_site_id: newRequest.work_site_id || null,
        requested_by: userProfile.id,
        image_url: imageUrl,
      })

      if (error) throw error

      toast({
        title: "Solicitud creada",
        description: "La solicitud de almacén ha sido creada exitosamente",
      })

      // Limpiar formulario
      setNewRequest({
        title: "",
        description: "",
        quantity: "",
        work_site_id: "",
      })
      setSelectedImage(null)
      setImagePreview(null)
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

  const removeSelectedImage = () => {
    setSelectedImage(null)
    setImagePreview(null)
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

  return (
    <div className="space-y-4">
      <div className="flex justify-between items-center">
        <div>
          <h2 className="text-lg font-semibold">Solicitudes de Almacén</h2>
          <p className="text-sm text-muted-foreground">Gestiona las solicitudes de materiales y equipos</p>
        </div>
        {userProfile.role === "encargado_obra" && (
          <Dialog open={showCreateDialog} onOpenChange={setShowCreateDialog}>
            <DialogTrigger asChild>
              <Button>
                <Plus className="h-4 w-4 mr-2" />
                Nueva Solicitud
              </Button>
            </DialogTrigger>
            <DialogContent className="max-w-md max-h-[90vh] overflow-y-auto">
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

                {/* Sección de imagen */}
                <div className="space-y-2">
                  <Label htmlFor="image">Imagen (Opcional)</Label>
                  <div className="space-y-3">
                    {!imagePreview ? (
                      <div className="border-2 border-dashed border-gray-300 rounded-lg p-4 text-center">
                        <Upload className="mx-auto h-8 w-8 text-gray-400 mb-2" />
                        <p className="text-sm text-gray-600 mb-2">Adjunta una imagen de referencia</p>
                        <Input
                          id="image"
                          type="file"
                          accept="image/*"
                          onChange={handleImageSelect}
                          className="hidden"
                        />
                        <Button
                          type="button"
                          variant="outline"
                          size="sm"
                          onClick={() => document.getElementById("image")?.click()}
                        >
                          Seleccionar Imagen
                        </Button>
                        <p className="text-xs text-gray-500 mt-1">Máximo 5MB - JPG, PNG, GIF</p>
                      </div>
                    ) : (
                      <div className="relative">
                        <img
                          src={imagePreview || "/placeholder.svg"}
                          alt="Preview"
                          className="w-full h-32 object-cover rounded-lg border"
                        />
                        <Button
                          type="button"
                          variant="destructive"
                          size="sm"
                          className="absolute top-2 right-2"
                          onClick={removeSelectedImage}
                        >
                          <X className="h-4 w-4" />
                        </Button>
                      </div>
                    )}
                  </div>
                </div>

                <Button type="submit" disabled={loading || uploadingImage} className="w-full">
                  {loading ? "Creando..." : uploadingImage ? "Subiendo imagen..." : "Crear Solicitud"}
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
                  {userProfile.role === "encargado_obra"
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
                <div className="space-y-3">
                  <div className="grid grid-cols-2 gap-4 text-sm">
                    <p>
                      <strong>Cantidad:</strong> {request.quantity}
                    </p>
                    <p>
                      <strong>Solicitado:</strong> {new Date(request.created_at).toLocaleDateString()}
                    </p>
                  </div>

                  {/* Mostrar imagen si existe */}
                  {request.image_url && (
                    <div className="space-y-2">
                      <Label className="text-sm font-medium">Imagen adjunta:</Label>
                      <div className="relative inline-block">
                        <img
                          src={request.image_url || "/placeholder.svg"}
                          alt="Imagen de la solicitud"
                          className="w-24 h-24 object-cover rounded-lg border cursor-pointer hover:opacity-80 transition-opacity"
                          onClick={() => setShowImageModal(request.image_url!)}
                        />
                        <Button
                          variant="secondary"
                          size="sm"
                          className="absolute -top-2 -right-2 h-6 w-6 rounded-full p-0"
                          onClick={() => setShowImageModal(request.image_url!)}
                        >
                          <Eye className="h-3 w-3" />
                        </Button>
                      </div>
                    </div>
                  )}
                </div>

                {userProfile.role === "oficial_almacen" && request.status === "pending" && (
                  <div className="flex gap-2 mt-4">
                    <Button size="sm" variant="outline" onClick={() => handleStatusUpdate(request.id, "approved")}>
                      Aprobar
                    </Button>
                    <Button size="sm" variant="destructive" onClick={() => handleStatusUpdate(request.id, "rejected")}>
                      Rechazar
                    </Button>
                  </div>
                )}

                {userProfile.role === "oficial_almacen" && request.status === "approved" && (
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

      {/* Modal para ver imagen completa */}
      {showImageModal && (
        <Dialog open={!!showImageModal} onOpenChange={() => setShowImageModal(null)}>
          <DialogContent className="max-w-3xl">
            <DialogHeader>
              <DialogTitle>Imagen de la solicitud</DialogTitle>
            </DialogHeader>
            <div className="flex justify-center">
              <img
                src={showImageModal || "/placeholder.svg"}
                alt="Imagen completa"
                className="max-w-full max-h-[70vh] object-contain rounded-lg"
              />
            </div>
          </DialogContent>
        </Dialog>
      )}
    </div>
  )
}
