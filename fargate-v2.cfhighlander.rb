CfhighlanderTemplate do

  DependsOn 'lib-iam@0.1.0'
  DependsOn 'lib-ec2@0.1.0'
  
  Parameters do
    ComponentParam 'EnvironmentName', 'dev', isGlobal: true
    ComponentParam 'EnvironmentType', 'development', isGlobal: true
    
    ComponentParam 'VPCId', type: 'AWS::EC2::VPC::Id'
    ComponentParam 'SubnetIds', type: 'CommaDelimitedList'

    ComponentParam 'EcsCluster'

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
    ComponentParam 'EnableScaling', 'false', allowedValues: ['true','false']
  end

  #Pass the all the config from the parent component to the inlined component
  Component template: 'ecs-task@0.5.3', name: "#{component_name.gsub('-','').gsub('_','')}Task", render: Inline, config: @config do
    parameter name: 'DnsDomain', value: Ref('DnsDomain')
  end

end