require 'yaml'

describe 'compiled component' do
  
  context 'cftest' do
    it 'compiles test' do
      expect(system("cfhighlander cftest #{@validate} --tests tests/existing_target_groups.test.yaml")).to be_truthy
    end
  end

  let(:template) { YAML.load_file("#{File.dirname(__FILE__)}/../out/tests/existing_target_groups/fargate-v2.compiled.yaml") }

  context 'has ecs ervice with multiple target groups' do
    let(:parameters) { template["Parameters"] }
    let(:properties) { template["Resources"]["EcsFargateService"]["Properties"] }

    it 'has a target group params' do
      expect(parameters).to include({
        "webTargetGroup" => {"Default"=>"", "NoEcho"=>false, "Type"=>"String"},
        "secureTargetGroup" => {"Default"=>"", "NoEcho"=>false, "Type"=>"String"},
      })
    end

    it 'has an ecs service with multiple targetgroups reference' do
        expect(properties['LoadBalancers']).to eq([
            {
                "ContainerName"=>"nginx",
                "ContainerPort"=>80,
                "TargetGroupArn"=>{"Ref"=>"webTargetGroup"}
            },
            {
                "ContainerName"=>"nginx",
                "ContainerPort"=>443,
                "TargetGroupArn"=>{"Ref"=>"secureTargetGroup"}
            }
        ])
    end
  end

end