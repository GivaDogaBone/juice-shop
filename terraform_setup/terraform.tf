terraform {
  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "GivaDogaBone"

    workspaces {
      name = "learn-terraform-circleci"
    }
  }
}

provider "aws" {
  region = var.region
  version = "~> 2.7"
}

provider "template" {
}

resource "aws_iam_user" "circleci" {
  name = var.user
  path = "/system/"
}

resource "aws_iam_access_key" "circleci" {
  user = aws_iam_user.circleci.name
}

resource "local_file" "circle_credentials" {
  filename = "tmp/circleci_credentials"
  content  = "${aws_iam_access_key.circleci.id}\n${aws_iam_access_key.circleci.secret}"
}

locals {
  # The name of the CloudFormation stack to be created for the VPC and related resources
  aws_vpc_stack_name = "${var.app}-vpc-stack"
  # The name of the CloudFormation stack to be created for the ECS service and related resources
  aws_ecs_service_stack_name = "${var.app}-svc-stack"
  # The name of the ECR repository to be created
  aws_ecr_repository_name = "${var.app}"
  # The name of the ECS cluster to be created
  aws_ecs_cluster_name = "${var.app}-cluster"
  # The name of the ECS service to be created
  aws_ecs_service_name = "${var.app}-service"
  # The name of the execution role to be created
  aws_ecs_execution_role_name = "${var.app}-ecs-execution-role"
}

resource "aws_ecr_repository" "demo-app-repository" {
  name = local.aws_ecr_repository_name
}
resource "aws_cloudformation_stack" "vpc" {
  name = local.aws_vpc_stack_name
  template_body = file("cloudformation-templates/public-vpc.yml")
  capabilities = ["CAPABILITY_NAMED_IAM"]
  parameters = {
    ClusterName = "${local.aws_ecs_cluster_name}"
    ExecutionRoleName = "${local.aws_ecs_execution_role_name}"
  }
}

# Note: creates task definition and task definition family with the same name as the ServiceName parameter value
resource "aws_cloudformation_stack" "ecs_service" {
  name = local.aws_ecs_service_stack_name
  template_body = file("cloudformation-templates/public-service.yml")
  depends_on = [aws_cloudformation_stack.vpc, aws_ecr_repository.demo-app-repository]

  parameters = {
    ContainerMemory = 1024
    ContainerPort = 80
    StackName = "${local.aws_vpc_stack_name}"
    ServiceName = "${local.aws_ecs_service_name}"
    # Note: Since ImageUrl parameter is not specified, the Service
    # will be deployed with the nginx image when created
  }
}
