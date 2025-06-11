// Tema restaurado a la versión 23 - Solo roles originales
export const theme = {
  roles: {
    oficial_almacen: {
      primary: "#2563eb",
      secondary: "#1d4ed8",
      accent: "#3b82f6",
      css: "bg-blue-100 text-blue-800",
    },
    transportista: {
      primary: "#059669",
      secondary: "#047857",
      accent: "#10b981",
      css: "bg-green-100 text-green-800",
    },
    encargado_obra: {
      primary: "#f97316",
      secondary: "#ea580c",
      accent: "#fb923c",
      css: "bg-orange-100 text-orange-800",
    },
  },
  status: {
    pending: "bg-yellow-100 text-yellow-800",
    assigned: "bg-blue-100 text-blue-800",
    in_progress: "bg-purple-100 text-purple-800",
    in_transit: "bg-purple-100 text-purple-800",
    delivered: "bg-green-100 text-green-800",
    completed: "bg-gray-100 text-gray-800",
    approved: "bg-green-100 text-green-800",
    rejected: "bg-red-100 text-red-800",
  },
}

export function getRoleColor(role: string) {
  return theme.roles[role as keyof typeof theme.roles] || theme.roles.transportista
}

export function getStatusColor(status: string) {
  return theme.status[status as keyof typeof theme.status] || theme.status.pending
}

export function getRoleLabel(role: string) {
  switch (role) {
    case "oficial_almacen":
      return "Oficial de Almacén"
    case "transportista":
      return "Transportista"
    case "encargado_obra":
      return "Encargado de Obra"
    default:
      return role
  }
}

export function getRoleDescription(role: string) {
  switch (role) {
    case "oficial_almacen":
      return "Gestiona inventario, entregas y coordina operaciones logísticas"
    case "transportista":
      return "Realiza entregas y transporta materiales entre ubicaciones"
    case "encargado_obra":
      return "Supervisa obras, solicita materiales y coordina trabajadores"
    default:
      return "Usuario del sistema"
  }
}
