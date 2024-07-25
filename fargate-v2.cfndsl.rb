CloudFormation do

  export = external_parameters.fetch(:export_name, external_parameters[:component_name])

  task_definition = external_parameters.fetch(:task_definition, nil)
  if task_definition.nil?
    raise 'you must define a task_definition'
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

  Condition(:EnableCognito, FnNot(FnEquals(Ref(:FargateUserPoolClientId), '')))

  service_loadbalancer = []
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

        tags = []
        tags << { Key: "Environment", Value: Ref("EnvironmentName") }
        tags << { Key: "EnvironmentType", Value: Ref("EnvironmentType") }

        targetgroup['tags'].each do |key,value|
          tags << { Key: key, Value: value }
        end if targetgroup.has_key?('tags')

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

          Tags tags if tags.any?
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

          actions = [{ Type: "forward", Order: 5000, TargetGroupArn: Ref(targetgroup['resource_name'])}]
          actions_with_cognito = actions + [cognito(Ref(:FargateUserPoolId), Ref(:FargateUserPoolClientId), Ref(:FargateUserPoolDomainName))]
          
          ElasticLoadBalancingV2_ListenerRule(rule_name) do
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
  
  targetgroups = external_parameters.fetch(:targetgroups, [])
  unless targetgroups.empty?
    
  end

  health_check_grace_period = external_parameters.fetch(:health_check_grace_period, nil)
  platform_version = external_parameters.fetch(:platform_version, nil)
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
      Cluster Ref("EcsCluster")
      PlatformVersion platform_version unless platform_version.nil?
      DesiredCount Ref('DesiredCount')
      DeploymentConfiguration deployment_configuration
      EnableExecuteCommand external_parameters.fetch(:enable_execute_command, false)
      TaskDefinition "Ref" => "Task" #Hack to work referencing child component resource
      HealthCheckGracePeriodSeconds health_check_grace_period unless health_check_grace_period.nil?
      LaunchType "FARGATE"

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


  
end