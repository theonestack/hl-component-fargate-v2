require 'yaml'

describe 'compiled component' do
  
  context 'cftest' do
    it 'compiles test' do
      expect(system("cfhighlander cftest #{@validate} --tests tests/ecs_exec.test.yaml")).to be_truthy
    end      
  end
  
  let(:template) { YAML.load_file("#{File.dirname(__FILE__)}/../out/tests/ecs_exec/fargate-v2.compiled.yaml") }

  context 'Resource LogGroup' do

    let(:properties) { template["Resources"]["LogGroup"]["Properties"] }

    it 'has property RetentionInDays' do
      expect(properties["RetentionInDays"]).to eq('7')
    end

    it 'has property LogGroupName' do
      expect(properties["LogGroupName"]).to eq({"Ref"=>"AWS::StackName"})
    end

  end

  context 'Resource Task' do

    let(:properties) { template["Resources"]["Task"]["Properties"] }
    let(:containerDefinition) { template["Resources"]["Task"]["Properties"]['ContainerDefinitions'][0] }

    it 'has property RequiresCompatibilities' do
      expect(properties["RequiresCompatibilities"]).to eq(['FARGATE'])
    end

    it 'has property CPU' do
      expect(properties["Cpu"]).to eq(256)
    end

    it 'has property Memory' do
      expect(properties["Memory"]).to eq(512)
    end

    it 'has property NetworkMode' do
      expect(properties["NetworkMode"]).to eq("awsvpc")
    end

    it 'has property Tags' do
      expect(properties["Tags"]).to eq([
        {"Key"=>"Name", "Value"=>"fargatev2Task"}, 
        {"Key"=>"Environment", "Value"=>{"Ref"=>"EnvironmentName"}}, 
        {"Key"=>"EnvironmentType", "Value"=>{"Ref"=>"EnvironmentType"}}])
    end

    it 'has ContainerDefinition Name' do
      expect(containerDefinition["Name"]).to eq("proxy")
    end

    it 'has ContainerDefinition Image' do
      expect(containerDefinition["Image"]).to eq({"Fn::Join"=>["", ["", "nginx", ":", "latest"]]})
    end

    it 'has ContainerDefinition LogConfiguration' do
      expect(containerDefinition["LogConfiguration"]["LogDriver"]).to eq("awslogs")
      expect(containerDefinition["LogConfiguration"]["Options"]).to eq({
        "awslogs-group" => {"Ref"=>"LogGroup"},
        "awslogs-region" => {"Ref"=>"AWS::Region"},
        "awslogs-stream-prefix" => "proxy"
      })

    end

  end

  context 'Resource Security Group' do

    let(:properties) { template["Resources"]["SecurityGroup"]["Properties"] }

    it 'has property VpcId' do
      expect(properties["VpcId"]).to eq({"Ref"=>"VPCId"})
    end

    it 'has property GroupDescription' do
      expect(properties["GroupDescription"]).to eq("fargate-v2 fargate service")
    end

  end

  context 'Resource ExecutionRole' do

    let(:properties) { template["Resources"]["ExecutionRole"]['Properties'] }

    it 'has ManagedPolicyArns' do
      expect(properties["ManagedPolicyArns"]).to eq(["arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"])
    end

    it 'has AssumeRolePolicyDocument' do
      expect(properties["AssumeRolePolicyDocument"]).to eq({
        "Statement"=>[
          {
            "Action"=>"sts:AssumeRole", 
            "Effect"=>"Allow", 
            "Principal"=>{"Service"=>"ecs-tasks.amazonaws.com"}
          },
          {
            "Action"=>"sts:AssumeRole", 
            "Effect"=>"Allow", 
            "Principal"=>{"Service"=>"ssm.amazonaws.com"}
          }
        ], 
        "Version"=>"2012-10-17"
      })
    end

  end

  context 'Resource TaskRole' do

    let(:properties) { template["Resources"]["TaskRole"]['Properties'] }

    it 'has AssumeRolePolicyDocument' do
      expect(properties["AssumeRolePolicyDocument"]).to eq({
        "Version" => "2012-10-17",
        "Statement" => [
          {
            "Action"=>"sts:AssumeRole",
            "Effect"=>"Allow",
            "Principal"=>{"Service"=>"ecs-tasks.amazonaws.com"}
          },
          {
            "Action"=>"sts:AssumeRole",
            "Effect"=>"Allow",
            "Principal"=>{"Service"=>"ssm.amazonaws.com"}
          }
        ],
      })
    end

    it 'has Polices' do
      expect(properties["Policies"]).to eq([
        {
          "PolicyDocument"=>{
            "Statement"=>[{
              "Action"=>["logs:GetLogEvents"],
              "Effect"=>"Allow",
              "Resource"=>[{"Fn::GetAtt"=>["LogGroup", "Arn"]}],
              "Sid"=>"fargatedefaultpolicy"}
            ]},
            "PolicyName"=>"fargate_default_policy"
        },
        {
          "PolicyName" => "ssm-session-manager",
          "PolicyDocument" => {
            "Statement" => [{
              "Sid" => "ssmsessionmanager",
              "Effect" => "Allow",
              "Action" => [
                "ssmmessages:CreateControlChannel",
                "ssmmessages:CreateDataChannel",
                "ssmmessages:OpenControlChannel",
                "ssmmessages:OpenDataChannel"
              ],
              "Resource" => ["*"],
            }]
          }
        }
      ])
    end

  end

  context 'Resource Service' do

    let(:properties) { template["Resources"]["EcsFargateService"]["Properties"] }

    it 'has property Cluster' do
      expect(properties["Cluster"]).to eq({"Ref"=>"EcsCluster"})
    end

    it 'has property LaunchType' do
      expect(properties["LaunchType"]).to eq("FARGATE")
    end

    it 'has property DesiredCount' do
      expect(properties["DesiredCount"]).to eq({"Ref"=>"DesiredCount"})
    end

    it 'has property DeploymentConfiguration' do
      expect(properties["DeploymentConfiguration"]).to eq({
        "MaximumPercent"=>{"Ref"=>"MaximumPercent"}, 
        "MinimumHealthyPercent"=>{"Ref"=>"MinimumHealthyPercent"}
      })
    end

    it 'has property TaskDefinition' do
      expect(properties["TaskDefinition"]).to eq({"Ref"=>"Task"})
    end

    it 'has property NetworkConfiguration' do
      expect(properties["NetworkConfiguration"]).to eq({
        "AwsvpcConfiguration"=>{
          "AssignPublicIp"=>"DISABLED", 
          "SecurityGroups"=>[{"Ref"=>"SecurityGroup"}], 
          "Subnets"=>{"Ref"=>"SubnetIds"}
        }
      })
    end

  end

  context 'Resource Outputs' do

    let(:outputs) { template["Outputs"] }

    it 'has component_name as part of the export' do
      expect(outputs['EcsTaskArn']).to eq({
        "Export"=>{"Name"=>{"Fn::Sub"=>"${EnvironmentName}-fargatev2Task-EcsTaskArn"}},
        "Value"=>{"Ref"=>"Task"}
      })
    end
  end 

end
