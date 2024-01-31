require 'yaml'

describe 'compiled component fargate-v2' do
  
  context 'cftest' do
    it 'compiles test' do
      expect(system("cfhighlander cftest #{@validate} --tests tests/ecs_exec.test.yaml")).to be_truthy
    end      
  end
  
  let(:template) { YAML.load_file("#{File.dirname(__FILE__)}/../out/tests/ecs_exec/fargate-v2.compiled.yaml") }
  
  context "Resource" do

    
    context "SecurityGroup" do
      let(:resource) { template["Resources"]["SecurityGroup"] }

      it "is of type AWS::EC2::SecurityGroup" do
          expect(resource["Type"]).to eq("AWS::EC2::SecurityGroup")
      end
      
      it "to have property VpcId" do
          expect(resource["Properties"]["VpcId"]).to eq({"Ref"=>"VPCId"})
      end
      
      it "to have property GroupDescription" do
          expect(resource["Properties"]["GroupDescription"]).to eq("fargate-v2 fargate service")
      end
      
    end
    
    context "EcsFargateService" do
      let(:resource) { template["Resources"]["EcsFargateService"] }

      it "is of type AWS::ECS::Service" do
          expect(resource["Type"]).to eq("AWS::ECS::Service")
      end
      
      it "to have property Cluster" do
          expect(resource["Properties"]["Cluster"]).to eq({"Ref"=>"EcsCluster"})
      end
      
      it "to have property PlatformVersion" do
          expect(resource["Properties"]["PlatformVersion"]).to eq("1.4.0")
      end
      
      it "to have property DesiredCount" do
          expect(resource["Properties"]["DesiredCount"]).to eq({"Ref"=>"DesiredCount"})
      end
      
      it "to have property DeploymentConfiguration" do
          expect(resource["Properties"]["DeploymentConfiguration"]).to eq({"MinimumHealthyPercent"=>{"Ref"=>"MinimumHealthyPercent"}, "MaximumPercent"=>{"Ref"=>"MaximumPercent"}})
      end
      
      it "to have property EnableExecuteCommand" do
          expect(resource["Properties"]["EnableExecuteCommand"]).to eq(true)
      end
      
      it "to have property TaskDefinition" do
          expect(resource["Properties"]["TaskDefinition"]).to eq({"Ref"=>"Task"})
      end
      
      it "to have property LaunchType" do
          expect(resource["Properties"]["LaunchType"]).to eq("FARGATE")
      end
      
      it "to have property NetworkConfiguration" do
          expect(resource["Properties"]["NetworkConfiguration"]).to eq({"AwsvpcConfiguration"=>{"AssignPublicIp"=>"DISABLED", "SecurityGroups"=>[{"Ref"=>"SecurityGroup"}], "Subnets"=>{"Ref"=>"SubnetIds"}}})
      end
      
    end
    
    context "LogGroup" do
      let(:resource) { template["Resources"]["LogGroup"] }

      it "is of type AWS::Logs::LogGroup" do
          expect(resource["Type"]).to eq("AWS::Logs::LogGroup")
      end
      
      it "to have property LogGroupName" do
          expect(resource["Properties"]["LogGroupName"]).to eq({"Ref"=>"AWS::StackName"})
      end
      
      it "to have property RetentionInDays" do
          expect(resource["Properties"]["RetentionInDays"]).to eq(7)
      end
      
    end
    
    context "TaskRole" do
      let(:resource) { template["Resources"]["TaskRole"] }

      it "is of type AWS::IAM::Role" do
          expect(resource["Type"]).to eq("AWS::IAM::Role")
      end
      
      it "to have property AssumeRolePolicyDocument" do
          expect(resource["Properties"]["AssumeRolePolicyDocument"]).to eq({"Version"=>"2012-10-17", "Statement"=>[{"Effect"=>"Allow", "Principal"=>{"Service"=>"ecs-tasks.amazonaws.com"}, "Action"=>"sts:AssumeRole"}, {"Effect"=>"Allow", "Principal"=>{"Service"=>"ssm.amazonaws.com"}, "Action"=>"sts:AssumeRole"}]})
      end
      
      it "to have property Path" do
          expect(resource["Properties"]["Path"]).to eq("/")
      end
      
      it "to have property Policies" do
          expect(resource["Properties"]["Policies"]).to eq([{"PolicyName"=>"fargate_default_policy", "PolicyDocument"=>{"Statement"=>[{"Sid"=>"fargatedefaultpolicy", "Action"=>["logs:GetLogEvents"], "Resource"=>[{"Fn::GetAtt"=>["LogGroup", "Arn"]}], "Effect"=>"Allow"}]}}, {"PolicyName"=>"ssm-session-manager", "PolicyDocument"=>{"Statement"=>[{"Sid"=>"ssmsessionmanager", "Action"=>["ssmmessages:CreateControlChannel", "ssmmessages:CreateDataChannel", "ssmmessages:OpenControlChannel", "ssmmessages:OpenDataChannel"], "Resource"=>["*"], "Effect"=>"Allow"}]}}])
      end
      
    end
    
    context "ExecutionRole" do
      let(:resource) { template["Resources"]["ExecutionRole"] }

      it "is of type AWS::IAM::Role" do
          expect(resource["Type"]).to eq("AWS::IAM::Role")
      end
      
      it "to have property AssumeRolePolicyDocument" do
          expect(resource["Properties"]["AssumeRolePolicyDocument"]).to eq({"Version"=>"2012-10-17", "Statement"=>[{"Effect"=>"Allow", "Principal"=>{"Service"=>"ecs-tasks.amazonaws.com"}, "Action"=>"sts:AssumeRole"}, {"Effect"=>"Allow", "Principal"=>{"Service"=>"ssm.amazonaws.com"}, "Action"=>"sts:AssumeRole"}]})
      end
      
      it "to have property Path" do
          expect(resource["Properties"]["Path"]).to eq("/")
      end
      
      it "to have property ManagedPolicyArns" do
          expect(resource["Properties"]["ManagedPolicyArns"]).to eq(["arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"])
      end
      
    end
    
    context "Task" do
      let(:resource) { template["Resources"]["Task"] }

      it "is of type AWS::ECS::TaskDefinition" do
          expect(resource["Type"]).to eq("AWS::ECS::TaskDefinition")
      end
      
      it "to have property ContainerDefinitions" do
          expect(resource["Properties"]["ContainerDefinitions"]).to eq([{"Name"=>"proxy", "Image"=>{"Fn::Join"=>["", ["", "nginx", ":", "latest"]]}, "LogConfiguration"=>{"LogDriver"=>"awslogs", "Options"=>{"awslogs-group"=>{"Ref"=>"LogGroup"}, "awslogs-region"=>{"Ref"=>"AWS::Region"}, "awslogs-stream-prefix"=>"proxy"}}}])
      end
      
      it "to have property RequiresCompatibilities" do
          expect(resource["Properties"]["RequiresCompatibilities"]).to eq(["FARGATE"])
      end
      
      it "to have property Cpu" do
          expect(resource["Properties"]["Cpu"]).to eq(256)
      end
      
      it "to have property Memory" do
          expect(resource["Properties"]["Memory"]).to eq(512)
      end
      
      it "to have property NetworkMode" do
          expect(resource["Properties"]["NetworkMode"]).to eq("awsvpc")
      end
      
      it "to have property TaskRoleArn" do
          expect(resource["Properties"]["TaskRoleArn"]).to eq({"Ref"=>"TaskRole"})
      end
      
      it "to have property ExecutionRoleArn" do
          expect(resource["Properties"]["ExecutionRoleArn"]).to eq({"Ref"=>"ExecutionRole"})
      end
      
      it "to have property Tags" do
          expect(resource["Properties"]["Tags"]).to eq([{"Key"=>"Name", "Value"=>"fargatev2Task"}, {"Key"=>"Environment", "Value"=>{"Ref"=>"EnvironmentName"}}, {"Key"=>"EnvironmentType", "Value"=>{"Ref"=>"EnvironmentType"}}])
      end
      
    end
    
  end

end