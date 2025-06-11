"use client"

import { useState, useEffect } from "react"
import { supabase, type UserProfile } from "@/lib/supabase"
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from "@/components/ui/dialog"
import { Button } from "@/components/ui/button"
import { Checkbox } from "@/components/ui/checkbox"
import { Label } from "@/components/ui/label"
import { Input } from "@/components/ui/input"
import { Textarea } from "@/components/ui/textarea"
import { useToast } from "@/hooks/use-toast"
import { Settings, Users, Loader2, AlertCircle, RefreshCw } from "lucide-react"

interface WorkerSelectorProps {
  open: boolean
  onOpenChange: (open: boolean) => void
  deliveryId: string | null
  userProfile: UserProfile
  onWorkersAssigned: () => void
}

export function WorkerSelector({
  open,
  onOpenChange,
  deliveryId,
  userProfile,
  onWorkersAssigned,
}: WorkerSelectorProps) {
  const { toast } = useToast()
  const [loading, setLoading] = useState(false)
  const [workers, setWorkers] = useState<{ id: string; name: string; role: string; email: string }[]>([])
  const [selectedWorkers, setSelectedWorkers] = useState<string[]>([])
  const [taskTitle, setTaskTitle] = useState("")
  const [taskDescription, setTaskDescription] = useState("")
  const [fetchingWorkers, setFetchingWorkers] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (open && deliveryId) {
      fetchWorkers()
      setTaskTitle(`Trabajo para entrega ${deliveryId.substring(0, 8)}`)
      setTaskDescription("Apoyo en la entrega de materiales")
      setSelectedWorkers([]) // Limpiar selección previa
      setError(null)
    }
  }, [open, deliveryId])

  const fetchWorkers = async () => {
    setFetchingWorkers(true)
    setError(null)

    try {
      console.log("Fetching workers for assignment...")

      // Método 1: Intentar usar la función principal corregida
      try {
        console.log("Trying main function...")
        const { data: functionData, error: functionError } = await supabase.rpc("get_available_workers_for_assignment")

        if (functionError) {
          console.log("Main function error:", functionError)
          throw functionError
        }

        if (functionData && functionData.length > 0) {
          console.log("Workers from main function:", functionData)
          setWorkers(
            functionData.map((worker: any) => ({
              id: worker.id,
              name: worker.full_name,
              role: worker.role,
              email: worker.email,
            })),
          )
          return
        }
      } catch (funcError) {
        console.log("Main function failed, trying simple function...")
      }

      // Método 2: Intentar usar la función simple
      try {
        console.log("Trying simple function...")
        const { data: simpleData, error: simpleError } = await supabase.rpc("get_workers_simple")

        if (simpleError) {
          console.log("Simple function error:", simpleError)
          throw simpleError
        }

        if (simpleData && simpleData.length > 0) {
          console.log("Workers from simple function:", simpleData)

          // Filtrar según el rol del usuario
          let filteredWorkers = simpleData
          if (userProfile.role === "encargado_obra") {
            // Encargados de obra solo ven operarios y peones
            filteredWorkers = simpleData.filter((w) => w.role === "operario_maquinaria" || w.role === "peon_logistica")
          }

          setWorkers(
            filteredWorkers.map((worker: any) => ({
              id: worker.id,
              name: worker.full_name,
              role: worker.role,
              email: worker.email,
            })),
          )
          return
        }
      } catch (simpleError) {
        console.log("Simple function also failed, trying direct query...")
      }

      // Método 3: Consulta directa como último recurso
      console.log("Trying direct query...")

      const roles = ["operario_maquinaria", "peon_logistica"]
      if (userProfile.role === "oficial_almacen") {
        roles.push("transportista")
      }

      const { data, error } = await supabase
        .from("user_profiles")
        .select("id, full_name, role, email")
        .in("role", roles)
        .order("full_name")

      console.log("Direct query result:", { data, error })

      if (error) {
        console.error("Direct query error:", error)
        throw error
      }

      if (!data || data.length === 0) {
        setError(
          "No se encontraron trabajadores en el sistema. Verifica que existan usuarios con los roles apropiados.",
        )
        setWorkers([])
      } else {
        console.log("Workers found via direct query:", data.length)
        setWorkers(
          data.map((worker) => ({
            id: worker.id,
            name: worker.full_name,
            role: worker.role,
            email: worker.email,
          })),
        )
      }
    } catch (error: any) {
      console.error("Error fetching workers:", error)
      setError(`Error al cargar trabajadores: ${error.message}`)
      setWorkers([])
    } finally {
      setFetchingWorkers(false)
    }
  }

  const handleAssignWorkers = async () => {
    if (!deliveryId || selectedWorkers.length === 0) {
      toast({
        title: "Error",
        description: "Selecciona al menos un trabajador",
        variant: "destructive",
      })
      return
    }

    if (!taskTitle.trim()) {
      toast({
        title: "Error",
        description: "El título de la tarea es requerido",
        variant: "destructive",
      })
      return
    }

    setLoading(true)
    try {
      console.log("Creating work assignments:", {
        deliveryId,
        selectedWorkers,
        taskTitle,
        taskDescription,
        userProfile: userProfile.id,
      })

      // Crear asignaciones de trabajo para cada trabajador seleccionado
      const assignments = selectedWorkers.map((workerId) => ({
        title: taskTitle.trim(),
        description: taskDescription.trim() || null,
        assigned_to: workerId,
        created_by: userProfile.id,
        delivery_id: deliveryId,
        status: "pending",
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      }))

      console.log("Assignments to insert:", assignments)

      const { data, error } = await supabase.from("work_assignments").insert(assignments).select()

      console.log("Insert result:", { data, error })

      if (error) {
        console.error("Error inserting assignments:", error)
        throw error
      }

      toast({
        title: "Trabajadores asignados",
        description: `Se han asignado ${selectedWorkers.length} trabajadores a la entrega`,
      })

      // Limpiar formulario
      setSelectedWorkers([])
      setTaskTitle("")
      setTaskDescription("")
      onOpenChange(false)
      onWorkersAssigned()
    } catch (error: any) {
      console.error("Error assigning workers:", error)
      toast({
        title: "Error",
        description: `Error al asignar trabajadores: ${error.message}`,
        variant: "destructive",
      })
    } finally {
      setLoading(false)
    }
  }

  const toggleWorker = (workerId: string) => {
    setSelectedWorkers((prev) => (prev.includes(workerId) ? prev.filter((id) => id !== workerId) : [...prev, workerId]))
  }

  const handleRetry = () => {
    setError(null)
    fetchWorkers()
  }

  const getRoleLabel = (role: string) => {
    switch (role) {
      case "operario_maquinaria":
        return "Operario de Maquinaria"
      case "peon_logistica":
        return "Peón de Logística"
      case "transportista":
        return "Transportista"
      default:
        return role
    }
  }

  const getRoleIcon = (role: string) => {
    switch (role) {
      case "operario_maquinaria":
        return <Settings className="h-4 w-4 text-purple-600" />
      case "peon_logistica":
        return <Users className="h-4 w-4 text-blue-600" />
      case "transportista":
        return <Users className="h-4 w-4 text-green-600" />
      default:
        return <Users className="h-4 w-4 text-gray-600" />
    }
  }

  const getRoleColor = (role: string) => {
    switch (role) {
      case "operario_maquinaria":
        return "bg-purple-100"
      case "peon_logistica":
        return "bg-blue-100"
      case "transportista":
        return "bg-green-100"
      default:
        return "bg-gray-100"
    }
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-md sm:max-w-lg mx-auto">
        <DialogHeader>
          <DialogTitle>Asignar Personal a la Entrega</DialogTitle>
          <DialogDescription>Selecciona los trabajadores que participarán en esta entrega</DialogDescription>
        </DialogHeader>

        <div className="space-y-4">
          <div className="space-y-2">
            <Label htmlFor="task-title">Título de la Tarea *</Label>
            <Input
              id="task-title"
              value={taskTitle}
              onChange={(e) => setTaskTitle(e.target.value)}
              placeholder="ej. Carga de materiales"
              required
            />
          </div>

          <div className="space-y-2">
            <Label htmlFor="task-description">Descripción</Label>
            <Textarea
              id="task-description"
              value={taskDescription}
              onChange={(e) => setTaskDescription(e.target.value)}
              placeholder="Describe la tarea a realizar"
              rows={3}
            />
          </div>

          <div className="space-y-2">
            <div className="flex items-center justify-between">
              <Label>Selecciona Trabajadores</Label>
              {!fetchingWorkers && (
                <Button variant="ghost" size="sm" onClick={handleRetry}>
                  <RefreshCw className="h-4 w-4 mr-1" />
                  Actualizar
                </Button>
              )}
            </div>

            {fetchingWorkers ? (
              <div className="flex items-center justify-center py-8 border rounded-md">
                <div className="text-center">
                  <Loader2 className="h-8 w-8 animate-spin text-blue-600 mx-auto" />
                  <p className="mt-2 text-sm text-gray-600">Cargando trabajadores...</p>
                </div>
              </div>
            ) : error ? (
              <div className="text-center py-8 border rounded-md border-red-200 bg-red-50">
                <AlertCircle className="h-8 w-8 mx-auto text-red-400 mb-2" />
                <p className="text-sm text-red-600 mb-2 px-4">{error}</p>
                <Button variant="outline" size="sm" onClick={handleRetry} className="mt-2">
                  <RefreshCw className="h-4 w-4 mr-1" />
                  Reintentar
                </Button>
              </div>
            ) : workers.length === 0 ? (
              <div className="text-center py-8 border rounded-md">
                <AlertCircle className="h-8 w-8 mx-auto text-gray-400 mb-2" />
                <p className="text-sm text-gray-500 mb-2">No hay trabajadores disponibles</p>
                <p className="text-xs text-gray-400 px-4">
                  Verifica que existan usuarios con los roles apropiados en el sistema
                </p>
                <Button variant="outline" size="sm" onClick={handleRetry} className="mt-2">
                  <RefreshCw className="h-4 w-4 mr-1" />
                  Reintentar
                </Button>
              </div>
            ) : (
              <div className="space-y-2 max-h-60 overflow-y-auto border rounded-md p-2">
                {workers.map((worker) => (
                  <div key={worker.id} className="flex items-center space-x-2 p-2 hover:bg-gray-100 rounded">
                    <Checkbox
                      id={`worker-${worker.id}`}
                      checked={selectedWorkers.includes(worker.id)}
                      onCheckedChange={() => toggleWorker(worker.id)}
                    />
                    <div className="flex items-center gap-2 flex-1 min-w-0">
                      <div className={`p-1 rounded ${getRoleColor(worker.role)}`}>{getRoleIcon(worker.role)}</div>
                      <Label
                        htmlFor={`worker-${worker.id}`}
                        className="text-sm font-medium leading-none peer-disabled:cursor-not-allowed peer-disabled:opacity-70 truncate cursor-pointer"
                      >
                        {worker.name}
                        <span className="text-xs text-gray-500 block">{getRoleLabel(worker.role)}</span>
                        {worker.email && <span className="text-xs text-gray-400 block">{worker.email}</span>}
                      </Label>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>

          <div className="flex justify-end gap-2 pt-4">
            <Button variant="outline" onClick={() => onOpenChange(false)} disabled={loading}>
              Cancelar
            </Button>
            <Button
              onClick={handleAssignWorkers}
              disabled={loading || selectedWorkers.length === 0 || !taskTitle.trim()}
            >
              {loading ? (
                <>
                  <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                  Asignando...
                </>
              ) : (
                `Asignar ${selectedWorkers.length > 0 ? `(${selectedWorkers.length})` : ""}`
              )}
            </Button>
          </div>
        </div>
      </DialogContent>
    </Dialog>
  )
}
