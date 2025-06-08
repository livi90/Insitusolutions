"use client"

import { supabase, type Notification } from "@/lib/supabase"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { useToast } from "@/hooks/use-toast"
import { Bell, Check, Truck, Package, CheckCircle, AlertTriangle, Calendar } from "lucide-react"

interface NotificationCenterProps {
  notifications: Notification[]
  onUpdate: () => void
}

export function NotificationCenter({ notifications, onUpdate }: NotificationCenterProps) {
  const { toast } = useToast()

  const handleMarkAsRead = async (notificationId: string) => {
    try {
      const { error } = await supabase.from("notifications").update({ read: true }).eq("id", notificationId)

      if (error) throw error

      onUpdate()
    } catch (error: any) {
      toast({
        title: "Error",
        description: error.message,
        variant: "destructive",
      })
    }
  }

  const handleMarkAllAsRead = async () => {
    try {
      const { error } = await supabase.from("notifications").update({ read: true }).eq("read", false)

      if (error) throw error

      toast({
        title: "Notificaciones marcadas",
        description: "Todas las notificaciones han sido marcadas como leídas",
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

  const getNotificationIcon = (type: string) => {
    switch (type) {
      case "delivery_assigned":
        return <Package className="h-4 w-4" />
      case "delivery_in_transit":
        return <Truck className="h-4 w-4" />
      case "delivery_delivered":
      case "delivery_completed":
        return <CheckCircle className="h-4 w-4" />
      case "work_assignment":
        return <Calendar className="h-4 w-4" />
      case "work_started":
      case "work_completed":
        return <CheckCircle className="h-4 w-4" />
      case "system":
        return <AlertTriangle className="h-4 w-4" />
      default:
        return <Bell className="h-4 w-4" />
    }
  }

  const getNotificationColor = (type: string) => {
    switch (type) {
      case "delivery_assigned":
        return "bg-blue-100 text-blue-800"
      case "delivery_in_transit":
        return "bg-purple-100 text-purple-800"
      case "delivery_delivered":
      case "delivery_completed":
      case "work_completed":
        return "bg-green-100 text-green-800"
      case "work_assignment":
        return "bg-indigo-100 text-indigo-800"
      case "work_started":
        return "bg-blue-100 text-blue-800"
      case "system":
      case "welcome":
        return "bg-amber-100 text-amber-800"
      default:
        return "bg-gray-100 text-gray-800"
    }
  }

  const unreadCount = notifications.filter((n) => !n.read).length

  return (
    <div className="space-y-4">
      <div className="flex justify-between items-center">
        <div>
          <h2 className="text-2xl font-bold text-gray-900">Centro de Notificaciones</h2>
          <p className="text-sm text-gray-600">
            {unreadCount > 0
              ? `Tienes ${unreadCount} notificaciones sin leer`
              : "Todas las notificaciones están al día"}
          </p>
        </div>
        {unreadCount > 0 && (
          <Button variant="outline" size="sm" onClick={handleMarkAllAsRead} className="gap-2">
            <Check className="h-4 w-4" />
            Marcar todas como leídas
          </Button>
        )}
      </div>

      <div className="space-y-3">
        {notifications.length === 0 ? (
          <Card className="border-0 shadow-md">
            <CardContent className="pt-6">
              <div className="text-center py-8">
                <div className="p-4 bg-gradient-to-r from-blue-600 to-indigo-600 rounded-full w-fit mx-auto mb-4 text-white">
                  <Bell className="h-8 w-8" />
                </div>
                <h3 className="mt-2 text-lg font-medium text-gray-900">No hay notificaciones</h3>
                <p className="mt-1 text-gray-500">
                  Las notificaciones aparecerán aquí cuando haya actividad relevante.
                </p>
              </div>
            </CardContent>
          </Card>
        ) : (
          notifications.map((notification) => {
            const notificationColor = getNotificationColor(notification.type)

            return (
              <Card
                key={notification.id}
                className={`border-0 shadow-sm hover:shadow-md transition-shadow ${notification.read ? "opacity-60" : ""}`}
              >
                <CardHeader className="pb-3">
                  <div className="flex justify-between items-start">
                    <div className="flex items-center gap-2">
                      <div className={`p-1.5 rounded-full ${notificationColor}`}>
                        {getNotificationIcon(notification.type)}
                      </div>
                      <CardTitle className="text-base">{notification.title}</CardTitle>
                      {!notification.read && (
                        <Badge variant="secondary" className="text-xs bg-blue-100 text-blue-800">
                          Nuevo
                        </Badge>
                      )}
                    </div>
                    <div className="flex items-center gap-2">
                      <span className="text-xs text-muted-foreground">
                        {new Date(notification.created_at).toLocaleString()}
                      </span>
                      {!notification.read && (
                        <Button variant="outline" size="sm" onClick={() => handleMarkAsRead(notification.id)}>
                          <Check className="h-3 w-3" />
                        </Button>
                      )}
                    </div>
                  </div>
                </CardHeader>
                <CardContent>
                  <CardDescription className="text-gray-700">{notification.message}</CardDescription>
                </CardContent>
              </Card>
            )
          })
        )}
      </div>
    </div>
  )
}
