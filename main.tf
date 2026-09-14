# ==========================================
# 1. СЕРВИСНЫЙ АККАУНТ ДЛЯ БАКЕТА
# ==========================================
resource "yandex_iam_service_account" "sa" {
  name = "bucket-sa-kms"
}

resource "yandex_iam_service_account_static_access_key" "sa-key" {
  service_account_id = yandex_iam_service_account.sa.id
}

# Роли для сервисного аккаунта
resource "yandex_resourcemanager_folder_iam_member" "sa-roles" {
  folder_id = var.folder_id
  for_each  = toset([
    "storage.admin",
    "kms.keys.encrypterDecrypter"
  ])
  role   = each.value
  member = "serviceAccount:${yandex_iam_service_account.sa.id}"
}

# ==========================================
# 2. КЛЮЧ KMS ДЛЯ ШИФРОВАНИЯ
# ==========================================
resource "yandex_kms_symmetric_key" "bucket-key" {
  name              = var.kms_key_name
  description       = "Симметричный ключ для шифрования бакета"
  default_algorithm = "AES_128"
  rotation_period   = "8760h"  # 1 год

  depends_on = [yandex_resourcemanager_folder_iam_member.sa-roles]
}

# ==========================================
# 3. БАКЕТ С ШИФРОВАНИЕМ
# ==========================================
resource "yandex_storage_bucket" "bucket" {
  bucket     = var.bucket_name
  access_key = yandex_iam_service_account_static_access_key.sa-key.access_key
  secret_key = yandex_iam_service_account_static_access_key.sa-key.secret_key
  acl        = "public-read"

  # Шифрование по умолчанию через KMS
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = yandex_kms_symmetric_key.bucket-key.id
        sse_algorithm     = "aws:kms"
      }
    }
  }

  depends_on = [
    yandex_kms_symmetric_key.bucket-key,
    yandex_resourcemanager_folder_iam_member.sa-roles
  ]
}

# ==========================================
# 4. ЗАГРУЗКА КАРТИНКИ В ЗАШИФРОВАННЫЙ БАКЕТ
# ==========================================
resource "yandex_storage_object" "image" {
  access_key = yandex_iam_service_account_static_access_key.sa-key.access_key
  secret_key = yandex_iam_service_account_static_access_key.sa-key.secret_key
  bucket     = yandex_storage_bucket.bucket.bucket
  key        = "Game.png"
  source     = "${path.module}/Game.png"
  acl        = "public-read"

  depends_on = [yandex_storage_bucket.bucket]
}

# ==========================================
# 5. ВЫХОДНЫЕ ДАННЫЕ
# ==========================================
output "kms_key_id" {
  value       = yandex_kms_symmetric_key.bucket-key.id
  description = "ID ключа KMS"
}

output "bucket_name" {
  value       = yandex_storage_bucket.bucket.bucket
  description = "Имя бакета"
}

output "image_url" {
  value       = "https://storage.yandexcloud.net/${var.bucket_name}/Game.png"
  description = "URL картинки"
}

# ==========================================
# 5. ПОЛИТИКА ПУБЛИЧНОГО ДОСТУПА К БАКЕТУ
# ==========================================
resource "yandex_storage_bucket_policy" "public" {
  bucket     = yandex_storage_bucket.bucket.bucket
  access_key = yandex_iam_service_account_static_access_key.sa-key.access_key
  secret_key = yandex_iam_service_account_static_access_key.sa-key.secret_key

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = ["s3:GetObject"]
        Resource  = ["arn:aws:s3:::${yandex_storage_bucket.bucket.bucket}/*"]
      }
    ]
  })
}
