require 'yaml'

describe 'compiled component fargate-v2' do
  
  context 'cftest' do
    it 'compiles test' do
      expect(system("cfhighlander cftest #{@validate} --tests tests/ecs_scaling.test.yaml")).to be_truthy
    end      
  end
  
  let(:template) { YAML.load_file("#{File.dirname(__FILE__)}/../out/tests/ecs_scaling/fargate-v2.compiled.yaml") }
  
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
          expect(resource["Properties"]["EnableExecuteCommand"]).to eq(false)
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
          expect(resource["Properties"]["Policies"]).to eq([{"PolicyName"=>"fargate_default_policy", "PolicyDocument"=>{"Version"=>"2012-10-17", "Statement"=>[{"Sid"=>"fargatedefaultpolicy", "Action"=>["logs:GetLogEvents"], "Resource"=>[{"Fn::GetAtt"=>["LogGroup", "Arn"]}], "Effect"=>"Allow"}]}}])
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
          expect(resource["Properties"]["ContainerDefinitions"]).to eq([{"Name"=>"proxy", "Image"=>{"Fn::Join"=>["", [{"Fn::Sub"=>"nginx"}, ":", "latest"]]}, "LogConfiguration"=>{"LogDriver"=>"awslogs", "Options"=>{"awslogs-group"=>{"Ref"=>"LogGroup"}, "awslogs-region"=>{"Ref"=>"AWS::Region"}, "awslogs-stream-prefix"=>"proxy"}}}])
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
    
    context "ServiceECSAutoScaleRole" do
      let(:resource) { template["Resources"]["ServiceECSAutoScaleRole"] }

      it "is of type AWS::IAM::Role" do
          expect(resource["Type"]).to eq("AWS::IAM::Role")
      end
      
      it "to have property AssumeRolePolicyDocument" do
          expect(resource["Properties"]["AssumeRolePolicyDocument"]).to eq({"Version"=>"2012-10-17", "Statement"=>[{"Effect"=>"Allow", "Principal"=>{"Service"=>"application-autoscaling.amazonaws.com"}, "Action"=>"sts:AssumeRole"}]})
      end
      
      it "to have property Path" do
          expect(resource["Properties"]["Path"]).to eq("/")
      end
      
      it "to have property Policies" do
          expect(resource["Properties"]["Policies"]).to eq([{"PolicyName"=>"ecs-scaling", "PolicyDocument"=>{"Statement"=>[{"Effect"=>"Allow", "Action"=>["cloudwatch:DescribeAlarms", "cloudwatch:PutMetricAlarm", "cloudwatch:DeleteAlarms"], "Resource"=>"*"}, {"Effect"=>"Allow", "Action"=>["ecs:UpdateService", "ecs:DescribeServices"], "Resource"=>{"Ref"=>"EcsFargateService"}}]}}])
      end
      
    end
    
    context "ServiceScalingTarget" do
      let(:resource) { template["Resources"]["ServiceScalingTarget"] }

      it "is of type AWS::ApplicationAutoScaling::ScalableTarget" do
          expect(resource["Type"]).to eq("AWS::ApplicationAutoScaling::ScalableTarget")
      end
      
      it "to have property MaxCapacity" do
          expect(resource["Properties"]["MaxCapacity"]).to eq({"Ref"=>"fargatev2ScalingMax"})
      end
      
      it "to have property MinCapacity" do
          expect(resource["Properties"]["MinCapacity"]).to eq({"Ref"=>"fargatev2ScalingMin"})
      end
      
      it "to have property ResourceId" do
          expect(resource["Properties"]["ResourceId"]).to eq({"Fn::Join"=>["", ["service/", {"Fn::Select"=>[1, {"Fn::Split"=>["/", {"Ref"=>"EcsFargateService"}]}]}, "/", {"Fn::Select"=>[2, {"Fn::Split"=>["/", {"Ref"=>"EcsFargateService"}]}]}]]})
      end
      
      it "to have property RoleARN" do
          expect(resource["Properties"]["RoleARN"]).to eq({"Fn::GetAtt"=>["ServiceECSAutoScaleRole", "Arn"]})
      end
      
      it "to have property ScalableDimension" do
          expect(resource["Properties"]["ScalableDimension"]).to eq("ecs:service:DesiredCount")
      end
      
      it "to have property ServiceNamespace" do
          expect(resource["Properties"]["ServiceNamespace"]).to eq("ecs")
      end
      
    end
    
    context "ServiceScalingUpPolicy" do
      let(:resource) { template["Resources"]["ServiceScalingUpPolicy"] }

      it "is of type AWS::ApplicationAutoScaling::ScalingPolicy" do
          expect(resource["Type"]).to eq("AWS::ApplicationAutoScaling::ScalingPolicy")
      end
      
      it "to have property PolicyName" do
          expect(resource["Properties"]["PolicyName"]).to eq({"Fn::Join"=>["-", [{"Ref"=>"EnvironmentName"}, "autoscaling", "scale-up-policy"]]})
      end
      
      it "to have property PolicyType" do
          expect(resource["Properties"]["PolicyType"]).to eq("StepScaling")
      end
      
      it "to have property ScalingTargetId" do
          expect(resource["Properties"]["ScalingTargetId"]).to eq({"Ref"=>"ServiceScalingTarget"})
      end
      
      it "to have property StepScalingPolicyConfiguration" do
          expect(resource["Properties"]["StepScalingPolicyConfiguration"]).to eq({"AdjustmentType"=>"ChangeInCapacity", "Cooldown"=>150, "MetricAggregationType"=>"Average", "StepAdjustments"=>[{"ScalingAdjustment"=>"2", "MetricIntervalLowerBound"=>0}]})
      end
      
    end
    
    context "ServiceScaleUpAlarm" do
      let(:resource) { template["Resources"]["ServiceScaleUpAlarm"] }

      it "is of type AWS::CloudWatch::Alarm" do
          expect(resource["Type"]).to eq("AWS::CloudWatch::Alarm")
      end
      
      it "to have property AlarmDescription" do
          expect(resource["Properties"]["AlarmDescription"]).to eq({"Fn::Join"=>[" ", [{"Ref"=>"EnvironmentName"}, "autoscaling ecs scale up alarm"]]})
      end
      
      it "to have property MetricName" do
          expect(resource["Properties"]["MetricName"]).to eq("CPUUtilization")
      end
      
      it "to have property Namespace" do
          expect(resource["Properties"]["Namespace"]).to eq("AWS/ECS")
      end
      
      it "to have property Statistic" do
          expect(resource["Properties"]["Statistic"]).to eq("Average")
      end
      
      it "to have property Period" do
          expect(resource["Properties"]["Period"]).to eq("60")
      end
      
      it "to have property EvaluationPeriods" do
          expect(resource["Properties"]["EvaluationPeriods"]).to eq("5")
      end
      
      it "to have property Threshold" do
          expect(resource["Properties"]["Threshold"]).to eq("70")
      end
      
      it "to have property AlarmActions" do
          expect(resource["Properties"]["AlarmActions"]).to eq([{"Ref"=>"ServiceScalingUpPolicy"}])
      end
      
      it "to have property ComparisonOperator" do
          expect(resource["Properties"]["ComparisonOperator"]).to eq("GreaterThanThreshold")
      end
      
      it "to have property Dimensions" do
          expect(resource["Properties"]["Dimensions"]).to eq([{"Name"=>"ServiceName", "Value"=>{"Fn::Select"=>[2, {"Fn::Split"=>["/", {"Ref"=>"EcsFargateService"}]}]}}, {"Name"=>"ClusterName", "Value"=>{"Fn::Select"=>[1, {"Fn::Split"=>["/", {"Ref"=>"EcsFargateService"}]}]}}])
      end
      
    end
    
    context "ServiceScalingDownPolicy" do
      let(:resource) { template["Resources"]["ServiceScalingDownPolicy"] }

      it "is of type AWS::ApplicationAutoScaling::ScalingPolicy" do
          expect(resource["Type"]).to eq("AWS::ApplicationAutoScaling::ScalingPolicy")
      end
      
      it "to have property PolicyName" do
          expect(resource["Properties"]["PolicyName"]).to eq({"Fn::Join"=>["-", [{"Ref"=>"EnvironmentName"}, "autoscaling", "scale-down-policy"]]})
      end
      
      it "to have property PolicyType" do
          expect(resource["Properties"]["PolicyType"]).to eq("StepScaling")
      end
      
      it "to have property ScalingTargetId" do
          expect(resource["Properties"]["ScalingTargetId"]).to eq({"Ref"=>"ServiceScalingTarget"})
      end
      
      it "to have property StepScalingPolicyConfiguration" do
          expect(resource["Properties"]["StepScalingPolicyConfiguration"]).to eq({"AdjustmentType"=>"ChangeInCapacity", "Cooldown"=>600, "MetricAggregationType"=>"Average", "StepAdjustments"=>[{"ScalingAdjustment"=>"-1", "MetricIntervalUpperBound"=>0}]})
      end
      
    end
    
    context "ServiceScaleDownAlarm" do
      let(:resource) { template["Resources"]["ServiceScaleDownAlarm"] }

      it "is of type AWS::CloudWatch::Alarm" do
          expect(resource["Type"]).to eq("AWS::CloudWatch::Alarm")
      end
      
      it "to have property AlarmDescription" do
          expect(resource["Properties"]["AlarmDescription"]).to eq({"Fn::Join"=>[" ", [{"Ref"=>"EnvironmentName"}, "autoscaling ecs scale down alarm"]]})
      end
      
      it "to have property MetricName" do
          expect(resource["Properties"]["MetricName"]).to eq("CPUUtilization")
      end
      
      it "to have property Namespace" do
          expect(resource["Properties"]["Namespace"]).to eq("AWS/ECS")
      end
      
      it "to have property Statistic" do
          expect(resource["Properties"]["Statistic"]).to eq("Average")
      end
      
      it "to have property Period" do
          expect(resource["Properties"]["Period"]).to eq("60")
      end
      
      it "to have property EvaluationPeriods" do
          expect(resource["Properties"]["EvaluationPeriods"]).to eq("5")
      end
      
      it "to have property Threshold" do
          expect(resource["Properties"]["Threshold"]).to eq("70")
      end
      
      it "to have property AlarmActions" do
          expect(resource["Properties"]["AlarmActions"]).to eq([{"Ref"=>"ServiceScalingDownPolicy"}])
      end
      
      it "to have property ComparisonOperator" do
          expect(resource["Properties"]["ComparisonOperator"]).to eq("LessThanThreshold")
      end
      
      it "to have property Dimensions" do
          expect(resource["Properties"]["Dimensions"]).to eq([{"Name"=>"ServiceName", "Value"=>{"Fn::Select"=>[2, {"Fn::Split"=>["/", {"Ref"=>"EcsFargateService"}]}]}}, {"Name"=>"ClusterName", "Value"=>{"Fn::Select"=>[1, {"Fn::Split"=>["/", {"Ref"=>"EcsFargateService"}]}]}}])
      end
      
    end
    
  end

end