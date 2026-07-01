output "alb_dns" {
  value = aws_lb.stage_alb.dns_name
}

output "target_group_arn" {
  value = aws_lb_target_group.stage_tg.arn
}

output "asg_name" {
  value = aws_autoscaling_group.stage.name
}