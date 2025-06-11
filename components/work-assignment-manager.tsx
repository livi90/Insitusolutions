"use client"

import { useState } from "react"
import { supabase, type WorkAssignment, type UserProfile } from "@/lib/supabase"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { useToast } from "@/hooks/use-toast"
import { CheckCircle, Clock, Clipboard, AlertCircle, RefreshCw, Users, Settings } from "lucide-react"
import { getStatusColor, getRoleLabel } from "@/lib/theme"

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

  const getRoleIcon = (role: string) => {
    switch (role) {
      case "operario_maquinaria":
        return <Settings className="h-4 w-4" />
      case "peon_logistica":
        return <Users className="h-4 w-4" />
      default:
        return <Users className="h-4 w-4" />
    }
  }

  return (
    <div className="space-y-4 sm:space-y-6">
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <h2 className="text-lg sm:text-xl font-semibold flex items-center gap-2">
            {getRoleIcon(userProfile.role)}
            Mis Tareas Asignadas
          </h2>
          <p className="text-sm text-muted-foreground">
            Como {getRoleLabel(userProfile.role)}, gestiona tus tareas y actualiza su estado
          </p>
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
                <div className="p-3 bg-gray-100 rounded-full w-fit mx-auto mb-4">{getRoleIcon(userProfile.role)}</div>
                <h3 className="mt-2 text-sm font-medium text-gray-900">No tienes tareas asignadas</h3>
                <p className="mt-1 text-sm text-gray-500">
                  Cuando te asignen tareas como {getRoleLabel(userProfile.role)}, aparecerán aquí para que puedas
                  gestionarlas.
                </p>
                <div className="mt-4 p-3 bg-blue-50 rounded-lg">
                  <p className="text-xs text-blue-700">
                    <strong>Tip:</strong> Las tareas se asignan desde el módulo de entregas por parte del oficial de
                    almacén o encargado de obra.
                  </p>
                </div>
              </div>
            </CardContent>
          </Card>
        ) : (
          assignments.map((assignment) => (
            <Card key={assignment.id} className="hover:shadow-lg transition-shadow">
              <CardHeader className="pb-3">
                <div className="flex flex-col sm:flex-row justify-between items-start gap-3">
                  <div className="min-w-0 flex-1">
                    <CardTitle className="text-base sm:text-lg flex items-center gap-2">
                      {getRoleIcon(userProfile.role)}
                      {assignment.title}
                    </CardTitle>
                    <CardDescription className="mt-1">{assignment.description}</CardDescription>
                    <div className="flex items-center gap-2 mt-2">
                      <Badge variant="outline" className="text-xs">
                        {getRoleLabel(userProfile.role)}
                      </Badge>
                    </div>
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
                      <strong>Entrega relacionada:</strong> {assignment.delivery_id.substring(0, 8)}...
                    </p>
                  )}
                  {assignment.work_site_id && (
                    <p className="text-sm">
                      <strong>Obra:</strong> {assignment.work_site_id.substring(0, 8)}...
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
                  <p className="text-sm">
                    <strong>Asignada:</strong> {new Date(assignment.created_at).toLocaleString()}
                  </p>
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
                  {assignment.status === "completed" && (
                    <div className="flex items-center gap-2 text-green-600 text-sm">
                      <CheckCircle className="h-4 w-4" />
                      <span>Tarea completada exitosamente</span>
                    </div>
                  )}
                </div>
              </CardContent>
            </Card>
          ))
        )}
      </div>

      {/* Información adicional para trabajadores */}
      <Card className="bg-gradient-to-r from-blue-50 to-indigo-50 border-blue-200">
        <CardContent className="pt-6">
          <div className="flex items-start gap-3">
            <div className="p-2 bg-blue-100 rounded-lg">{getRoleIcon(userProfile.role)}</div>
            <div>
              <h3 className="font-semibold text-blue-900 mb-2">Información para {getRoleLabel(userProfile.role)}</h3>
              <div className="text-sm text-blue-800 space-y-1">
                {userProfile.role === "operario_maquinaria" && (
                  <>
                    <p>• Responsable de operar maquinaria especializada</p>
                    <p>• Manejo de equipos pesados y herramientas técnicas</p>
                    <p>• Supervisión de procesos de carga y descarga</p>
                  </>
                )}
                {userProfile.role === "peon_logistica" && (
                  <>
                    <p>• Apoyo en tareas de organización y empaque</p>
                    <p>• Carga y descarga de materiales menores</p>
                    <p>• Preparación y clasificación de inventario</p>
                  </>
                )}
              </div>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  )
}
