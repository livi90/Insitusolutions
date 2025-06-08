"use client"

import { useState, useEffect } from "react"
import { supabase, type UserProfile } from "@/lib/supabase"
import { Card, CardContent, CardHeader } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Checkbox } from "@/components/ui/checkbox"
import { Label } from "@/components/ui/label"
import { Textarea } from "@/components/ui/textarea"
import { Settings, Users, AlertTriangle, Shield, RefreshCw } from "lucide-react"
import { theme, getRoleLabel } from "@/lib/theme"

interface WorkerSelectorProps {
  deliveryId: string
  onWorkersAssigned: () => void
  onClose: () => void
}

interface WorkerWithAssignment {
  worker: UserProfile
  selected: boolean
  assignmentType: "machinery" | "logistics"
  specialInstructions: string
  safetyRequirements: string
}

export function WorkerSelector({ deliveryId, onWorkersAssigned, onClose }: WorkerSelectorProps) {
  const [workers, setWorkers] = useState<WorkerWithAssignment[]>([])
  const [loading, setLoading] = useState(true)
  const [assigning, setAssigning] = useState(false)

  useEffect(() => {
    fetchAvailableWorkers()
  }, [])

  const fetchAvailableWorkers = async () => {
    setLoading(true)
    try {
      console.log("Fetching available workers...")

      const { data: workersData, error } = await supabase
        .from("user_profiles")
        .select("*")
        .in("role", ["operario_maquinaria", "peon_logistica"])
        .order("full_name")

      if (error) {
        console.error("Error fetching workers:", error)
        throw error
      }

      console.log("Workers found:", workersData)

      if (!workersData || workersData.length === 0) {
        console.log("No workers found, creating demo workers...")
        // Si no hay trabajadores, mostrar mensaje y opción para crearlos
        setWorkers([])
        return
      }

      const workersWithAssignment: WorkerWithAssignment[] = workersData.map((worker) => ({
        worker,
        selected: false,
        assignmentType: worker.role === "operario_maquinaria" ? "machinery" : "logistics",
        specialInstructions: "",
        safetyRequirements: getDefaultSafetyRequirements(worker.role),
      }))

      setWorkers(workersWithAssignment)
    } catch (error) {
      console.error("Error fetching workers:", error)
    } finally {
      setLoading(false)
    }
  }

  const createDemoWorkers = async () => {
    try {
      console.log("Creating demo workers...")

      const demoWorkers = [
        {
          id: "44444444-4444-4444-4444-444444444444",
          email: "operario1@logistica.com",
          full_name: "Roberto Operario Grúa",
          role: "operario_maquinaria",
          permission_level: "normal",
        },
        {
          id: "44444444-4444-4444-4444-444444444445",
          email: "operario2@logistica.com",
          full_name: "Miguel Operario Excavadora",
          role: "operario_maquinaria",
          permission_level: "normal",
        },
        {
          id: "55555555-5555-5555-5555-555555555555",
          email: "peon1@logistica.com",
          full_name: "Pedro Peón Logística",
          role: "peon_logistica",
          permission_level: "normal",
        },
        {
          id: "55555555-5555-5555-5555-555555555556",
          email: "peon2@logistica.com",
          full_name: "Sandra Peón Señalización",
          role: "peon_logistica",
          permission_level: "normal",
        },
      ]

      const { error } = await supabase.from("user_profiles").upsert(demoWorkers, { onConflict: "id" })

      if (error) throw error

      console.log("Demo workers created successfully")
      fetchAvailableWorkers()
    } catch (error) {
      console.error("Error creating demo workers:", error)
    }
  }

  const getDefaultSafetyRequirements = (role: string) => {
    switch (role) {
      case "operario_maquinaria":
        return "Uso obligatorio de casco, arnés de seguridad, chaleco reflectivo. Verificar certificación de operador."
      case "peon_logistica":
        return "Uso obligatorio de casco, chaleco reflectivo, guantes de trabajo. Mantener comunicación por radio."
      default:
        return "Seguir protocolos de seguridad estándar."
    }
  }

  const handleWorkerToggle = (index: number, checked: boolean) => {
    setWorkers((prev) => prev.map((worker, i) => (i === index ? { ...worker, selected: checked } : worker)))
  }

  const handleInstructionsChange = (index: number, instructions: string) => {
    setWorkers((prev) =>
      prev.map((worker, i) => (i === index ? { ...worker, specialInstructions: instructions } : worker)),
    )
  }

  const handleSafetyChange = (index: number, safety: string) => {
    setWorkers((prev) => prev.map((worker, i) => (i === index ? { ...worker, safetyRequirements: safety } : worker)))
  }

  const handleAssignWorkers = async () => {
    setAssigning(true)
    try {
      const selectedWorkers = workers.filter((w) => w.selected)

      if (selectedWorkers.length === 0) {
        onClose()
        return
      }

      // Obtener información de la entrega
      const { data: delivery, error: deliveryError } = await supabase
        .from("deliveries")
        .select("*")
        .eq("id", deliveryId)
        .single()

      if (deliveryError) throw deliveryError

      // Crear asignaciones para cada trabajador seleccionado
      const assignments = selectedWorkers.map((workerData) => ({
        title: `${workerData.assignmentType === "machinery" ? "Operación de Maquinaria" : "Apoyo Logístico"} - ${delivery.title}`,
        description: `${workerData.assignmentType === "machinery" ? "Operación de maquinaria requerida" : "Apoyo en logística y señalización"} para: ${delivery.description}`,
        assigned_to: workerData.worker.id,
        delivery_id: deliveryId,
        assignment_type: workerData.assignmentType,
        priority: "normal",
        status: "pending",
        special_instructions: workerData.specialInstructions || null,
        safety_requirements: workerData.safetyRequirements,
        created_by: delivery.created_by,
      }))

      const { error: assignmentError } = await supabase.from("work_assignments").insert(assignments)

      if (assignmentError) throw assignmentError

      // Crear notificaciones para cada trabajador
      const notifications = selectedWorkers.map((workerData) => ({
        title: "Nueva Asignación de Trabajo",
        message: `Te han asignado una nueva tarea: ${workerData.assignmentType === "machinery" ? "Operación de Maquinaria" : "Apoyo Logístico"} - ${delivery.title}`,
        type: "work_assignment",
        user_id: workerData.worker.id,
        delivery_id: deliveryId,
      }))

      const { error: notificationError } = await supabase.from("notifications").insert(notifications)

      if (notificationError) throw notificationError

      onWorkersAssigned()
      onClose()
    } catch (error) {
      console.error("Error assigning workers:", error)
    } finally {
      setAssigning(false)
    }
  }

  const selectedCount = workers.filter((w) => w.selected).length

  if (loading) {
    return (
      <div className="p-6 text-center">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600 mx-auto"></div>
        <p className="mt-2 text-gray-600">Cargando trabajadores...</p>
      </div>
    )
  }

  if (workers.length === 0) {
    return (
      <div className="p-6 text-center">
        <div className="p-4 bg-yellow-50 rounded-lg mb-4">
          <AlertTriangle className="h-8 w-8 text-yellow-600 mx-auto mb-2" />
          <h3 className="text-lg font-medium text-yellow-800 mb-2">No hay trabajadores disponibles</h3>
          <p className="text-sm text-yellow-700 mb-4">
            No se encontraron operarios de maquinaria ni peones de logística en el sistema.
          </p>
          <Button onClick={createDemoWorkers} className="bg-yellow-600 hover:bg-yellow-700 text-white">
            Crear Trabajadores de Demostración
          </Button>
        </div>
        <div className="flex justify-end gap-3">
          <Button variant="outline" onClick={onClose}>
            Cerrar
          </Button>
          <Button onClick={fetchAvailableWorkers} variant="outline" className="gap-2">
            <RefreshCw className="h-4 w-4" />
            Actualizar Lista
          </Button>
        </div>
      </div>
    )
  }

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <div>
          <h3 className="text-lg font-semibold">Asignar Trabajadores</h3>
          <p className="text-sm text-gray-600">
            Selecciona los trabajadores que participarán en esta entrega ({selectedCount} seleccionados)
          </p>
        </div>
        <Button onClick={fetchAvailableWorkers} variant="outline" size="sm" className="gap-2">
          <RefreshCw className="h-4 w-4" />
          Actualizar
        </Button>
      </div>

      <div className="space-y-4 max-h-96 overflow-y-auto">
        {workers.map((workerData, index) => {
          const roleColor = theme.roles[workerData.worker.role as keyof typeof theme.roles]

          return (
            <Card key={workerData.worker.id} className={`border ${workerData.selected ? "ring-2 ring-blue-500" : ""}`}>
              <CardHeader className="pb-3">
                <div className="flex items-center space-x-3">
                  <Checkbox
                    id={`worker-${workerData.worker.id}`}
                    checked={workerData.selected}
                    onCheckedChange={(checked) => handleWorkerToggle(index, checked as boolean)}
                  />
                  <div className={`p-2 rounded-lg bg-gradient-to-r ${roleColor.gradient} text-white`}>
                    {workerData.worker.role === "operario_maquinaria" ? (
                      <Settings className="h-4 w-4" />
                    ) : (
                      <Users className="h-4 w-4" />
                    )}
                  </div>
                  <div className="flex-1">
                    <Label htmlFor={`worker-${workerData.worker.id}`} className="text-base font-medium cursor-pointer">
                      {workerData.worker.full_name}
                    </Label>
                    <div className="flex items-center gap-2 mt-1">
                      <Badge variant="outline" className="text-xs">
                        {getRoleLabel(workerData.worker.role)}
                      </Badge>
                      <Badge className={`text-xs ${roleColor.light}`} style={{ color: roleColor.primary }}>
                        {workerData.assignmentType === "machinery" ? "Maquinaria" : "Logística"}
                      </Badge>
                      <Badge variant="outline" className="text-xs">
                        {workerData.worker.email}
                      </Badge>
                    </div>
                  </div>
                </div>
              </CardHeader>

              {workerData.selected && (
                <CardContent className="space-y-4">
                  <div className="space-y-2">
                    <Label className="text-sm font-medium flex items-center gap-1">
                      <AlertTriangle className="h-3 w-3" />
                      Instrucciones Especiales
                    </Label>
                    <Textarea
                      placeholder="Instrucciones específicas para este trabajador..."
                      value={workerData.specialInstructions}
                      onChange={(e) => handleInstructionsChange(index, e.target.value)}
                      rows={2}
                      className="text-sm"
                    />
                  </div>

                  <div className="space-y-2">
                    <Label className="text-sm font-medium flex items-center gap-1">
                      <Shield className="h-3 w-3" />
                      Requisitos de Seguridad
                    </Label>
                    <Textarea
                      value={workerData.safetyRequirements}
                      onChange={(e) => handleSafetyChange(index, e.target.value)}
                      rows={2}
                      className="text-sm"
                    />
                  </div>
                </CardContent>
              )}
            </Card>
          )
        })}
      </div>

      <div className="flex justify-end gap-3 pt-4 border-t">
        <Button variant="outline" onClick={onClose}>
          Cancelar
        </Button>
        <Button
          onClick={handleAssignWorkers}
          disabled={assigning || selectedCount === 0}
          className="bg-gradient-to-r from-blue-600 to-indigo-600 hover:from-blue-700 hover:to-indigo-700 text-white"
        >
          {assigning ? "Asignando..." : `Asignar ${selectedCount} Trabajador${selectedCount !== 1 ? "es" : ""}`}
        </Button>
      </div>
    </div>
  )
}
