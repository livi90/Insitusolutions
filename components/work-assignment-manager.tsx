"use client"
import { supabase, type WorkAssignment, type UserProfile } from "@/lib/supabase"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { useToast } from "@/hooks/use-toast"
import { Clock, Play, CheckCircle, AlertTriangle, Settings, Users, MapPin, Calendar, Shield, Truck } from "lucide-react"
import { theme, getStatusColor, getPriorityColor } from "@/lib/theme"

interface WorkAssignmentManagerProps {
  assignments: WorkAssignment[]
  userProfile: UserProfile
  onUpdate: () => void
}

export function WorkAssignmentManager({ assignments, userProfile, onUpdate }: WorkAssignmentManagerProps) {
  const { toast } = useToast()
  const roleColor = theme.roles[userProfile.role as keyof typeof theme.roles] || theme.roles.transportista

  const handleStatusUpdate = async (assignmentId: string, newStatus: string) => {
    try {
      const updateData: any = { status: newStatus }

      if (newStatus === "in_progress") {
        updateData.actual_start = new Date().toISOString()
      } else if (newStatus === "completed") {
        updateData.actual_end = new Date().toISOString()
      }

      const { error } = await supabase.from("work_assignments").update(updateData).eq("id", assignmentId)

      if (error) throw error

      toast({
        title: "Estado actualizado",
        description: "El estado de la asignación ha sido actualizado",
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
      case "in_progress":
        return <Play className="h-4 w-4" />
      case "completed":
        return <CheckCircle className="h-4 w-4" />
      case "cancelled":
        return <AlertTriangle className="h-4 w-4" />
      default:
        return <Clock className="h-4 w-4" />
    }
  }

  const getTypeIcon = (type: string) => {
    switch (type) {
      case "machinery":
        return <Settings className="h-4 w-4" />
      case "logistics":
        return <Users className="h-4 w-4" />
      case "loading":
        return <Truck className="h-4 w-4" />
      case "signaling":
        return <MapPin className="h-4 w-4" />
      default:
        return <MapPin className="h-4 w-4" />
    }
  }

  const getTypeLabel = (type: string) => {
    switch (type) {
      case "machinery":
        return "Maquinaria"
      case "logistics":
        return "Logística"
      case "loading":
        return "Carga/Descarga"
      case "signaling":
        return "Señalización"
      default:
        return type
    }
  }

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <div>
          <h2 className="text-2xl font-bold text-gray-900">Mis Asignaciones de Trabajo</h2>
          <p className="text-gray-600">Gestiona tus tareas y reporta el progreso</p>
        </div>
        <Button onClick={onUpdate} variant="outline" className="gap-2">
          <Clock className="h-4 w-4" />
          Actualizar
        </Button>
      </div>

      <div className="grid gap-6">
        {assignments.length === 0 ? (
          <Card className="border-2 border-dashed border-gray-200">
            <CardContent className="pt-8 pb-8">
              <div className="text-center">
                <div
                  className={`p-4 rounded-full w-fit mx-auto mb-4 bg-gradient-to-r ${roleColor.gradient} text-white`}
                >
                  {userProfile.role === "operario_maquinaria" ? (
                    <Settings className="h-8 w-8" />
                  ) : (
                    <Users className="h-8 w-8" />
                  )}
                </div>
                <h3 className="text-lg font-medium text-gray-900 mb-2">No hay asignaciones</h3>
                <p className="text-gray-500">No tienes asignaciones de trabajo pendientes en este momento.</p>
              </div>
            </CardContent>
          </Card>
        ) : (
          assignments.map((assignment) => {
            const statusColor = getStatusColor(assignment.status)
            const priorityColor = getPriorityColor(assignment.priority)

            return (
              <Card
                key={assignment.id}
                className="border-l-4 shadow-lg hover:shadow-xl transition-shadow"
                style={{ borderLeftColor: roleColor.primary }}
              >
                <CardHeader className="pb-4">
                  <div className="flex justify-between items-start">
                    <div className="flex-1">
                      <div className="flex items-center gap-3 mb-2">
                        <div className={`p-2 rounded-lg bg-gradient-to-r ${roleColor.gradient} text-white`}>
                          {getTypeIcon(assignment.assignment_type)}
                        </div>
                        <div>
                          <CardTitle className="text-xl text-gray-900">{assignment.title}</CardTitle>
                          <div className="flex items-center gap-2 mt-1">
                            <Badge variant="outline" className="text-xs">
                              {getTypeLabel(assignment.assignment_type)}
                            </Badge>
                            <Badge className={`text-xs ${priorityColor}`}>{assignment.priority.toUpperCase()}</Badge>
                          </div>
                        </div>
                      </div>
                      {assignment.description && (
                        <CardDescription className="text-gray-600 mt-2">{assignment.description}</CardDescription>
                      )}
                    </div>
                    <Badge className={`${statusColor.bg} ${statusColor.text} border ${statusColor.border}`}>
                      <div className="flex items-center gap-1">
                        {getStatusIcon(assignment.status)}
                        {assignment.status.replace("_", " ").toUpperCase()}
                      </div>
                    </Badge>
                  </div>
                </CardHeader>

                <CardContent className="space-y-4">
                  {/* Información de tiempo */}
                  {assignment.scheduled_start && (
                    <div className="flex items-center gap-2 text-sm text-gray-600">
                      <Calendar className="h-4 w-4" />
                      <span>Programado: {new Date(assignment.scheduled_start).toLocaleString()}</span>
                    </div>
                  )}

                  {/* Equipos necesarios */}
                  {assignment.equipment_needed && (
                    <div className="p-3 rounded-lg" style={{ backgroundColor: roleColor.light }}>
                      <div className="flex items-center gap-2 mb-1">
                        <Settings className="h-4 w-4" style={{ color: roleColor.primary }} />
                        <span className="font-medium text-gray-900">Equipos Necesarios</span>
                      </div>
                      <p className="text-sm text-gray-800">{assignment.equipment_needed}</p>
                    </div>
                  )}

                  {/* Instrucciones especiales */}
                  {assignment.special_instructions && (
                    <div className="p-3 bg-amber-50 rounded-lg">
                      <div className="flex items-center gap-2 mb-1">
                        <AlertTriangle className="h-4 w-4 text-amber-600" />
                        <span className="font-medium text-amber-900">Instrucciones Especiales</span>
                      </div>
                      <p className="text-sm text-amber-800">{assignment.special_instructions}</p>
                    </div>
                  )}

                  {/* Requisitos de seguridad */}
                  {assignment.safety_requirements && (
                    <div className="p-3 bg-red-50 rounded-lg">
                      <div className="flex items-center gap-2 mb-1">
                        <Shield className="h-4 w-4 text-red-600" />
                        <span className="font-medium text-red-900">Requisitos de Seguridad</span>
                      </div>
                      <p className="text-sm text-red-800">{assignment.safety_requirements}</p>
                    </div>
                  )}

                  {/* Acciones */}
                  <div className="flex gap-3 pt-4 border-t">
                    {assignment.status === "pending" && (
                      <Button
                        onClick={() => handleStatusUpdate(assignment.id, "in_progress")}
                        className="text-white"
                        style={{
                          background: `linear-gradient(to right, ${roleColor.primary}, ${roleColor.secondary})`,
                        }}
                      >
                        <Play className="h-4 w-4 mr-2" />
                        Iniciar Trabajo
                      </Button>
                    )}

                    {assignment.status === "in_progress" && (
                      <Button
                        onClick={() => handleStatusUpdate(assignment.id, "completed")}
                        className="bg-green-600 hover:bg-green-700 text-white"
                      >
                        <CheckCircle className="h-4 w-4 mr-2" />
                        Completar
                      </Button>
                    )}

                    {assignment.status === "completed" && (
                      <div className="flex items-center gap-2 text-green-600">
                        <CheckCircle className="h-4 w-4" />
                        <span className="font-medium">Trabajo Completado</span>
                        {assignment.actual_end && (
                          <span className="text-sm text-gray-500">
                            el {new Date(assignment.actual_end).toLocaleString()}
                          </span>
                        )}
                      </div>
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
