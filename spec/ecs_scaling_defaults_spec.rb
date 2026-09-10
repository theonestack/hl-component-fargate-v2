require 'yaml'

describe 'compiled component fargate-v2' do

  context 'cftest' do
    it 'compiles test' do
      expect(system("cfhighlander cftest #{@validate} --tests tests/ecs_scaling_defaults.test.yaml")).to be_truthy
    end
  end

  let(:template) { YAML.load_file("#{File.dirname(__FILE__)}/../out/tests/ecs_scaling_defaults/fargate-v2.compiled.yaml") }

  context "Resource" do

    context "ServiceScaleUpAlarm" do
      let(:resource) { template["Resources"]["ServiceScaleUpAlarm"] }

      it "falls back to the default EvaluationPeriods when omitted" do
          expect(resource["Properties"]["EvaluationPeriods"]).to eq("5")
      end

    end

    context "ServiceScaleDownAlarm" do
      let(:resource) { template["Resources"]["ServiceScaleDownAlarm"] }

      it "falls back to the default EvaluationPeriods when omitted" do
          expect(resource["Properties"]["EvaluationPeriods"]).to eq("5")
      end

    end

    context "ServiceScalingUpPolicy" do
      let(:resource) { template["Resources"]["ServiceScalingUpPolicy"] }

      it "falls back to the default scale-up Cooldown when omitted" do
          expect(resource["Properties"]["StepScalingPolicyConfiguration"]["Cooldown"]).to eq(300)
      end

    end

    context "ServiceScalingDownPolicy" do
      let(:resource) { template["Resources"]["ServiceScalingDownPolicy"] }

      it "falls back to the default scale-down Cooldown when omitted" do
          expect(resource["Properties"]["StepScalingPolicyConfiguration"]["Cooldown"]).to eq(900)
      end

    end

    context "ServiceTargetTrackingPolicy" do
      let(:resource) { template["Resources"]["ServiceTargetTrackingPolicy"] }
      let(:config) { resource["Properties"]["TargetTrackingScalingPolicyConfiguration"] }

      it "to have property TargetValue" do
          expect(config["TargetValue"]).to eq(50)
      end

      it "omits ScaleInCooldown when not configured" do
          expect(config).not_to have_key("ScaleInCooldown")
      end

      it "omits ScaleOutCooldown when not configured" do
          expect(config).not_to have_key("ScaleOutCooldown")
      end

      it "falls back to the default predefined metric when neither metric_type nor custom is set" do
          expect(config["PredefinedMetricSpecification"]).to eq({"PredefinedMetricType" => "ECSServiceAverageCPUUtilization"})
      end

      it "does not emit a CustomizedMetricSpecification" do
          expect(config).not_to have_key("CustomizedMetricSpecification")
      end

    end

    context "ServiceTargetTrackingPolicy2" do
      let(:resource) { template["Resources"]["ServiceTargetTrackingPolicy2"] }
      let(:config) { resource["Properties"]["TargetTrackingScalingPolicyConfiguration"] }

      it "to have property TargetValue" do
          expect(config["TargetValue"]).to eq(75)
      end

      it "to have property CustomizedMetricSpecification" do
          expect(config["CustomizedMetricSpecification"]).to eq({"Namespace" => "Custom/App", "MetricName" => "QueueDepth", "Statistic" => "Average"})
      end

      it "does not emit a PredefinedMetricSpecification when a custom metric is configured" do
          expect(config).not_to have_key("PredefinedMetricSpecification")
      end

    end

  end

end
