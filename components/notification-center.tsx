"use client"

import { supabase, type Notification } from "@/lib/supabase"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { useToast } from "@/hooks/use-toast"
import { Bell, Check } from "lucide-react"

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
      case "delivery_in_transit":
      case "delivery_completed":
        return <Bell className="h-4 w-4" />
      default:
        return <Bell className="h-4 w-4" />
    }
  }

  const unreadCount = notifications.filter((n) => !n.read).length

  return (
    <div className="space-y-4">
      <div className="flex justify-between items-center">
        <div>
          <h2 className="text-lg font-semibold">Centro de Notificaciones</h2>
          <p className="text-sm text-muted-foreground">
            {unreadCount > 0
              ? `Tienes ${unreadCount} notificaciones sin leer`
              : "Todas las notificaciones están al día"}
          </p>
        </div>
        {unreadCount > 0 && (
          <Button variant="outline" size="sm" onClick={handleMarkAllAsRead}>
            <Check className="h-4 w-4 mr-2" />
            Marcar todas como leídas
          </Button>
        )}
      </div>

      <div className="space-y-3">
        {notifications.length === 0 ? (
          <Card>
            <CardContent className="pt-6">
              <div className="text-center py-8">
                <Bell className="mx-auto h-12 w-12 text-gray-400" />
                <h3 className="mt-2 text-sm font-medium text-gray-900">No hay notificaciones</h3>
                <p className="mt-1 text-sm text-gray-500">
                  Las notificaciones aparecerán aquí cuando haya actividad relevante.
                </p>
              </div>
            </CardContent>
          </Card>
        ) : (
          notifications.map((notification) => (
            <Card key={notification.id} className={notification.read ? "opacity-60" : ""}>
              <CardHeader className="pb-3">
                <div className="flex justify-between items-start">
                  <div className="flex items-center gap-2">
                    {getNotificationIcon(notification.type)}
                    <CardTitle className="text-base">{notification.title}</CardTitle>
                    {!notification.read && (
                      <Badge variant="secondary" className="text-xs">
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
                <CardDescription>{notification.message}</CardDescription>
              </CardContent>
            </Card>
          ))
        )}
      </div>
    </div>
  )
}
