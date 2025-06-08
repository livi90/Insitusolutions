// Paleta de colores para In-Situ Solutions
export const theme = {
  // Colores principales de la marca
  brand: {
    primary: "#0F52BA", // Azul In-Situ
    secondary: "#1E40AF", // Azul oscuro
    accent: "#3B82F6", // Azul claro
    light: "#EFF6FF", // Azul muy claro
  },

  // Colores para roles específicos
  roles: {
    oficial_almacen: {
      primary: "#1E40AF", // Azul oscuro
      secondary: "#2563EB",
      light: "#DBEAFE",
      gradient: "from-blue-600 to-blue-700",
      hover: "from-blue-700 to-blue-800",
    },
    transportista: {
      primary: "#047857", // Verde
      secondary: "#059669",
      light: "#D1FAE5",
      gradient: "from-green-600 to-green-700",
      hover: "from-green-700 to-green-800",
    },
    encargado_obra: {
      primary: "#B45309", // Naranja
      secondary: "#D97706",
      light: "#FEF3C7",
      gradient: "from-orange-500 to-orange-600",
      hover: "from-orange-600 to-orange-700",
    },
    operario_maquinaria: {
      primary: "#6D28D9", // Púrpura
      secondary: "#7C3AED",
      light: "#EDE9FE",
      gradient: "from-purple-600 to-purple-700",
      hover: "from-purple-700 to-purple-800",
    },
    peon_logistica: {
      primary: "#0F766E", // Teal
      secondary: "#0D9488",
      light: "#CCFBF1",
      gradient: "from-teal-600 to-teal-700",
      hover: "from-teal-700 to-teal-800",
    },
  },

  // Colores para estados
  status: {
    pending: {
      bg: "bg-yellow-100",
      text: "text-yellow-800",
      border: "border-yellow-200",
      icon: "text-yellow-600",
    },
    assigned: {
      bg: "bg-blue-100",
      text: "text-blue-800",
      border: "border-blue-200",
      icon: "text-blue-600",
    },
    in_progress: {
      bg: "bg-indigo-100",
      text: "text-indigo-800",
      border: "border-indigo-200",
      icon: "text-indigo-600",
    },
    in_transit: {
      bg: "bg-purple-100",
      text: "text-purple-800",
      border: "border-purple-200",
      icon: "text-purple-600",
    },
    delivered: {
      bg: "bg-green-100",
      text: "text-green-800",
      border: "border-green-200",
      icon: "text-green-600",
    },
    completed: {
      bg: "bg-green-100",
      text: "text-green-800",
      border: "border-green-200",
      icon: "text-green-600",
    },
    cancelled: {
      bg: "bg-red-100",
      text: "text-red-800",
      border: "border-red-200",
      icon: "text-red-600",
    },
  },

  // Colores para prioridades
  priority: {
    low: "bg-gray-500 text-white",
    normal: "bg-blue-500 text-white",
    high: "bg-orange-500 text-white",
    urgent: "bg-red-500 text-white",
  },

  // Gradientes
  gradients: {
    primary: "bg-gradient-to-r from-blue-600 to-indigo-700",
    secondary: "bg-gradient-to-r from-indigo-500 to-purple-600",
    header: "bg-gradient-to-r from-blue-700 to-indigo-800",
    sidebar: "bg-gradient-to-b from-gray-800 to-gray-900",
    card: "bg-gradient-to-br from-white to-gray-50",
  },
}

// Función para obtener el color de rol
export function getRoleColor(role: string) {
  const roleKey = role as keyof typeof theme.roles
  return theme.roles[roleKey] || theme.roles.transportista
}

// Función para obtener el color de estado
export function getStatusColor(status: string) {
  const statusKey = status as keyof typeof theme.status
  return theme.status[statusKey] || theme.status.pending
}

// Función para obtener el color de prioridad
export function getPriorityColor(priority: string) {
  const priorityKey = priority as keyof typeof theme.priority
  return theme.priority[priorityKey] || theme.priority.normal
}

// Función para obtener el nombre del rol
export function getRoleLabel(role: string) {
  switch (role) {
    case "oficial_almacen":
      return "Oficial de Almacén"
    case "transportista":
      return "Transportista"
    case "encargado_obra":
      return "Encargado de Obra"
    case "operario_maquinaria":
      return "Operario de Maquinaria"
    case "peon_logistica":
      return "Peón de Logística"
    default:
      return role
  }
}

// Función para obtener la descripción del rol
export function getRoleDescription(role: string) {
  switch (role) {
    case "oficial_almacen":
      return "Gestiona inventario, entregas y coordina operaciones"
    case "transportista":
      return "Realiza entregas y transporta materiales"
    case "encargado_obra":
      return "Supervisa obras y gestiona solicitudes"
    case "operario_maquinaria":
      return "Opera grúas, excavadoras y maquinaria pesada"
    case "peon_logistica":
      return "Apoya en descarga, señalización y logística"
    default:
      return ""
  }
}
