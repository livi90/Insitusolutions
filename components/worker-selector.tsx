"use client"

import { useState, useEffect } from "react"
import { supabase, type UserProfile } from "@/lib/supabase"
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from "@/components/ui/dialog"
import { Button } from "@/components/ui/button"
import { Checkbox } from "@/components/ui/checkbox"
import { Label } from "@/components/ui/label"
import { Input } from "@/components/ui/input"
import { useToast } from "@/hooks/use-toast"
import { Settings, Users, Loader2, AlertCircle } from "lucide-react"

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
  const [workers, setWorkers] = useState<{ id: string; name: string; role: string }[]>([])
  const [selectedWorkers, setSelectedWorkers] = useState<string[]>([])
  const [taskTitle, setTaskTitle] = useState("")
  const [taskDescription, setTaskDescription] = useState("")
  const [fetchingWorkers, setFetchingWorkers] = useState(false)

  useEffect(() => {
    if (open && deliveryId) {
      fetchWorkers()
      setTaskTitle(`Trabajo para entrega ${deliveryId.substring(0, 8)}`)
      setTaskDescription("Apoyo en la entrega de materiales")
      setSelectedWorkers([]) // Limpiar selección previa
    }
  }, [open, deliveryId])

  const fetchWorkers = async () => {
    setFetchingWorkers(true)
    try {
      console.log("Fetching workers for assignment...")

      // Intentar obtener trabajadores con roles específicos
      const { data, error } = await supabase
        .from("user_profiles")
        .select("id, full_name, role")
        .in("role", ["operario_maquinaria", "peon_logistica"])
        .order("full_name")

      console.log("Workers query result:", { data, error })

      if (error) {
        console.error("Error fetching workers:", error)
        throw error
      }

      if (!data || data.length === 0) {
        console.log("No workers found, trying alternative query...")

        // Intentar consulta alternativa sin filtro de rol
        const { data: allUsers, error: allUsersError } = await supabase
          .from("user_profiles")
          .select("id, full_name, role")
          .order("full_name")

        console.log("All users query result:", { data: allUsers, error: allUsersError })

        if (allUsersError) throw allUsersError

        // Filtrar manualmente los roles que necesitamos
        const filteredWorkers = (allUsers || []).filter(
          (user) => user.role === "operario_maquinaria" || user.role === "peon_logistica",
        )

        setWorkers(
          filteredWorkers.map((worker) => ({
            id: worker.id,
            name: worker.full_name,
            role: worker.role,
          })),
        )

        if (filteredWorkers.length === 0) {
          toast({
            title: "Sin trabajadores",
            description:
              "No se encontraron operarios o peones de logística en el sistema. Verifica que existan usuarios con estos roles.",
            variant: "destructive",
          })
        }
      } else {
        setWorkers(
          data.map((worker) => ({
            id: worker.id,
            name: worker.full_name,
            role: worker.role,
          })),
        )
      }
    } catch (error: any) {
      console.error("Error fetching workers:", error)
      toast({
        title: "Error",
        description: `Error al cargar trabajadores: ${error.message}`,
        variant: "destructive",
      })
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
            <Input
              id="task-description"
              value={taskDescription}
              onChange={(e) => setTaskDescription(e.target.value)}
              placeholder="Describe la tarea a realizar"
            />
          </div>

          <div className="space-y-2">
            <Label>Selecciona Trabajadores</Label>
            {fetchingWorkers ? (
              <div className="flex items-center justify-center py-8 border rounded-md">
                <div className="text-center">
                  <Loader2 className="h-8 w-8 animate-spin text-blue-600 mx-auto" />
                  <p className="mt-2 text-sm text-gray-600">Cargando trabajadores...</p>
                </div>
              </div>
            ) : workers.length === 0 ? (
              <div className="text-center py-8 border rounded-md">
                <AlertCircle className="h-8 w-8 mx-auto text-gray-400 mb-2" />
                <p className="text-sm text-gray-500 mb-2">No hay trabajadores disponibles</p>
                <p className="text-xs text-gray-400">
                  Verifica que existan usuarios con roles "operario_maquinaria" o "peon_logistica"
                </p>
                <Button variant="outline" size="sm" onClick={fetchWorkers} className="mt-2">
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
                      <div
                        className={`p-1 rounded ${
                          worker.role === "operario_maquinaria" ? "bg-purple-100" : "bg-blue-100"
                        }`}
                      >
                        {worker.role === "operario_maquinaria" ? (
                          <Settings className="h-4 w-4 text-purple-600" />
                        ) : (
                          <Users className="h-4 w-4 text-blue-600" />
                        )}
                      </div>
                      <Label
                        htmlFor={`worker-${worker.id}`}
                        className="text-sm font-medium leading-none peer-disabled:cursor-not-allowed peer-disabled:opacity-70 truncate cursor-pointer"
                      >
                        {worker.name}
                        <span className="text-xs text-gray-500 block">
                          {worker.role === "operario_maquinaria" ? "Operario de Maquinaria" : "Peón de Logística"}
                        </span>
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
