require 'yaml'

describe 'compiled component' do
  
  context 'cftest' do
    it 'compiles test' do
      expect(system("cfhighlander cftest #{@validate} --tests tests/multiple_target_groups.test.yaml")).to be_truthy
    end
  end

  let(:template) { YAML.load_file("#{File.dirname(__FILE__)}/../out/tests/multiple_target_groups/fargate-v2.compiled.yaml") }

  context 'Resource Web TargetGroup' do
    let(:properties) { template["Resources"]["webTargetGroup"]["Properties"] }

    it 'has a web target group' do
      expect(properties).to eq({
        "Port" => 80,
        "Protocol" => "HTTP",
        "Tags" => [{"Key"=>"Environment", "Value"=>{"Ref"=>"EnvironmentName"}}, {"Key"=>"EnvironmentType", "Value"=>{"Ref"=>"EnvironmentType"}}],
        "TargetType" => "ip",
        "VpcId" => {"Ref"=>"VPCId"},
      })
    end
  end

  context 'Resource Secure TargetGroup' do
    let(:properties) { template["Resources"]["secureTargetGroup"]["Properties"] }

    it 'has a secure target group' do
      expect(properties).to eq({
        "Port" => 443,
        "Protocol" => "HTTP",
        "Tags" => [{"Key"=>"Environment", "Value"=>{"Ref"=>"EnvironmentName"}}, {"Key"=>"EnvironmentType", "Value"=>{"Ref"=>"EnvironmentType"}}],
        "TargetType" => "ip",
        "VpcId" => {"Ref"=>"VPCId"},
      })
    end
  end

  context 'has web listener rule' do
    let(:parameters) { template["Parameters"] }
    let(:properties) { template["Resources"]["webTargetRule10"]["Properties"] }

    it 'has a web listener rule' do
      expect(parameters).to include({
        "DnsDomain" => {"Default"=>"", "NoEcho"=>false, "Type"=>"String"},
        "httpListener" => {"Default"=>"", "NoEcho"=>false, "Type"=>"String"},
      })

      expect(properties).to eq({
        "Actions" => [{"TargetGroupArn"=>{"Ref"=>"webTargetGroup"}, "Type"=>"forward"}],
        "Conditions" => [{"Field"=>"host-header", "Values"=>["www.*"]}],
        "ListenerArn" => {"Ref"=>"httpListener"},
        "Priority" => 10,
      })
    end
  end

  context 'has secure listener rule' do
    let(:parameters) { template["Parameters"] }
    let(:properties) { template["Resources"]["secureTargetRule10"]["Properties"] }

    it 'has a web listener rule' do
      expect(parameters).to include({
        "DnsDomain" => {"Default"=>"", "NoEcho"=>false, "Type"=>"String"},
        "httpListener" => {"Default"=>"", "NoEcho"=>false, "Type"=>"String"},
      })

      expect(properties).to eq({
        "Actions" => [{"TargetGroupArn"=>{"Ref"=>"secureTargetGroup"}, "Type"=>"forward"}],
        "Conditions" => [{"Field"=>"host-header", "Values"=>["www.*"]}],
        "ListenerArn" => {"Ref"=>"httpsListener"},
        "Priority" => 10,
      })
    end
  end

end