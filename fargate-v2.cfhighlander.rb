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
      ComponentParam 'LoadBalancer'
      ComponentParam 'TargetGroup' unless targetgroup.has_key?('rules')
      ComponentParam 'Listener'
      ComponentParam 'DnsDomain', isGlobal: true
    end

    ComponentParam 'DesiredCount', 1
    ComponentParam 'MinimumHealthyPercent', 100
    ComponentParam 'MaximumPercent', 200
    ComponentParam 'EnableScaling', 'false', allowedValues: ['true','false']
  end

  #Pass the all the config from the parent component to the inlined component
  Component template: 'ecs-task@secrets', name: "#{component_name.gsub('-','').gsub('_','')}", render: Inline, config: @config

end