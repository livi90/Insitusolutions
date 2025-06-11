"use client"

import { useState } from "react"
import { supabase, type WorkAssignment, type UserProfile } from "@/lib/supabase"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { useToast } from "@/hooks/use-toast"
import { CheckCircle, Clock, Clipboard, AlertCircle, RefreshCw } from "lucide-react"
import { getStatusColor } from "@/lib/theme"

interface WorkAssignmentManagerProps {
  assignments: WorkAssignment[]
  userProfile: UserProfile
  onUpdate: () => void
}

export function WorkAssignmentManager({ assignments, userProfile, onUpdate }: WorkAssignmentManagerProps) {
  const { toast } = useToast()
  const [loading, setLoading] = useState<Record<string, boolean>>({})

  const handleStatusUpdate = async (assignmentId: string, newStatus: string) => {
    setLoading({ ...loading, [assignmentId]: true })

    try {
      const updateData: any = { status: newStatus }
      if (newStatus === "completed") {
        updateData.completed_date = new Date().toISOString()
      }

      const { error } = await supabase.from("work_assignments").update(updateData).eq("id", assignmentId)

      if (error) throw error

      toast({
        title: "Estado actualizado",
        description: "El estado de la tarea ha sido actualizado",
      })
      onUpdate()
    } catch (error: any) {
      toast({
        title: "Error",
        description: error.message,
        variant: "destructive",
      })
    } finally {
      setLoading({ ...loading, [assignmentId]: false })
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
          <h2 className="text-lg sm:text-xl font-semibold">Mis Tareas Asignadas</h2>
          <p className="text-sm text-muted-foreground">Gestiona tus tareas y actualiza su estado</p>
        </div>
        <Button variant="outline" size="sm" onClick={onUpdate} className="w-full sm:w-auto">
          <RefreshCw className="h-4 w-4 mr-2" />
          Actualizar
        </Button>
      </div>

      <div className="grid gap-4 sm:gap-6">
        {assignments.length === 0 ? (
          <Card>
            <CardContent className="pt-6">
              <div className="text-center py-8">
                <Clipboard className="mx-auto h-12 w-12 text-gray-400" />
                <h3 className="mt-2 text-sm font-medium text-gray-900">No tienes tareas asignadas</h3>
                <p className="mt-1 text-sm text-gray-500">
                  Cuando te asignen tareas, aparecerán aquí para que puedas gestionarlas.
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

                <div className="flex flex-col sm:flex-row gap-2 mt-4">
                  {assignment.status === "pending" && (
                    <Button
                      size="sm"
                      onClick={() => handleStatusUpdate(assignment.id, "in_progress")}
                      disabled={loading[assignment.id]}
                      className="w-full sm:w-auto"
                    >
                      <Clipboard className="h-4 w-4 mr-2" />
                      Iniciar Tarea
                    </Button>
                  )}
                  {assignment.status === "in_progress" && (
                    <Button
                      size="sm"
                      onClick={() => handleStatusUpdate(assignment.id, "completed")}
                      disabled={loading[assignment.id]}
                      className="w-full sm:w-auto"
                    >
                      <CheckCircle className="h-4 w-4 mr-2" />
                      Completar Tarea
                    </Button>
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
