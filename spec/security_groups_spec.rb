require 'yaml'

describe 'compiled component' do
  
  context 'cftest' do
    it 'compiles test' do
      expect(system("cfhighlander cftest #{@validate} --tests tests/security_groups.test.yaml")).to be_truthy
    end      
  end

  let(:template) { YAML.load_file("#{File.dirname(__FILE__)}/../out/tests/security_groups/fargate-v2.compiled.yaml") }

  context 'Resource SecurityGroup Source Security Group Ingress' do

    let(:ingress) { template["Resources"]["IngressRule1"]["Properties"] }
  
    it 'has property Properties' do
      expect(ingress).to eq({
        "Description"=>"allows traffic from an existing SG to this service",
        "FromPort"=>80,
        "GroupId"=>{"Ref"=>"SecurityGroup"}, 
        "IpProtocol"=>"tcp", 
        "SourceSecurityGroupId"=>{"Ref"=>"MySecurityGroup"}, 
        "ToPort"=>80
      })
    end

  end

  context 'Resource SecurityGroup Dest Security Group Ingress' do

    let(:ingress) { template["Resources"]["IngressRule2"]["Properties"] }
  
    it 'has property Properties' do
      expect(ingress).to eq({
        "Description"=>"allows traffic from this service to another SG",
        "FromPort"=>1433, 
        "GroupId"=>{"Ref"=>"OtherSecurityGroup"}, 
        "IpProtocol"=>"tcp", 
        "SourceSecurityGroupId"=>{"Ref"=>"SecurityGroup"}, 
        "ToPort"=>1433
      })
    end

  end

  context 'Resource SecurityGroup Dest Security Group Ingress' do

    let(:ingress) { template["Resources"]["IngressRule3"]["Properties"] }
  
    it 'has property Properties' do
      expect(ingress).to eq({
        "Description"=>"allows traffic from one SG to another",
        "FromPort"=>1024, 
        "GroupId"=>{"Ref"=>"SecurityGroup"}, 
        "IpProtocol"=>"tcp", 
        "SourceSecurityGroupId"=>{"Ref"=>"MySecurityGroup"}, 
        "ToPort"=>9999
      })
    end

  end

  context 'Resource SecurityGroup Inbound SSH From CIDR' do

    let(:ingress) { template["Resources"]["IngressRule4"]["Properties"] }
  
    it 'has property Properties' do
      expect(ingress).to eq({
        "Description"=>"allow inbound 22 access from cidr",
        "FromPort"=>22, 
        "CidrIp"=>{"Fn::Sub"=>"10.0.0.1/32"}, 
        "IpProtocol"=>"tcp", 
        "ToPort"=>22
      })
    end

  end

end