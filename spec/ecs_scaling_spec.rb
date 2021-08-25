require 'yaml'

describe 'compiled component' do
  
  context 'cftest' do
    it 'compiles test' do
      expect(system("cfhighlander cftest #{@validate} --tests tests/ecs_scaling.test.yaml")).to be_truthy
    end      
  end
  
  let(:template) { YAML.load_file("#{File.dirname(__FILE__)}/../out/tests/ecs_scaling/fargate-v2.compiled.yaml") }

  context 'Resource LogGroup' do

    let(:properties) { template["Resources"]["LogGroup"]["Properties"] }

    it 'has property RetentionInDays' do
      expect(properties["RetentionInDays"]).to eq('7')
    end

    it 'has property LogGroupName' do
      expect(properties["LogGroupName"]).to eq({"Ref"=>"AWS::StackName"})
    end

  end

  context 'Resource IAM Role' do
    let(:properties) { template["Resources"]["ServiceECSAutoScaleRole"]["Properties"] }

    it 'has property AssumeRolePolicyDocument' do
        expect(properties["AssumeRolePolicyDocument"]).to eq(
          {"Statement"=>[{"Action"=>"sts:AssumeRole", "Effect"=>"Allow", "Principal"=>{"Service"=>"application-autoscaling.amazonaws.com"}}], "Version"=>"2012-10-17"}
        )
    end

    it 'has property Policies' do
        expect(properties["Policies"]).to eq([{
          "PolicyDocument"=> {
              "Statement"=> [
                {
                  "Action"=> [
                    "cloudwatch:DescribeAlarms",
                    "cloudwatch:PutMetricAlarm",
                    "cloudwatch:DeleteAlarms"
                  ],
                  "Effect"=>"Allow",
                  "Resource"=>"*"
                },
                {
                  "Action"=>["ecs:UpdateService", "ecs:DescribeServices"],
                  "Effect"=>"Allow",
                  "Resource"=>{"Ref"=>"EcsFargateService"}
                }
              ]
            },
            "PolicyName"=>"ecs-scaling"
        }])
    end
  end

  context 'Resource ServiceScalingTarget' do
    let(:properties) { template["Resources"]["ServiceScalingTarget"]["Properties"] }

    it 'has properties' do
      expect(properties).to eq({
        "MaxCapacity" => {"Ref"=>"fargatev2ScalingMax"},
        "MinCapacity" => {"Ref"=>"fargatev2ScalingMin"},
        "ResourceId" => {"Fn::Join"=>["", ["service/", {"Fn::Select"=>[1, {"Fn::Split"=>["/", {"Ref"=>"EcsFargateService"}]}]}, "/", {"Fn::Select"=>[2, {"Fn::Split"=>["/", {"Ref"=>"EcsFargateService"}]}]}]]},
        "RoleARN" => {"Fn::GetAtt"=>["ServiceECSAutoScaleRole", "Arn"]},
        "ScalableDimension" => "ecs:service:DesiredCount",
        "ServiceNamespace" => "ecs",
      })
    end
  end

  context 'Resource ServiceScalingUpPolicy' do
    let(:properties) { template["Resources"]["ServiceScalingUpPolicy"]["Properties"] }

    it 'has properties' do
      expect(properties).to eq({
        "PolicyName" => {"Fn::Join"=>["-", [{"Ref"=>"EnvironmentName"}, "autoscaling", "scale-up-policy"]]},
        "PolicyType" => "StepScaling",
        "ScalingTargetId" => {"Ref"=>"ServiceScalingTarget"},
        "StepScalingPolicyConfiguration" => {"AdjustmentType"=>"ChangeInCapacity", "Cooldown"=>150, "MetricAggregationType"=>"Average", "StepAdjustments"=>[{"MetricIntervalLowerBound"=>0, "ScalingAdjustment"=>"2"}]},
      })
    end
  end

  context 'Resource ServiceScaleUpAlarm' do
    let(:properties) { template["Resources"]["ServiceScaleUpAlarm"]["Properties"] }

    it 'has properties' do
      expect(properties).to eq({
        "AlarmActions" => [{"Ref"=>"ServiceScalingUpPolicy"}],
        "AlarmDescription" => {"Fn::Join"=>[" ", [{"Ref"=>"EnvironmentName"}, "autoscaling ecs scale up alarm"]]},
        "ComparisonOperator" => "GreaterThanThreshold",
        "Dimensions" => [{"Name"=>"ServiceName", "Value"=>{"Fn::Select"=>[2, {"Fn::Split"=>["/", {"Ref"=>"EcsFargateService"}]}]}}, {"Name"=>"ClusterName", "Value"=>{"Fn::Select"=>[1, {"Fn::Split"=>["/", {"Ref"=>"EcsFargateService"}]}]}}],
        "EvaluationPeriods" => "5",
        "MetricName" => "CPUUtilization",
        "Namespace" => "AWS/ECS",
        "Period" => "60",
        "Statistic" => "Average",
        "Threshold" => "70",
      })
    end
  end

  context 'Resource ServiceScalingDownPolicy' do
    let(:properties) { template["Resources"]["ServiceScalingDownPolicy"]["Properties"] }

    it 'has properties' do
      expect(properties).to eq({
        "PolicyName" => {"Fn::Join"=>["-", [{"Ref"=>"EnvironmentName"}, "autoscaling", "scale-down-policy"]]},
        "PolicyType" => "StepScaling",
        "ScalingTargetId" => {"Ref"=>"ServiceScalingTarget"},
        "StepScalingPolicyConfiguration" => {"AdjustmentType"=>"ChangeInCapacity", "Cooldown"=>600, "MetricAggregationType"=>"Average", "StepAdjustments"=>[{"MetricIntervalUpperBound"=>0, "ScalingAdjustment"=>"-1"}]},
      })
    end
  end

  context 'Resource ServiceScaleDownAlarm' do
    let(:properties) { template["Resources"]["ServiceScaleDownAlarm"]["Properties"] }

    it 'has properties' do
      expect(properties).to eq({
        "AlarmActions" => [{"Ref"=>"ServiceScalingDownPolicy"}],
        "AlarmDescription" => {"Fn::Join"=>[" ", [{"Ref"=>"EnvironmentName"}, "autoscaling ecs scale down alarm"]]},
        "ComparisonOperator" => "LessThanThreshold",
        "Dimensions" => [{"Name"=>"ServiceName", "Value"=>{"Fn::Select"=>[2, {"Fn::Split"=>["/", {"Ref"=>"EcsFargateService"}]}]}}, {"Name"=>"ClusterName", "Value"=>{"Fn::Select"=>[1, {"Fn::Split"=>["/", {"Ref"=>"EcsFargateService"}]}]}}],
        "EvaluationPeriods" => "5",
        "MetricName" => "CPUUtilization",
        "Namespace" => "AWS/ECS",
        "Period" => "60",
        "Statistic" => "Average",
        "Threshold" => "70",
      })
    end
  end
end