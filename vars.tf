variable "yourname" {
  description = "name of project"
  type        = string
}

variable "location" {
  description = "location of project"
  type        = string
}

variable "admin_username" {
  description = "admin username for the virtual machine"
  type        = string
}

variable "admin_password" {
  description = "admin password for the virtual machine"
  type        = string
  sensitive   = true
}

