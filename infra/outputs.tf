output "database_endpoint" {
  description = "RDS database endpoint"
  value       = module.database.db_endpoint
}

output "database_name" {
  description = "Name of the database"
  value       = module.database.db_name
}

output "database_port" {
  description = "Database port"
  value       = module.database.db_port
}

output "database_security_group_id" {
  description = "Security group ID for database access"
  value       = module.database.db_security_group_id
}

output "connection_string" {
  description = "PostgreSQL connection string (without password)"
  value       = "postgresql://${var.db_username}:PASSWORD@${module.database.db_endpoint}/${var.db_name}"
  sensitive   = true
}
