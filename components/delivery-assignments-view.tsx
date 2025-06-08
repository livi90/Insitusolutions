"use client"

import { useState, useEffect } from "react"
import { supabase, type WorkAssignment, type UserProfile, type Delivery } from "@/lib/supabase"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Clock, Settings, Users, CheckCircle, AlertTriangle, Eye, RefreshCw } from "lucide-react"
import { theme, getStatusColor, getRoleLabel } from "@/lib/theme"
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog"

interface DeliveryAssignmentsViewProps {
  userProfile: UserProfile
}

interface AssignmentWithDetails extends WorkAssignment {
  worker: UserProfile
  delivery: Delivery
}

export function DeliveryAssignmentsView({ userProfile }: DeliveryAssignmentsViewProps) {
  const [assignments, setAssignments] = useState<AssignmentWithDetails[]>([])
  const [loading, setLoading] = useState(true)
  const [selectedAssignment, setSelectedAssignment] = useState<AssignmentWithDetails | null>(null)

  useEffect(() => {
    fetchAssignments()
  }, [userProfile])

  const fetchAssignments = async () => {
    setLoading(true)
    try {
      // Obtener asignaciones relacionadas con entregas creadas por el usuario actual
      const { data: assignmentsData, error } = await supabase
        .from("work_assignments")
        .select(`
          *,
          worker:assigned_to(id, full_name, role, email),
          delivery:delivery_id(id, title, description, delivery_address, status, created_by)
        `)
        .not("delivery_id", "is", null)
        .order("created_at", { ascending: false })

      if (error) throw error

      // Filtrar solo las asignaciones de entregas creadas por el usuario actual
      const filteredAssignments = (assignmentsData || [])
        .filter((assignment: any) => assignment.delivery?.created_by === userProfile.id)
        .map((assignment: any) => ({
          ...assignment,
          worker: assignment.worker,
          delivery: assignment.delivery,
        }))

      setAssignments(filteredAssignments)
    } catch (error) {
      console.error("Error fetching assignments:", error)
    } finally {
      setLoading(false)
    }
  }

  const getTypeIcon = (type: string) => {
    switch (type) {
      case "machinery":
        return <Settings className="h-4 w-4" />
      case "logistics":
        return <Users className="h-4 w-4" />
      default:
        return <Users className="h-4 w-4" />
    }
  }

  const getTypeLabel = (type: string) => {
    switch (type) {
      case "machinery":
        return "Maquinaria"
      case "logistics":
        return "Logística"
      default:
        return type
    }
  }

  const getStatusIcon = (status: string) => {
    switch (status) {
      case "pending":
        return <Clock className="h-4 w-4" />
      case "in_progress":
        return <Settings className="h-4 w-4" />
      case "completed":
        return <CheckCircle className="h-4 w-4" />
      case "cancelled":
        return <AlertTriangle className="h-4 w-4" />
      default:
        return <Clock className="h-4 w-4" />
    }
  }

  const roleColor = theme.roles[userProfile.role as keyof typeof theme.roles] || theme.roles.oficial_almacen

  if (loading) {
    return (
      <div className="text-center py-8">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600 mx-auto"></div>
        <p className="mt-2 text-gray-600">Cargando asignaciones...</p>
      </div>
    )
  }

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <div>
          <h2 className="text-2xl font-bold text-gray-900">Asignaciones de Trabajadores</h2>
          <p className="text-gray-600">
            Supervisa las asignaciones de trabajo para tus entregas ({assignments.length} asignaciones)
          </p>
        </div>
        <Button onClick={fetchAssignments} variant="outline" className="gap-2">
          <RefreshCw className="h-4 w-4" />
          Actualizar
        </Button>
      </div>

      <div className="grid gap-4">
        {assignments.length === 0 ? (
          <Card className="border-2 border-dashed border-gray-200">
            <CardContent className="pt-8 pb-8">
              <div className="text-center">
                <div
                  className={`p-4 rounded-full w-fit mx-auto mb-4 text-white bg-gradient-to-r ${roleColor.gradient}`}
                >
                  <Users className="h-8 w-8" />
                </div>
                <h3 className="text-lg font-medium text-gray-900 mb-2">No hay asignaciones</h3>
                <p className="text-gray-500">
                  Las asignaciones de trabajadores aparecerán aquí cuando crees entregas y asignes personal.
                </p>
                <p className="text-sm text-gray-400 mt-2">
                  Crea una nueva entrega y usa el botón "Asignar Trabajadores" para comenzar.
                </p>
              </div>
            </CardContent>
          </Card>
        ) : (
          assignments.map((assignment) => {
            const statusColor = getStatusColor(assignment.status)
            const workerRoleColor = theme.roles[assignment.worker.role as keyof typeof theme.roles]

            return (
              <Card key={assignment.id} className="border-0 shadow-md hover:shadow-lg transition-shadow">
                <CardHeader className="pb-3">
                  <div className="flex justify-between items-start">
                    <div className="flex items-center gap-3">
                      <div className={`p-2 rounded-lg bg-gradient-to-r ${workerRoleColor.gradient} text-white`}>
                        {getTypeIcon(assignment.assignment_type)}
                      </div>
                      <div>
                        <CardTitle className="text-lg">{assignment.title}</CardTitle>
                        <div className="flex items-center gap-2 mt-1">
                          <Badge variant="outline" className="text-xs">
                            {assignment.worker.full_name}
                          </Badge>
                          <Badge
                            className="text-xs"
                            style={{ backgroundColor: workerRoleColor.light, color: workerRoleColor.primary }}
                          >
                            {getRoleLabel(assignment.worker.role)}
                          </Badge>
                          <Badge variant="outline" className="text-xs">
                            {getTypeLabel(assignment.assignment_type)}
                          </Badge>
                        </div>
                      </div>
                    </div>
                    <div className="flex items-center gap-2">
                      <Badge className={`${statusColor.bg} ${statusColor.text} border ${statusColor.border}`}>
                        <div className="flex items-center gap-1">
                          {getStatusIcon(assignment.status)}
                          {assignment.status.replace("_", " ").toUpperCase()}
                        </div>
                      </Badge>
                      <Dialog>
                        <DialogTrigger asChild>
                          <Button variant="outline" size="sm" onClick={() => setSelectedAssignment(assignment)}>
                            <Eye className="h-4 w-4" />
                          </Button>
                        </DialogTrigger>
                        <DialogContent className="max-w-2xl">
                          <DialogHeader>
                            <DialogTitle>Detalles de la Asignación</DialogTitle>
                            <DialogDescription>Información completa sobre la asignación de trabajo</DialogDescription>
                          </DialogHeader>
                          {selectedAssignment && (
                            <div className="space-y-4">
                              <div className="grid grid-cols-2 gap-4">
                                <div>
                                  <h4 className="font-medium text-gray-900">Trabajador</h4>
                                  <p className="text-sm text-gray-600">{selectedAssignment.worker.full_name}</p>
                                  <p className="text-xs text-gray-500">
                                    {getRoleLabel(selectedAssignment.worker.role)}
                                  </p>
                                  <p className="text-xs text-gray-400">{selectedAssignment.worker.email}</p>
                                </div>
                                <div>
                                  <h4 className="font-medium text-gray-900">Entrega Relacionada</h4>
                                  <p className="text-sm text-gray-600">{selectedAssignment.delivery.title}</p>
                                  <p className="text-xs text-gray-500">
                                    {selectedAssignment.delivery.delivery_address}
                                  </p>
                                </div>
                              </div>

                              {selectedAssignment.description && (
                                <div>
                                  <h4 className="font-medium text-gray-900">Descripción</h4>
                                  <p className="text-sm text-gray-600">{selectedAssignment.description}</p>
                                </div>
                              )}

                              {selectedAssignment.special_instructions && (
                                <div className="p-3 bg-amber-50 rounded-lg">
                                  <h4 className="font-medium text-amber-900 flex items-center gap-1">
                                    <AlertTriangle className="h-4 w-4" />
                                    Instrucciones Especiales
                                  </h4>
                                  <p className="text-sm text-amber-800">{selectedAssignment.special_instructions}</p>
                                </div>
                              )}

                              {selectedAssignment.safety_requirements && (
                                <div className="p-3 bg-red-50 rounded-lg">
                                  <h4 className="font-medium text-red-900 flex items-center gap-1">
                                    <AlertTriangle className="h-4 w-4" />
                                    Requisitos de Seguridad
                                  </h4>
                                  <p className="text-sm text-red-800">{selectedAssignment.safety_requirements}</p>
                                </div>
                              )}

                              <div className="grid grid-cols-2 gap-4 text-xs text-gray-500">
                                <div>
                                  <span className="font-medium">Creado:</span>{" "}
                                  {new Date(selectedAssignment.created_at).toLocaleString()}
                                </div>
                                {selectedAssignment.actual_start && (
                                  <div>
                                    <span className="font-medium">Iniciado:</span>{" "}
                                    {new Date(selectedAssignment.actual_start).toLocaleString()}
                                  </div>
                                )}
                                {selectedAssignment.actual_end && (
                                  <div>
                                    <span className="font-medium">Completado:</span>{" "}
                                    {new Date(selectedAssignment.actual_end).toLocaleString()}
                                  </div>
                                )}
                                <div>
                                  <span className="font-medium">Prioridad:</span>{" "}
                                  <Badge className="text-xs ml-1" variant="outline">
                                    {selectedAssignment.priority.toUpperCase()}
                                  </Badge>
                                </div>
                              </div>
                            </div>
                          )}
                        </DialogContent>
                      </Dialog>
                    </div>
                  </div>
                </CardHeader>
                <CardContent>
                  <div className="space-y-2">
                    <p className="text-sm text-gray-600">
                      <strong>Entrega:</strong> {assignment.delivery.title}
                    </p>
                    <p className="text-sm text-gray-600">
                      <strong>Dirección:</strong> {assignment.delivery.delivery_address}
                    </p>
                    {assignment.scheduled_start && (
                      <p className="text-sm text-gray-600">
                        <strong>Programado:</strong> {new Date(assignment.scheduled_start).toLocaleString()}
                      </p>
                    )}
                    {assignment.equipment_needed && (
                      <p className="text-sm text-gray-600">
                        <strong>Equipos:</strong> {assignment.equipment_needed}
                      </p>
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
