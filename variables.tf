variable "token" {
  type      = string
  sensitive = true
}

variable "cloud_id" {
  type      = string
  sensitive = true
}

variable "folder_id" {
  type      = string
  sensitive = true
}

variable "default_zone" {
  type    = string
  default = "ru-central1-a"
}

variable "bucket_name" {
  type    = string
  default = "ekwest93-08092026"
}

variable "kms_key_name" {
  type    = string
  default = "bucket-encryption-key"
}
