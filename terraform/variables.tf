variable "region" {
    type        =   string
    description =   "Region in which cluster to be deployed"
}

variable "project" {
    type        =   string
}
variable "cluster_name" {
    type        =   string
    description =   "Cluster name"
}

variable "trusted_ip" {
    type        =   string
    description =   "Trusted IP address"
}

variable "min_nodes" {
    type        =   string
}

variable "max_nodes" {
    type        =   string
}

variable "auto_upgrade" {
    type        =   string
    default     =   false
}

variable "machine_type" {
    type        =   string
    default     =   "e2-medium"
}