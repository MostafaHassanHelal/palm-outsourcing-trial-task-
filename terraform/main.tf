provider "aws" {
  region = "us-east-1"
}

# 1. Dead Letter Queue (DLQ) for failed messages
resource "aws_sqs_queue" "payouts_dlq" {
  name = "payouts-worker-dlq"
}

# 2. Main Processing Queue with Redrive Policy
resource "aws_sqs_queue" "payouts_queue" {
  name                      = "payouts-worker-queue"
  message_retention_seconds = 86400 # 1 day
  visibility_timeout_seconds = 60   # Time for worker to process

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.payouts_dlq.arn
    maxReceiveCount     = 5 # Move to DLQ after 5 failed attempts
  })
}

# 3. CloudWatch Alarm: Alert if ANY message hits the DLQ
resource "aws_cloudwatch_metric_alarm" "dlq_depth_alarm" {
  alarm_name          = "PayoutsDLQNotEmpty"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = "60"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "This metric monitors the Payouts DLQ for failed messages"
  dimensions = {
    QueueName = aws_sqs_queue.payouts_dlq.name
  }
}

# 4. Minimal IAM Policy for the Worker App
resource "aws_iam_policy" "payout_worker_policy" {
  name        = "PayoutWorkerQueueAccess"
  description = "Allows worker to read/delete from payouts queue"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.payouts_queue.arn
      }
    ]
  })
}