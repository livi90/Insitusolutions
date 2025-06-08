// Paleta de colores mejorada para In-Situ Solutions
export const theme = {
  // Colores principales de la marca
  brand: {
    primary: "#0F52BA", // Azul In-Situ
    secondary: "#1E40AF", // Azul oscuro
    accent: "#3B82F6", // Azul claro
    light: "#EFF6FF", // Azul muy claro
  },

  // Colores para roles específicos con mejor contraste
  roles: {
    oficial_almacen: {
      primary: "#1E40AF", // Azul oscuro
      secondary: "#2563EB",
      light: "#DBEAFE",
      bg: "#1E40AF",
      text: "#FFFFFF",
      lightBg: "#EBF8FF",
      lightText: "#1E40AF",
      gradient: "role-oficial-almacen",
      css: "bg-blue-600 text-white",
      hoverCss: "hover:bg-blue-700",
    },
    transportista: {
      primary: "#047857", // Verde
      secondary: "#059669",
      light: "#D1FAE5",
      bg: "#047857",
      text: "#FFFFFF",
      lightBg: "#ECFDF5",
      lightText: "#047857",
      gradient: "role-transportista",
      css: "bg-green-600 text-white",
      hoverCss: "hover:bg-green-700",
    },
    encargado_obra: {
      primary: "#F97316", // Naranja más vibrante
      secondary: "#FB923C",
      light: "#FEF3C7",
      bg: "#F97316",
      text: "#FFFFFF",
      lightBg: "#FFF7ED",
      lightText: "#C2410C",
      gradient: "role-encargado-obra",
      css: "bg-orange-500 text-white",
      hoverCss: "hover:bg-orange-600",
    },
    operario_maquinaria: {
      primary: "#7C3AED", // Púrpura
      secondary: "#8B5CF6",
      light: "#EDE9FE",
      bg: "#7C3AED",
      text: "#FFFFFF",
      lightBg: "#F5F3FF",
      lightText: "#7C3AED",
      gradient: "role-operario-maquinaria",
      css: "bg-purple-600 text-white",
      hoverCss: "hover:bg-purple-700",
    },
    peon_logistica: {
      primary: "#0EA5E9", // Azul cyan más vibrante
      secondary: "#38BDF8",
      light: "#E0F2FE",
      bg: "#0EA5E9",
      text: "#FFFFFF",
      lightBg: "#F0F9FF",
      lightText: "#0369A1",
      gradient: "role-peon-logistica",
      css: "bg-sky-500 text-white",
      hoverCss: "hover:bg-sky-600",
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

// Función para obtener clases CSS responsivas
export function getResponsiveClasses(baseClasses: string, mobileClasses?: string) {
  return `${baseClasses} ${mobileClasses ? `sm:${baseClasses} ${mobileClasses}` : ""}`
}
