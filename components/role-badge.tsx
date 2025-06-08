import { getRoleColor, getRoleLabel } from "@/lib/theme"

interface RoleBadgeProps {
  role: string
  showLabel?: boolean
  size?: "sm" | "md" | "lg"
}

export function RoleBadge({ role, showLabel = true, size = "md" }: RoleBadgeProps) {
  const roleColor = getRoleColor(role)
  const roleLabel = getRoleLabel(role)

  const sizeClasses = {
    sm: "h-6 text-xs",
    md: "h-8 text-sm",
    lg: "h-10 text-base",
  }

  return (
    <div
      className={`${roleColor.gradient} ${sizeClasses[size]} flex items-center justify-center rounded-full px-3 font-medium text-white shadow-sm`}
    >
      {showLabel ? roleLabel : role}
    </div>
  )
}
