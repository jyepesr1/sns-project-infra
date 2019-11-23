variable "region_name" {
  description = "Region in which the infrastructure will be deployed"
  default     = "us-east-1"
}

variable "public_key_path" {
  description = "Public key path"
  default     = "public_keys/id_rsa.pub"
}

variable "instance_ami" {
  description = "AMI for aws EC2 instance"
  default     = "ami-00068cd7555f543d5" # CentOS 7 (free tier)
}

variable "instance_type" {
  description = "type for aws EC2 instance"
  default     = "t2.micro"
}

data "template_file" "template_bastion" {
  template = <<-EOF
              #!/bin/bash
              yum install -y git python-pip
              amazon-linux-extras install ansible2
              mkdir /usr/ansible
              git clone -b ec2 https://github.com/jyepesr1/ansible_movie_analyst_app /usr/ansible/
              pip install awscli PyMySQL --upgrade --user
              cd /usr/ansible
              ansible-playbook -v --vault-id @get_pass.sh --connection=local -i 127.0.0.1, ./playbooks/bastion.yml
  EOF
}