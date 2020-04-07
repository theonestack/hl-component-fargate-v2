# fargate-v2 CfHighlander component

Deploys a ECS fargates service with support for creating and managing ALB/NLB target groups

[![Build Status](https://travis-ci.com/theonestack/hl-component-fargate-v2.svg?branch=master)](https://travis-ci.com/theonestack/hl-component-fargate-v2)

# vpc-v2 CfHighlander component

Base component in which to build AWS network based resources from such as EC2, RDS and ECS

```bash
kurgan add fargate-v2
```

## Requirements

## Parameters

| Name | Use | Default | Global | Type | Allowed Values |
| ---- | --- | ------- | ------ | ---- | -------------- |
| EnvironmentName | Tagging | dev | true | string
| EnvironmentType | Tagging | development | true | string | ['development','production']
| VPCId | Security Groups | None | false | AWS::EC2::VPC::Id
| SubnetIds | list of subnets | None | false | CommaDelimitedList
| EcsCluster | ecs cluster to deploy to | None | false | string
| LoadBalancer | ALB/NLB | None | false | string (arn)
| LoadBalancer | ALB/NLB | None | false | string (arn)
| Listener | ALB/NLB listener | None | false | string (arn
| DesiredCount | No running tasks | 1 | false | int
| MinimumHealthyPercent | Deployment | 100 | false | int
| MaximumPercent | Deployment | 200 | false | int
| EnableScaling | Autoscaling | false | false | boolean




## Configuration

### Task Definition

```yaml
task_definition:
  web:
    image: nginx
    ports:
      - 80
```

### Target Groups

```yaml
targetgroup:
  name: web
  type: ip
  container: nginx
  port: 80
  protocol: http
  listener: http
  rules:
    -
      host: www.*
      priority: 10
```

## Outputs/Exports

| Name | Value | Exported |
| ---- | ----- | -------- |
| SecurityGroup | Ecs Service SecurityGroup | true
| TaskTargetGroup | Task Targetgroup | true
| ServiceName | Ecs Service Name | true

## Included Components

[ecs-task](https://github.com/theonestack/hl-component-ecs-task)

## Development

```bash
gem install cfhighlander
```

or via docker

```bash
docker pull theonestack/cfhighlander
```

compiling the templates

```bash
cfcompile fargate-v2
```

compiling with the vaildate fag to validate the templates

```bash
cfcompile fargate-v2 --validate
```

### Testing

```bash
gem install rspec
```

```bash
rspec

.........
CloudFormation YAML template for ecs-task written to /Users/aaronwalker/Workspaces/theonestack/hl-component-fargate-v2/out/yaml/fargatev2Task.compiled.yaml
CloudFormation YAML template for fargate-v2 written to /Users/aaronwalker/Workspaces/theonestack/hl-component-fargate-v2/out/tests/targetgroup_param/fargate-v2.compiled.yaml
Validate template /Users/aaronwalker/Workspaces/theonestack/hl-component-fargate-v2/out/tests/targetgroup_param/fargate-v2.compiled.yaml locally
SUCCESS
Validate template /Users/aaronwalker/Workspaces/theonestack/hl-component-fargate-v2/out/yaml/fargatev2Task.compiled.yaml locally
SUCCESS

  ============================
  #    CfHighlander Tests    #
  ============================

  Pass: 1
  Fail: 0
  Time: 3.289156

...

Finished in 32.62 seconds (files took 0.31077 seconds to load)
40 examples, 0 failures
```



