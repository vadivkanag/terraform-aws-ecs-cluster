resource "aws_ecs_cluster" "this" {
  count = var.create ? 1 : 0

  name = var.cluster_name

  dynamic "configuration" {
    for_each = var.create_cloudwatch_log_group ? [var.cluster_configuration] : []

    content {
      dynamic "execute_command_configuration" {
        for_each = try([merge(local.execute_command_configuration, configuration.value.execute_command_configuration)], [{}])

        content {
          kms_key_id = try(execute_command_configuration.value.kms_key_id, null)
          logging    = try(execute_command_configuration.value.logging, "DEFAULT")

          dynamic "log_configuration" {
            for_each = try([execute_command_configuration.value.log_configuration], [])

            content {
              cloud_watch_encryption_enabled = try(log_configuration.value.cloud_watch_encryption_enabled, null)
              cloud_watch_log_group_name     = try(log_configuration.value.cloud_watch_log_group_name, null)
              s3_bucket_name                 = try(log_configuration.value.s3_bucket_name, null)
              s3_bucket_encryption_enabled   = try(log_configuration.value.s3_bucket_encryption_enabled, null)
              s3_key_prefix                  = try(log_configuration.value.s3_key_prefix, null)
            }
          }
        }
      }
    }
  }

  tags = var.tags
}

output "ecs_cluster_id" {
  description = "Id of the ecs cluster"
  value       = aws_ecs_cluster.this[0].id
}

resource "aws_cloudwatch_log_group" "ecs_cluster" {
  count = var.create && var.create_cloudwatch_log_group ? 1 : 0

  name              = "/aws/ecs/${var.cluster_name}-${var.environment}"
  retention_in_days = var.cloudwatch_log_group_retention_in_days
  kms_key_id        = var.cloudwatch_log_group_kms_key_id

  tags = merge(var.tags, var.cloudwatch_log_group_tags)
}

output "log_group_name" {
  value = aws_cloudwatch_log_group.ecs_cluster[0].name
}
