require 'yaml'

describe 'compiled component' do
  
  context 'cftest' do
    it 'compiles test' do
      expect(system("cfhighlander cftest #{@validate} --tests tests/secrets.test.yaml")).to be_truthy
    end      
  end
  
  let(:template) { YAML.load_file("#{File.dirname(__FILE__)}/../out/tests/secrets/fargate-v2.compiled.yaml") }

  context 'Resource ExecutionRole' do
    
    let(:polices) { template["Resources"]["ExecutionRole"]['Properties']['Policies'] }

    it 'has policies restricting access to secrets' do
      expect(polices).to eq([{
        "PolicyDocument"=> {
          "Statement"=> [{
            "Action"=>"ssm:GetParameters",
            "Effect"=>"Allow",
            "Resource"=>[
              {"Fn::Sub"=>"arn:aws:ssm:${AWS::Region}:${AWS::AccountId}:parameter/${EnvironmentName}/app/MY_SECRET"},
              "arn:aws:ssm:eu-central-1:012345678990:parameter/app/YOUR_SECRET"
            ],
            "Sid"=>"ssmsecrets"
          }]
        },
        "PolicyName"=>"ssm-secrets"
      }])
    end

  end

  context 'Resource Task' do

    let(:secrets) { template["Resources"]["Task"]['Properties']['ContainerDefinitions'][0]['Secrets'] }

    it 'has secrets with arns' do
      expect(secrets).to eq([
        {
          "Name"=>"MY_SECRET",
          "ValueFrom"=>{"Fn::Sub"=>"arn:aws:ssm:${AWS::Region}:${AWS::AccountId}:parameter/${EnvironmentName}/app/MY_SECRET"}
        },
        {
          "Name"=>"YOUR_SECRET",
          "ValueFrom"=>"arn:aws:ssm:eu-central-1:012345678990:parameter/app/YOUR_SECRET"
        }
      ])
    end

  end

end