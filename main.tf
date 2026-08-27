provider "aws" {
  region     = var.aws_region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

# 1. IAM ROLE & INSTANCE PROFILE (SSM)


resource "aws_iam_role" "ssm_role" {
  name = "ec2-ssm-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "ec2.amazonaws.com" }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_attach" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_profile" {
  name = "ec2-ssm-instance-profile"
  role = aws_iam_role.ssm_role.name
}

# 2. EC2 INSTANCES


resource "aws_instance" "ServerA" {
  count                = 4
  ami                  = var.ami_id
  instance_type        = var.instance_type
  subnet_id            = "subnet-0ec962c63c2ea7edf"
  iam_instance_profile = aws_iam_instance_profile.ssm_profile.name

  tags = {
    Name       = "${var.instance_name}-${count.index + 1}"
    PatchGroup = "Production-Patching"
  }
}

# 3. PATCH & VULNERABILITY MANAGEMENT (SSM & INSPECTOR)


resource "aws_ssm_patch_baseline" "ubuntu_baseline" {
  name             = "Custom-Patch-baseline"
  operating_system = "UBUNTU"

  approval_rule {
    approve_after_days = 7
    compliance_level   = "HIGH"

    patch_filter {
      key    = "PRODUCT"
      values = ["*"]
    }

    patch_filter {
      key    = "PRIORITY"
      values = ["Required", "Important", "Standard"]
    }
  }
}

resource "aws_ssm_patch_group" "patch_group" {
  baseline_id = aws_ssm_patch_baseline.ubuntu_baseline.id
  patch_group = "Production-Patching"
}

resource "aws_ssm_association" "patch_association" {
  name = "AWS-RunPatchBaseline"

  targets {
    key    = "tag:PatchGroup"
    values = ["Production-Patching"]
  }

  schedule_expression = "cron(0 02 ? * SUN *)"

  parameters = {
    Operation = "Install"
  }
}

data "aws_caller_identity" "current" {}

resource "aws_inspector2_enabling" "inspector" {
  account_ids    = [data.aws_caller_identity.current.account_id]
  resource_types = ["EC2"]
}


# 4. MONITORING & ALERTS (SNS & CLOUDWATCH)


resource "aws_sns_topic" "sys_alerts" {
  name = "infrastructure-health-alerts"
}

resource "aws_sns_topic_subscription" "email_alert" {
  topic_arn = aws_sns_topic.sys_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_metric_alarm" "status_check_alarm" {
  count               = 4
  alarm_name          = "StatusCheckFailed-${aws_instance.ServerA[count.index].id}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Maximum"
  threshold           = 1
  alarm_description   = "Triggered when instance status check fails."

  dimensions = {
    InstanceId = aws_instance.ServerA[count.index].id
  }

  alarm_actions = [aws_sns_topic.sys_alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "high_cpu_alarm" {
  count               = 4
  alarm_name          = "HighCPU-${aws_instance.ServerA[count.index].id}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 85
  alarm_description   = "Triggered when CPU utilization exceeds 85%."

  dimensions = {
    InstanceId = aws_instance.ServerA[count.index].id
  }

  alarm_actions = [aws_sns_topic.sys_alerts.arn]
}