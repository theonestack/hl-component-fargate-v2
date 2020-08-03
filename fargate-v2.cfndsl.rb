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
      GroupId ingress_rule.has_key?('dest_sg') ? ingress_rule['dest_sg'] : Ref(:SecurityGroup)
      SourceSecurityGroupId ingress_rule.has_key?('source_sg') ? ingress_rule['source_sg'] :  Ref(:SecurityGroup)
      IpProtocol ingress_rule.has_key?('protocol') ? ingress_rule['protocol'] : 'tcp'
      FromPort ingress_rule['from']
      ToPort ingress_rule.has_key?('to') ? ingress_rule['to'] : ingress_rule['from']
    end
  end

  service_loadbalancer = []
  targetgroup = external_parameters.fetch(:targetgroup, {})
  unless targetgroup.empty?

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

      ElasticLoadBalancingV2_TargetGroup('TaskTargetGroup') do
        ## Required
        Port targetgroup['port']
        Protocol targetgroup['protocol'].upcase
        VpcId Ref('VPCId')
        ## Optional
        if targetgroup.has_key?('healthcheck')
          HealthCheckPort targetgroup['healthcheck']['port'] if targetgroup['healthcheck'].has_key?('port')
          HealthCheckProtocol targetgroup['healthcheck']['protocol'] if targetgroup['healthcheck'].has_key?('port')
          HealthCheckIntervalSeconds targetgroup['healthcheck']['interval'] if targetgroup['healthcheck'].has_key?('interval')
          HealthCheckTimeoutSeconds targetgroup['healthcheck']['timeout'] if targetgroup['healthcheck'].has_key?('timeout')
          HealthyThresholdCount targetgroup['healthcheck']['heathy_count'] if targetgroup['healthcheck'].has_key?('heathy_count')
          UnhealthyThresholdCount targetgroup['healthcheck']['unheathy_count'] if targetgroup['healthcheck'].has_key?('unheathy_count')
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
          rule_name = "TargetRule#{rule['priority']}"
        else
          rule_name = "TargetRule#{index}"
        end

        ElasticLoadBalancingV2_ListenerRule(rule_name) do
          Actions [{ Type: "forward", TargetGroupArn: Ref('TaskTargetGroup') }]
          Conditions listener_conditions
          ListenerArn Ref("Listener")
          Priority rule['priority']
        end

      end

      targetgroup_arn = Ref('TaskTargetGroup')

      Output("TaskTargetGroup") {
        Value(Ref('TaskTargetGroup'))
        Export FnSub("${EnvironmentName}-#{export}-targetgroup")
      }
    else
      targetgroup_arn = Ref('TargetGroup')
    end


    service_loadbalancer << {
      ContainerName: targetgroup['container'],
      ContainerPort: targetgroup['port'],
      TargetGroupArn: targetgroup_arn
    }

  end

  health_check_grace_period = external_parameters.fetch(:health_check_grace_period, nil)
  unless task_definition.empty?

    ECS_Service('EcsFargateService') do
      Cluster Ref("EcsCluster")
      DesiredCount Ref('DesiredCount')
      DeploymentConfiguration ({
          MinimumHealthyPercent: Ref('MinimumHealthyPercent'),
          MaximumPercent: Ref('MaximumPercent')
      })
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

    end

    Output('ServiceName') do
      Value(FnGetAtt('EcsFargateService', 'Name'))
      Export FnSub("${EnvironmentName}-#{export}-ServiceName")
    end
  end


  
end