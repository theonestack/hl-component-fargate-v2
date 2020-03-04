require 'yaml'

describe 'compiled component' do
  
  context 'cftest' do
    it 'compiles test' do
      expect(system("cfhighlander cftest #{@validate} --tests tests/targetgroup_param.test.yaml")).to be_truthy
    end      
  end

  let(:template) { YAML.load_file("#{File.dirname(__FILE__)}/../out/tests/targetgroup_param/fargate-v2.compiled.yaml") }

  context 'check template parameters' do
    
    let(:parameters) { template["Parameters"] }

    it 'has load balancer params' do
      expect(parameters).to include({
        "LoadBalancer" => {"Default"=>"", "NoEcho"=>false, "Type"=>"String"},
        "DnsDomain" => {"Default"=>"", "NoEcho"=>false, "Type"=>"String"},
        "Listener" => {"Default"=>"", "NoEcho"=>false, "Type"=>"String"},
        "TargetGroup" => {"Default"=>"", "NoEcho"=>false, "Type"=>"String"}
      })
    end

    context 'Resource TargetRule' do

      let(:loadbalancer) { template["Resources"]["EcsFargateService"]["Properties"]["LoadBalancers"] }
  
      it 'has property Properties' do
        expect(loadbalancer).to eq([{
          "ContainerName"=>"nginx", 
          "ContainerPort"=>80, 
          "TargetGroupArn"=>{"Ref"=>"TargetGroup"}
        }])
      end
  
    end

  end

end