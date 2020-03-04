CloudFormation do

  export = external_parameters.fetch(:export_name, external_parameters[:component_name])

  task_definition = external_parameters.fetch(:task_definition, nil)
  if task_definition.nil?
    raise 'you must define a task_definition'
  end

  EC2_SecurityGroup(:SecurityGroup) do
    VpcId Ref('VPCId')
    GroupDescription "#{external_parameters[:component_name]} fargate service"
  end
  Output(:SecurityGroup) {
    Value(Ref(:SecurityGroup))
    Export FnSub("${EnvironmentName}-#{export}-SecurityGroup")
  }

  health_check_grace_period = external_parameters.fetch(:health_check_grace_period, nil)
  service_loadbalancer = []
  unless task_definition.empty?

    ECS_Service('Service') do
      Cluster Ref("EcsCluster")
      DesiredCount Ref('DesiredCount')
      DeploymentConfiguration ({
          MinimumHealthyPercent: Ref('MinimumHealthyPercent'),
          MaximumPercent: Ref('MaximumPercent')
      })
      TaskDefinition FnSub("${Task}")
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
      Value(FnGetAtt('Service', 'Name'))
      Export FnSub("${EnvironmentName}-#{export}-ServiceName")
    end
  end


  
end