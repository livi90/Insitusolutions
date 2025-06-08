"use client"

import { getRoleColor, getRoleDescription, getRoleLabel } from "@/lib/theme"

interface RoleCardProps {
  role: string
  count?: number
  onClick?: () => void
}

export function RoleCard({ role, count, onClick }: RoleCardProps) {
  const roleColor = getRoleColor(role)
  const roleLabel = getRoleLabel(role)
  const roleDescription = getRoleDescription(role)

  return (
    <div
      onClick={onClick}
      className={`${roleColor.gradient} cursor-pointer rounded-xl p-4 text-white shadow-md transition-transform hover:scale-105 hover:shadow-lg`}
    >
      <div className="flex items-center justify-between">
        <h3 className="text-lg font-bold">{roleLabel}</h3>
        {count !== undefined && (
          <span className="flex h-8 w-8 items-center justify-center rounded-full bg-white/20 text-sm font-bold">
            {count}
          </span>
        )}
      </div>
      <p className="mt-2 text-sm opacity-90">{roleDescription}</p>
    </div>
  )
}
