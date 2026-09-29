CloudFormation do

  export = external_parameters.fetch(:export_name, external_parameters[:component_name])

  fargate_tags = []
  fargate_tags << { Key: "Environment", Value: Ref("EnvironmentName") }
  fargate_tags << { Key: "EnvironmentType", Value: Ref("EnvironmentType") }

  tags = external_parameters.fetch(:tags, {})
  tags.each do |key, value|
    fargate_tags << { Key: FnSub(key), Value: FnSub(value)}
  end

  task_definition = external_parameters.fetch(:task_definition, nil)
  if task_definition.nil?
    raise 'you must define a task_definition'
  end

  service_namespace = external_parameters.fetch(:service_namespace, nil)

  # Mirrors the name/condition cfhighlander used to derive for the (now removed) conditional
  # application-autoscaling sub-component: name = "#{component_name}Scaling", cfn_name = name with
  # '-'/'_'/' ' stripped, condition = "Enable#{cfn_name}". EnableScaling defaults to false, so the
  # ScalableTarget and friends below may not exist even when service_namespace is 'ecs'.
  if service_namespace == 'ecs'
    scaling_cfn_name = "#{external_parameters[:component_name]}Scaling".gsub('-', '').gsub('_', '').gsub(' ', '')
    scaling_condition = "Enable#{scaling_cfn_name}"
    Condition(scaling_condition.to_sym, FnEquals(Ref(scaling_condition), 'true'))
  end

  EC2_SecurityGroup(:SecurityGroup) do
    VpcId Ref('VPCId')
    GroupDescription "#{external_parameters[:component_name]} fargate service"
    Metadata({
      cfn_nag: {
        rules_to_suppress: [
          { id: 'F1000', reason: 'ignore egress for now' }
        ]
      }
    })
  end
  Output(:SecurityGroup) {
    Value(Ref(:SecurityGroup))
    Export FnSub("${EnvironmentName}-#{export}-SecurityGroup")
  }

  ingress_rules = external_parameters.fetch(:ingress_rules, [])
  ingress_rules.each_with_index do |ingress_rule, i|
    EC2_SecurityGroupIngress("IngressRule#{i+1}") do
      Description ingress_rule['desc'] if ingress_rule.has_key?('desc')
      if ingress_rule.has_key?('cidr')
        CidrIp ingress_rule['cidr']
      else
        SourceSecurityGroupId ingress_rule.has_key?('source_sg') ? ingress_rule['source_sg'] :  Ref(:SecurityGroup)
      end
      GroupId ingress_rule.has_key?('dest_sg') ? ingress_rule['dest_sg'] : Ref(:SecurityGroup)
      IpProtocol ingress_rule.has_key?('protocol') ? ingress_rule['protocol'] : 'tcp'
      FromPort ingress_rule['from']
      ToPort ingress_rule.has_key?('to') ? ingress_rule['to'] : ingress_rule['from']
    end
  end

  Condition(:EnableCognito, FnNot(FnEquals(Ref(:UserPoolClientId), '')))

  service_loadbalancer = []
  listener_rule_names = []
  # rule_name => condition, for rules that are only created when their condition is true
  conditional_listener_rules = {}
  targetgroups = external_parameters.fetch(:targetgroup, {})
  multiplie_target_groups =  targetgroups.is_a?(Array)
  unless targetgroups.empty?

    if multiplie_target_groups
      # Generate resource names based upon the target group name and the listener and suffix with resource type
      targetgroups.each do |tg| 
        tg['resource_name'] = "#{tg['name'].gsub(/[^0-9A-Za-z]/, '')}TargetGroup"
        tg['listener_resource'] = "#{tg['listener']}Listener"
      end
    else
      # Keep original resource names for backwards compatibility
      targetgroups['resource_name'] = targetgroup.has_key?('rules') ? 'TaskTargetGroup' : 'TargetGroup'
      targetgroups['listener_resource'] = 'Listener'
      targetgroups = [targetgroups]
    end

    targetgroups.each do |targetgroup|
      if targetgroup.has_key?('rules')
        attributes = []

        targetgroup['attributes'].each do |key,value|
          attributes << { Key: key, Value: value }
        end if targetgroup.has_key?('attributes')

        tg_tags = Marshal.load(Marshal.dump(fargate_tags))
        targetgroup['tags'].each do |key,value|
          tg_tags << { Key: key, Value: value }
        end unless targetgroup['tags'].nil?

        ElasticLoadBalancingV2_TargetGroup(targetgroup['resource_name']) do
          ## Required
          Port targetgroup['port']
          Protocol targetgroup['protocol'].upcase
          VpcId Ref('VPCId')
          ## Optional
          if targetgroup.has_key?('healthcheck')
            HealthCheckPort targetgroup['healthcheck']['port'] if targetgroup['healthcheck'].has_key?('port')
            HealthCheckProtocol targetgroup['healthcheck']['protocol'] if targetgroup['healthcheck'].has_key?('protocol')
            HealthCheckIntervalSeconds targetgroup['healthcheck']['interval'] if targetgroup['healthcheck'].has_key?('interval')
            HealthCheckTimeoutSeconds targetgroup['healthcheck']['timeout'] if targetgroup['healthcheck'].has_key?('timeout')
            HealthyThresholdCount targetgroup['healthcheck']['healthy_count'] if targetgroup['healthcheck'].has_key?('healthy_count')
            UnhealthyThresholdCount targetgroup['healthcheck']['unhealthy_count'] if targetgroup['healthcheck'].has_key?('unhealthy_count')
            HealthCheckPath targetgroup['healthcheck']['path'] if targetgroup['healthcheck'].has_key?('path')
            Matcher ({ HttpCode: targetgroup['healthcheck']['code'] }) if targetgroup['healthcheck'].has_key?('code')
          end

          TargetType targetgroup['type'] if targetgroup.has_key?('type')
          TargetGroupAttributes attributes if attributes.any?

          Tags tg_tags
        end

        targetgroup['rules'].each_with_index do |rule, index|
          listener_conditions = []
          if rule.key?("path")
            listener_conditions << { Field: "path-pattern", Values: [ rule["path"] ].flatten() }
          end
          if rule.key?("host")
            hosts = []
            if rule["host"].include?('!DNSDomain')
              host_subdomain = rule["host"].gsub('!DNSDomain', '') #remove <DNSDomain>
              hosts << FnJoin("", [ host_subdomain , Ref('DnsDomain') ])
            elsif rule["host"].include?('.')
              hosts << rule["host"]
            else
              hosts << FnJoin("", [ rule["host"], ".", Ref('DnsDomain') ])
            end
            listener_conditions << { Field: "host-header", Values: hosts }
          end
          listener_conditions = rule["custom_conditions"] if rule.has_key?("custom_conditions")

          if rule.key?("name")
            rule_name = rule['name']
          elsif rule['priority'].is_a? Integer
            if multiplie_target_groups
              rule_name = "#{targetgroup['name']}TargetRule#{rule['priority']}"
            else 
              rule_name = "TargetRule#{rule['priority']}"
            end
          else
            if multiplie_target_groups
              rule_name = "#{targetgroup['name']}TargetRule#{index}"
            else
              rule_name = "TargetRule#{index}"
            end
          end

          rule_condition = rule['condition']
          if rule_condition.nil?
            listener_rule_names << rule_name
          else
            conditional_listener_rules[rule_name] = rule_condition
          end

          actions = [{ Type: "forward", Order: 5000, TargetGroupArn: Ref(targetgroup['resource_name'])}]
          actions = rule["custom_actions"] if rule.has_key?("custom_actions")
          actions_with_cognito = actions + [cognito(Ref(:UserPoolId), Ref(:UserPoolClientId), Ref(:UserPoolDomainName))]
          
          ElasticLoadBalancingV2_ListenerRule(rule_name) do
            Condition rule_condition unless rule_condition.nil?
            Actions FnIf(:EnableCognito, actions_with_cognito, actions)
            Conditions listener_conditions
            ListenerArn Ref(targetgroup['listener_resource'])
            Priority rule['priority']
          end

        end

        targetgroup_arn =  Ref(targetgroup['resource_name'])
      else
        if multiplie_target_groups
          targetgroup_arn = Ref(targetgroup['resource_name'])
        else
          targetgroup_arn = Ref('TargetGroup')
        end
      end

      Output("#{targetgroup['resource_name']}") {
        Value(targetgroup_arn)
        Export FnSub("${EnvironmentName}-#{export}-#{targetgroup['resource_name']}")
      }

      service_loadbalancer << {
        ContainerName: targetgroup['container'],
        ContainerPort: targetgroup['port'],
        TargetGroupArn: targetgroup_arn
      }
    end

  end

  unless conditional_listener_rules.empty?
    conditional_listener_rules.values.uniq.each do |condition|
      Condition(condition.to_sym, FnEquals(Ref(condition), 'true'))
    end

    # DependsOn can't target a resource that may not exist, so the service depends on this
    # always-created handle instead, which references each conditional rule only when it's created.
    CloudFormation_WaitConditionHandle(:ConditionalListenerRules) do
      Metadata(conditional_listener_rules.map { |rule_name, condition|
        [rule_name, FnIf(condition, Ref(rule_name), '')]
      }.to_h)
    end
    listener_rule_names << 'ConditionalListenerRules'
  end

  targetgroups = external_parameters.fetch(:targetgroups, [])
  unless targetgroups.empty?
    
  end

  health_check_grace_period = external_parameters.fetch(:health_check_grace_period, nil)
  platform_version = external_parameters.fetch(:platform_version, nil)
  availability_zone_rebalancing = external_parameters.fetch(:availability_zone_rebalancing, nil)
  deployment_circuit_breaker = external_parameters.fetch(:deployment_circuit_breaker, {}).transform_keys {|k| k.split('_').collect(&:capitalize).join }
  deployment_configuration = {
    MinimumHealthyPercent: Ref('MinimumHealthyPercent'),
    MaximumPercent: Ref('MaximumPercent')
  }
  unless deployment_circuit_breaker.empty?
    deployment_configuration['DeploymentCircuitBreaker'] = deployment_circuit_breaker 
  end

  registry = {}
  service_discovery = external_parameters.fetch(:service_discovery, {})

  unless service_discovery.empty?

    ServiceDiscovery_Service(:ServiceRegistry) {
      NamespaceId Ref(:NamespaceId)
      Name service_discovery['name']  if service_discovery.has_key? 'name'
      DnsConfig({
        DnsRecords: [{
          TTL: 60,
          Type: 'A'
        }],
        RoutingPolicy: 'WEIGHTED'
      })
      if service_discovery.has_key? 'healthcheck'
        HealthCheckConfig service_discovery['healthcheck']
      else
        HealthCheckCustomConfig ({ FailureThreshold: (service_discovery['failure_threshold'] || 1) })
      end
    }

    registry[:RegistryArn] = FnGetAtt(:ServiceRegistry, :Arn)
    registry[:ContainerName] = service_discovery['container_name']
    registry[:ContainerPort] = service_discovery['container_port'] if service_discovery.has_key? 'container_port'
    registry[:Port] = service_discovery['port'] if service_discovery.has_key? 'port'
  end

  unless task_definition.empty?

    ECS_Service('EcsFargateService') do
      DependsOn(listener_rule_names) unless listener_rule_names.empty?
      Cluster Ref("EcsCluster")
      PlatformVersion platform_version unless platform_version.nil?
      # Omit DesiredCount only while the ScalableTarget is actually enabled (EnableScaling condition
      # true) - otherwise CloudFormation resets the live Auto Scaling-managed count on every deploy.
      # When scaling isn't compiled in, or is compiled in but disabled, DesiredCount is retained as normal.
      desired_count = Ref('DesiredCount')
      desired_count = FnIf(scaling_condition, Ref('AWS::NoValue'), desired_count) if service_namespace == 'ecs'
      DesiredCount desired_count
      DeploymentConfiguration deployment_configuration
      EnableExecuteCommand external_parameters.fetch(:enable_execute_command, false)
      TaskDefinition "Ref" => "Task" #Hack to work referencing child component resource
      HealthCheckGracePeriodSeconds health_check_grace_period unless health_check_grace_period.nil?
      AvailabilityZoneRebalancing availability_zone_rebalancing unless availability_zone_rebalancing.nil?
      LaunchType "FARGATE"
      Tags fargate_tags
      PropagateTags 'SERVICE'

      if service_loadbalancer.any?
        LoadBalancers service_loadbalancer
      end

      NetworkConfiguration ({
        AwsvpcConfiguration: {
          AssignPublicIp: external_parameters[:public_ip] ? "ENABLED" : "DISABLED",
          SecurityGroups: [ Ref(:SecurityGroup) ],
          Subnets: Ref('SubnetIds')
        }
      })

      unless registry.empty?
        ServiceRegistries([registry])
      end

    end

    Output('ServiceName') do
      Value(FnGetAtt('EcsFargateService', 'Name'))
      Export FnSub("${EnvironmentName}-#{export}-ServiceName")
    end
  end

  # Application Auto Scaling for the ECS service. Inlined from the former application-autoscaling /
  # ecs-scaling components so this component no longer depends on them externally. Every resource here
  # carries the same scaling_condition, matching how cfhighlander conditionally-inlined those components.
  if service_namespace == 'ecs'
    scaling_policy = external_parameters.fetch(:scaling_policy, {})

    IAM_Role(:ServiceECSAutoScaleRole) do
      AssumeRolePolicyDocument service_assume_role_policy('application-autoscaling')
      Path '/'
      Policies ([
        PolicyName: 'ecs-scaling',
        PolicyDocument: {
          Statement: [
            {
              Effect: "Allow",
              Action: ['cloudwatch:DescribeAlarms','cloudwatch:PutMetricAlarm','cloudwatch:DeleteAlarms'],
              Resource: "*"
            },
            {
              Effect: "Allow",
              Action: ['ecs:UpdateService','ecs:DescribeServices'],
              Resource: Ref(:EcsFargateService)
            }
          ]
      }])
      Condition scaling_condition
    end

    ecs_cluster = FnSelect(1, FnSplit('/', Ref(:EcsFargateService)))
    service_name = FnSelect(2, FnSplit('/', Ref(:EcsFargateService)))
    scheduled_actions = []

    scaling_policy['scheduled_actions'].each do | a |
      action = {
        'ScalableTargetAction' => {
          'MaxCapacity' => a['max_capacity'],
          'MinCapacity' => a['min_capacity']
        },
        'Schedule' => a['schedule'],
        'ScheduledActionName' => FnJoin( '-', [ "service", ecs_cluster, service_name, "scheduled-action-#{scheduled_actions.length + 1}" ] )
      }
      action[:Timezone] = scaling_policy['timezone'] if scaling_policy.key? 'timezone'
      scheduled_actions << action
    end if scaling_policy.key? 'scheduled_actions'

    ApplicationAutoScaling_ScalableTarget(:ServiceScalingTarget) do
      MaxCapacity Ref("#{scaling_cfn_name}Max")
      MinCapacity Ref("#{scaling_cfn_name}Min")
      ResourceId FnJoin( '', [ "service/", ecs_cluster, "/",  service_name ] )
      RoleARN FnGetAtt(:ServiceECSAutoScaleRole,:Arn)
      ScalableDimension "ecs:service:DesiredCount"
      ServiceNamespace "ecs"
      ScheduledActions scheduled_actions if scheduled_actions.length > 0
      Condition scaling_condition
    end

    default_alarm = {}
    default_alarm['metric_name'] = 'CPUUtilization'
    default_alarm['namespace'] = 'AWS/ECS'
    default_alarm['statistic'] = 'Average'
    default_alarm['period'] = '60'
    default_alarm['evaluation_periods'] = '5'
    default_alarm['dimentions'] = [
      { Name: 'ServiceName', Value: service_name},
      { Name: 'ClusterName', Value: ecs_cluster}
    ]

    if scaling_policy['up'].kind_of?(Hash)
      scaling_policy['up'] = [scaling_policy['up']]
    end

    if scaling_policy['down'].kind_of?(Hash)
      scaling_policy['down'] = [scaling_policy['down']]
    end

    if scaling_policy['target'].kind_of?(Hash)
      scaling_policy['target'] = [scaling_policy['target']]
    end

    scaling_policy['up'].each_with_index do |scale_up_policy, i|
      logical_scaling_policy_name = "ServiceScalingUpPolicy"  + (i > 0 ? "#{i+1}" : "")
      logical_alarm_name          = "ServiceScaleUpAlarm"     + (i > 0 ? "#{i+1}" : "")
      policy_name                 = "scale-up-policy"         + (i > 0 ? "-#{i+1}" : "")

      ApplicationAutoScaling_ScalingPolicy(logical_scaling_policy_name) do
        PolicyName FnJoin('-', [ Ref('EnvironmentName'), 'autoscaling', policy_name])
        PolicyType "StepScaling"
        ScalingTargetId Ref(:ServiceScalingTarget)
        StepScalingPolicyConfiguration({
          AdjustmentType: "ChangeInCapacity",
          Cooldown: scale_up_policy['cooldown'] || 300,
          MetricAggregationType: "Average",
          StepAdjustments: [{ ScalingAdjustment: scale_up_policy['adjustment'].to_s, MetricIntervalLowerBound: 0 }]
        })
        Condition scaling_condition
      end

      CloudWatch_Alarm(logical_alarm_name) do
        AlarmDescription FnJoin(' ', [Ref('EnvironmentName'), "autoscaling ecs scale up alarm"])
        MetricName scale_up_policy['metric_name'] || default_alarm['metric_name']
        Namespace scale_up_policy['namespace'] || default_alarm['namespace']
        Statistic scale_up_policy['statistic'] || default_alarm['statistic']
        Period (scale_up_policy['period'] || default_alarm['period']).to_s
        EvaluationPeriods scale_up_policy['evaluation_periods'].to_s
        Threshold scale_up_policy['threshold'].to_s
        AlarmActions [Ref(logical_scaling_policy_name)]
        ComparisonOperator 'GreaterThanThreshold'
        Dimensions scale_up_policy['dimentions'] || default_alarm['dimentions']
        Condition scaling_condition
      end
    end unless scaling_policy['up'].nil?

    scaling_policy['down'].each_with_index do |scale_down_policy, i|
      logical_scaling_policy_name = "ServiceScalingDownPolicy"  + (i > 0 ? "#{i+1}" : "")
      logical_alarm_name          = "ServiceScaleDownAlarm"     + (i > 0 ? "#{i+1}" : "")
      policy_name                 = "scale-down-policy"         + (i > 0 ? "-#{i+1}" : "")

      ApplicationAutoScaling_ScalingPolicy(logical_scaling_policy_name) do
        PolicyName FnJoin('-', [ Ref('EnvironmentName'), 'autoscaling', policy_name])
        PolicyType 'StepScaling'
        ScalingTargetId Ref(:ServiceScalingTarget)
        StepScalingPolicyConfiguration({
          AdjustmentType: "ChangeInCapacity",
          Cooldown: scale_down_policy['cooldown'] || 900,
          MetricAggregationType: "Average",
          StepAdjustments: [{ ScalingAdjustment: scale_down_policy['adjustment'].to_s, MetricIntervalUpperBound: 0 }]
        })
        Condition scaling_condition
      end

      CloudWatch_Alarm(logical_alarm_name) do
        AlarmDescription FnJoin(' ', [Ref('EnvironmentName'), "autoscaling ecs scale down alarm"])
        MetricName scale_down_policy['metric_name'] || default_alarm['metric_name']
        Namespace scale_down_policy['namespace'] || default_alarm['namespace']
        Statistic scale_down_policy['statistic'] || default_alarm['statistic']
        Period (scale_down_policy['period'] || default_alarm['period']).to_s
        EvaluationPeriods scale_down_policy['evaluation_periods'].to_s
        Threshold scale_down_policy['threshold'].to_s
        AlarmActions [Ref(logical_scaling_policy_name)]
        ComparisonOperator 'LessThanThreshold'
        Dimensions scale_down_policy['dimentions'] || default_alarm['dimentions']
        Condition scaling_condition
      end
    end unless scaling_policy['down'].nil?

    scaling_policy['target'].each_with_index do |scale_target_policy, i|
      logical_scaling_policy_name = "ServiceTargetTrackingPolicy"  + (i > 0 ? "#{i+1}" : "")
      policy_name                 = "target-tracking-policy"       + (i > 0 ? "-#{i+1}" : "")

      ApplicationAutoScaling_ScalingPolicy(logical_scaling_policy_name) do
        PolicyName FnJoin('-', [ Ref('EnvironmentName'), 'autoscaling', policy_name])
        PolicyType 'TargetTrackingScaling'
        ScalingTargetId Ref(:ServiceScalingTarget)
        TargetTrackingScalingPolicyConfiguration do
          TargetValue scale_target_policy['target_value']
          ScaleInCooldown scale_target_policy['scale_in_cooldown'].to_s
          ScaleOutCooldown scale_target_policy['scale_out_cooldown'].to_s
          PredefinedMetricSpecification do
            PredefinedMetricType scale_target_policy['metric_type'] || 'ECSServiceAverageCPUUtilization'
          end unless scale_target_policy['metric_type'].nil?
          CustomizedMetricSpecification do
            Namespace scale_target_policy['custom']['namespace']
            MetricName scale_target_policy['custom']['metric_name']
            Statistic scale_target_policy['custom']['statistic']
            Unit scale_target_policy['custom']['unit'] unless scale_target_policy['custom']['unit'].nil?
            Dimensions scale_target_policy['custom']['dimensions'] unless scale_target_policy['custom']['dimensions'].nil?
          end unless scale_target_policy['custom'].nil?
        end
        Condition scaling_condition
      end
    end unless scaling_policy['target'].nil?
  end

end