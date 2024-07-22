CfhighlanderTemplate do

  DependsOn 'lib-iam@0.2.0'
  DependsOn 'lib-ec2@0.1.0'
  DependsOn 'lib-alb'
  
  Parameters do
    ComponentParam 'EnvironmentName', 'dev', isGlobal: true
    ComponentParam 'EnvironmentType', 'development', isGlobal: true
    
    ComponentParam 'VPCId', type: 'AWS::EC2::VPC::Id'
    ComponentParam 'SubnetIds', type: 'CommaDelimitedList'

    ComponentParam 'EcsCluster'
    ComponentParam 'UserPoolId', ''
    ComponentParam 'UserPoolClientId', ''
    ComponentParam 'UserPoolDomainName', ''

    if defined? targetgroup
      ComponentParam 'DnsDomain', isGlobal: true
      if targetgroup.is_a?(Array)
        targetgroup.each do |tg|
          if tg.has_key?('rules')
            ComponentParam "#{tg['listener']}Listener"
          else
            ComponentParam "#{tg['name'].gsub(/[^0-9A-Za-z]/, '')}TargetGroup"
          end
        end
      else
        ComponentParam 'TargetGroup' unless targetgroup.has_key?('rules')
        ComponentParam 'Listener'
        ComponentParam 'LoadBalancer'
      end
    end

    ComponentParam 'DesiredCount', 1
    ComponentParam 'MinimumHealthyPercent', 100
    ComponentParam 'MaximumPercent', 200
    ComponentParam 'ExportName', ''

    if defined? service_discovery
      ComponentParam 'NamespaceId'
    end
  end

  #Pass the all the config from the parent component to the inlined component
  Component template: 'git:https://github.com/theonestack/hl-component-ecs-task#feature/ebs-support.snapshot', name: "#{component_name.gsub('-','').gsub('_','')}Task", render: Inline, config: @config do
    parameter name: 'DnsDomain', value: Ref('DnsDomain')
    parameter name: 'EbsAZ', value: Ref('EbsAZ')
  end

  unless service_namespace.nil?
    Component template: 'application-autoscaling@0.1.7', name: "#{component_name.gsub('-','').gsub('_','')}Scaling", render: Inline, conditional: true, enabled: false, config: @config do
      parameter name: 'Service', value: Ref('EcsFargateService')
    end
  end

end
