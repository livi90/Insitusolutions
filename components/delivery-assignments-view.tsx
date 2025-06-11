"use client"

import { useState, useEffect } from "react"
import { supabase, type UserProfile, type WorkAssignment } from "@/lib/supabase"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { useToast } from "@/hooks/use-toast"
import { Users, RefreshCw, Clipboard, CheckCircle, Clock, AlertCircle } from "lucide-react"
import { getStatusColor } from "@/lib/theme"

interface DeliveryAssignmentsViewProps {
  userProfile: UserProfile
}

export function DeliveryAssignmentsView({ userProfile }: DeliveryAssignmentsViewProps) {
  const { toast } = useToast()
  const [assignments, setAssignments] = useState<WorkAssignment[]>([])
  const [loading, setLoading] = useState(true)
  const [workers, setWorkers] = useState<Record<string, { name: string; role: string }>>({})

  useEffect(() => {
    fetchAssignments()
  }, [userProfile])

  const fetchAssignments = async () => {
    setLoading(true)
    try {
      // Obtener todas las asignaciones
      const { data: assignmentsData, error: assignmentsError } = await supabase
        .from("work_assignments")
        .select("*")
        .order("created_at", { ascending: false })

      if (assignmentsError) throw assignmentsError

      // Obtener información de los trabajadores
      const workerIds = assignmentsData?.map((a) => a.assigned_to) || []
      if (workerIds.length > 0) {
        const { data: workersData, error: workersError } = await supabase
          .from("user_profiles")
          .select("id, full_name, role")
          .in("id", workerIds)

        if (workersError) throw workersError

        const workersMap: Record<string, { name: string; role: string }> = {}
        workersData?.forEach((worker) => {
          workersMap[worker.id] = {
            name: worker.full_name,
            role: worker.role,
          }
        })
        setWorkers(workersMap)
      }

      setAssignments(assignmentsData || [])
    } catch (error: any) {
      console.error("Error fetching assignments:", error)
      toast({
        title: "Error",
        description: `Error al cargar asignaciones: ${error.message}`,
        variant: "destructive",
      })
    } finally {
      setLoading(false)
    }
  }

  const getStatusIcon = (status: string) => {
    switch (status) {
      case "pending":
        return <Clock className="h-4 w-4" />
      case "in_progress":
        return <Clipboard className="h-4 w-4" />
      case "completed":
        return <CheckCircle className="h-4 w-4" />
      case "cancelled":
        return <AlertCircle className="h-4 w-4" />
      default:
        return <Clock className="h-4 w-4" />
    }
  }

  const getStatusLabel = (status: string) => {
    switch (status) {
      case "pending":
        return "Pendiente"
      case "in_progress":
        return "En Progreso"
      case "completed":
        return "Completada"
      case "cancelled":
        return "Cancelada"
      default:
        return status
    }
  }

  return (
    <div className="space-y-4 sm:space-y-6">
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <h2 className="text-lg sm:text-xl font-semibold">Asignaciones de Personal</h2>
          <p className="text-sm text-muted-foreground">Visualiza las tareas asignadas a los trabajadores</p>
        </div>
        <Button variant="outline" size="sm" onClick={fetchAssignments} className="w-full sm:w-auto">
          <RefreshCw className="h-4 w-4 mr-2" />
          Actualizar
        </Button>
      </div>

      <div className="grid gap-4 sm:gap-6">
        {loading ? (
          <Card>
            <CardContent className="pt-6">
              <div className="text-center py-8">
                <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto"></div>
                <p className="mt-4 text-gray-600">Cargando asignaciones...</p>
              </div>
            </CardContent>
          </Card>
        ) : assignments.length === 0 ? (
          <Card>
            <CardContent className="pt-6">
              <div className="text-center py-8">
                <Users className="mx-auto h-12 w-12 text-gray-400" />
                <h3 className="mt-2 text-sm font-medium text-gray-900">No hay asignaciones</h3>
                <p className="mt-1 text-sm text-gray-500">
                  Cuando asignes tareas a los trabajadores, aparecerán aquí para su seguimiento.
                </p>
              </div>
            </CardContent>
          </Card>
        ) : (
          assignments.map((assignment) => (
            <Card key={assignment.id} className="hover:shadow-lg transition-shadow">
              <CardHeader className="pb-3">
                <div className="flex flex-col sm:flex-row justify-between items-start gap-3">
                  <div className="min-w-0 flex-1">
                    <CardTitle className="text-base sm:text-lg">{assignment.title}</CardTitle>
                    <CardDescription className="mt-1">{assignment.description}</CardDescription>
                  </div>
                  <Badge className={`${getStatusColor(assignment.status)} flex-shrink-0`}>
                    <div className="flex items-center gap-1">
                      {getStatusIcon(assignment.status)}
                      {getStatusLabel(assignment.status)}
                    </div>
                  </Badge>
                </div>
              </CardHeader>
              <CardContent>
                <div className="space-y-2 sm:space-y-3">
                  <div className="flex items-center gap-2">
                    <Users className="h-4 w-4 text-gray-500" />
                    <p className="text-sm">
                      <strong>Asignado a:</strong>{" "}
                      {workers[assignment.assigned_to]
                        ? `${workers[assignment.assigned_to].name} (${
                            workers[assignment.assigned_to].role === "operario_maquinaria"
                              ? "Operario"
                              : "Peón Logística"
                          })`
                        : "Trabajador"}
                    </p>
                  </div>
                  {assignment.delivery_id && (
                    <p className="text-sm">
                      <strong>Entrega relacionada:</strong> {assignment.delivery_id}
                    </p>
                  )}
                  {assignment.work_site_id && (
                    <p className="text-sm">
                      <strong>Obra:</strong> {assignment.work_site_id}
                    </p>
                  )}
                  {assignment.scheduled_date && (
                    <p className="text-sm">
                      <strong>Fecha programada:</strong> {new Date(assignment.scheduled_date).toLocaleString()}
                    </p>
                  )}
                  {assignment.completed_date && (
                    <p className="text-sm">
                      <strong>Completada:</strong> {new Date(assignment.completed_date).toLocaleString()}
                    </p>
                  )}
                </div>
              </CardContent>
            </Card>
          ))
        )}
      </div>
    </div>
  )
}
