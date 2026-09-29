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

      # A rule with `condition: <Name>` is only created when the <Name> parameter is 'true'.
      # Rules may share a condition, so each parameter is only declared once.
      [targetgroup].flatten.flat_map { |tg| tg.fetch('rules', []) }
        .map { |rule| rule['condition'] }.compact.uniq.each do |condition|
        ComponentParam condition, 'true', allowedValues: %w(true false)
      end
    end

    ComponentParam 'DesiredCount', 1
    ComponentParam 'MinimumHealthyPercent', 100
    ComponentParam 'MaximumPercent', 200
    ComponentParam 'ExportName', ''

    # Mirrors the parameters/condition cfhighlander used to derive for the (now removed) conditional
    # application-autoscaling@0.1.7 sub-component: name = "#{component_name}Scaling", cfn_name = name
    # with '-'/'_'/' ' stripped, condition = "Enable#{cfn_name}". Only service_namespace: ecs is supported.
    if service_namespace == 'ecs'
      scaling_cfn_name = "#{component_name}Scaling".gsub('-', '').gsub('_', '').gsub(' ', '')
      ComponentParam "Enable#{scaling_cfn_name}", 'false', allowedValues: %w(true false)
      ComponentParam "#{scaling_cfn_name}Min", 1
      ComponentParam "#{scaling_cfn_name}Max", 10
    end

    if defined? service_discovery
      ComponentParam 'NamespaceId'
    end

  end

  #Pass the all the config from the parent component to the inlined component
  Component template: 'ecs-task@0.5.14', name: "#{component_name.gsub('-','').gsub('_','')}Task", render: Inline, config: @config do
    parameter name: 'DnsDomain', value: Ref('DnsDomain')

    additional_parameters.each do |parameter_name|
      parameter name: parameter_name, value: Ref(parameter_name)
    end if defined? additional_parameters

  end

end
