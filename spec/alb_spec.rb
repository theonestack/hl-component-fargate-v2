require 'yaml'

describe 'compiled component' do
  
  context 'cftest' do
    it 'compiles test' do
      expect(system("cfhighlander cftest #{@validate} --tests tests/alb.test.yaml")).to be_truthy
    end      
  end

  let(:template) { YAML.load_file("#{File.dirname(__FILE__)}/../out/tests/alb/fargate-v2.compiled.yaml") }

  context 'Resource TargetGroup' do

    let(:properties) { template["Resources"]["TaskTargetGroup"]["Properties"] }

    it 'has property Properties' do
      expect(properties).to include({
        "Port"=>80, 
        "Protocol"=>"HTTP", 
        "TargetType"=>"ip", 
        "VpcId"=>{"Ref"=>"VPCId"}
      })
    end

  end

  context 'Resource TargetRule' do

    let(:properties) { template["Resources"]["TargetRule10"]["Properties"] }

    it 'has property Properties' do
      expect(properties).to eq({
        "Actions"=>[{"TargetGroupArn"=>{"Ref"=>"TaskTargetGroup"}, "Type"=>"forward"}], 
        "Conditions"=>[{"Field"=>"host-header", "Values"=>["www.*"]}],
        "ListenerArn"=>{"Ref"=>"Listener"},
        "Priority"=>10
        })
    end

  end

  context 'check template parameters' do
    
    let(:parameters) { template["Parameters"] }

    it 'has load balancer params' do
      expect(parameters).to include({
        "LoadBalancer" => {"Default"=>"", "NoEcho"=>false, "Type"=>"String"},
        "DnsDomain" => {"Default"=>"", "NoEcho"=>false, "Type"=>"String"},
        "Listener" => {"Default"=>"", "NoEcho"=>false, "Type"=>"String"}
      })
    end

    it 'dose not have target group params' do
      expect(parameters).not_to include({
        "TargetGroup" => {"Default"=>"", "NoEcho"=>false, "Type"=>"String"}
      })
    end

  end

end