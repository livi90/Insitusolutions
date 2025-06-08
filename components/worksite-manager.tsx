"use client"

import type React from "react"

import { useState, useEffect } from "react"
import { supabase, type WorkSite, type UserProfile } from "@/lib/supabase"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Textarea } from "@/components/ui/textarea"
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog"
import { useToast } from "@/hooks/use-toast"
import { Plus, MapPin, Users } from "lucide-react"

interface WorkSiteManagerProps {
  userProfile: UserProfile
}

export function WorkSiteManager({ userProfile }: WorkSiteManagerProps) {
  const { toast } = useToast()
  const [workSites, setWorkSites] = useState<WorkSite[]>([])
  const [showCreateDialog, setShowCreateDialog] = useState(false)
  const [loading, setLoading] = useState(false)
  const [newWorkSite, setNewWorkSite] = useState({
    name: "",
    address: "",
    description: "",
  })

  useEffect(() => {
    fetchWorkSites()
  }, [userProfile])

  const fetchWorkSites = async () => {
    try {
      const { data, error } = await supabase
        .from("work_sites")
        .select("*")
        .eq("site_manager_id", userProfile.id)
        .order("created_at", { ascending: false })

      if (error) throw error
      setWorkSites(data || [])
    } catch (error) {
      console.error("Error fetching work sites:", error)
    }
  }

  const handleCreateWorkSite = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true)

    try {
      const { error } = await supabase.from("work_sites").insert({
        ...newWorkSite,
        site_manager_id: userProfile.id,
      })

      if (error) throw error

      toast({
        title: "Obra creada",
        description: "La obra ha sido creada exitosamente",
      })

      setNewWorkSite({
        name: "",
        address: "",
        description: "",
      })
      setShowCreateDialog(false)
      fetchWorkSites()
    } catch (error: any) {
      toast({
        title: "Error",
        description: error.message,
        variant: "destructive",
      })
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="space-y-4">
      <div className="flex justify-between items-center">
        <div>
          <h2 className="text-lg font-semibold">Gestión de Obras</h2>
          <p className="text-sm text-muted-foreground">Administra tus sitios de trabajo y equipos</p>
        </div>
        <Dialog open={showCreateDialog} onOpenChange={setShowCreateDialog}>
          <DialogTrigger asChild>
            <Button>
              <Plus className="h-4 w-4 mr-2" />
              Nueva Obra
            </Button>
          </DialogTrigger>
          <DialogContent>
            <DialogHeader>
              <DialogTitle>Crear Nueva Obra</DialogTitle>
              <DialogDescription>Completa los detalles de la nueva obra</DialogDescription>
            </DialogHeader>
            <form onSubmit={handleCreateWorkSite} className="space-y-4">
              <div className="space-y-2">
                <Label htmlFor="name">Nombre de la Obra</Label>
                <Input
                  id="name"
                  value={newWorkSite.name}
                  onChange={(e) => setNewWorkSite({ ...newWorkSite, name: e.target.value })}
                  required
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="address">Dirección</Label>
                <Input
                  id="address"
                  value={newWorkSite.address}
                  onChange={(e) => setNewWorkSite({ ...newWorkSite, address: e.target.value })}
                  required
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="description">Descripción</Label>
                <Textarea
                  id="description"
                  value={newWorkSite.description}
                  onChange={(e) => setNewWorkSite({ ...newWorkSite, description: e.target.value })}
                  rows={3}
                />
              </div>
              <Button type="submit" disabled={loading} className="w-full">
                {loading ? "Creando..." : "Crear Obra"}
              </Button>
            </form>
          </DialogContent>
        </Dialog>
      </div>

      <div className="grid gap-4">
        {workSites.length === 0 ? (
          <Card>
            <CardContent className="pt-6">
              <div className="text-center py-8">
                <MapPin className="mx-auto h-12 w-12 text-gray-400" />
                <h3 className="mt-2 text-sm font-medium text-gray-900">No hay obras</h3>
                <p className="mt-1 text-sm text-gray-500">Comienza creando tu primera obra.</p>
              </div>
            </CardContent>
          </Card>
        ) : (
          workSites.map((workSite) => (
            <Card key={workSite.id}>
              <CardHeader>
                <div className="flex justify-between items-start">
                  <div>
                    <CardTitle className="text-lg">{workSite.name}</CardTitle>
                    <CardDescription className="mt-1 flex items-center gap-1">
                      <MapPin className="h-4 w-4" />
                      {workSite.address}
                    </CardDescription>
                  </div>
                </div>
              </CardHeader>
              <CardContent>
                {workSite.description && <p className="text-sm text-gray-600 mb-4">{workSite.description}</p>}
                <div className="flex items-center gap-4 text-sm text-muted-foreground">
                  <span className="flex items-center gap-1">
                    <Users className="h-4 w-4" />
                    Creada el {new Date(workSite.created_at).toLocaleDateString()}
                  </span>
                </div>
              </CardContent>
            </Card>
          ))
        )}
      </div>
    </div>
  )
}
