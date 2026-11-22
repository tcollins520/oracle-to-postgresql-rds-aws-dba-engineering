
# Retrieves the latest Amazon Linux 2023 x86-64 AMI for the tunnel gateway.
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Configures SSH access for the restricted Oracle reverse-tunnel connection.
locals {
  gateway_user_data = <<-USERDATA
    set -euxo pipefail

    dnf install -y openssh-server
    id oracle-tunnel >/dev/null 2>&1 || useradd --create-home --shell /sbin/nologin oracle-tunnel

    install -d -o oracle-tunnel -g oracle-tunnel -m 0700 /home/oracle-tunnel/.ssh
    cat > /home/oracle-tunnel/.ssh/authorized_keys <<'AUTHORIZED_KEYS'
    restrict,port-forwarding,permitlisten="${var.private_ip}:${var.tunnel_listen_port}" ${var.public_key}
    AUTHORIZED_KEYS
    chown oracle-tunnel:oracle-tunnel /home/oracle-tunnel/.ssh/authorized_keys
    chmod 0600 /home/oracle-tunnel/.ssh/authorized_keys

    cat > /etc/ssh/sshd_config.d/90-oracle-dms-tunnel.conf <<'SSHD'
    PasswordAuthentication no
    PermitRootLogin no
    PubkeyAuthentication yes
    GatewayPorts clientspecified
    AllowUsers oracle-tunnel
    AllowTcpForwarding remote
    PermitListen ${var.private_ip}:${var.tunnel_listen_port}
    PermitTTY no
    X11Forwarding no
    AllowAgentForwarding no
    ForceCommand /sbin/nologin
    MaxSessions 0
    SSHD

    sshd -t
    systemctl enable --now sshd
    systemctl enable --now amazon-ssm-agent || true
  USERDATA
}

# Provisions the private EC2 gateway that receives the Oracle reverse SSH tunnel.
resource "aws_instance" "gateway" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  private_ip                  = var.private_ip
  vpc_security_group_ids      = [var.security_group_id]
  iam_instance_profile        = var.instance_profile_name
  user_data                   = local.gateway_user_data
  user_data_replace_on_change = true
  monitoring                  = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "disabled"
  }

  root_block_device {
    volume_size           = 10
    volume_type           = "gp3"
    encrypted             = true
    kms_key_id            = var.kms_key_arn
    delete_on_termination = true
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-tunnel-gateway"
    Role = "Oracle reverse SSH tunnel"
  })
}

# Assigns a stable public Elastic IP for the Oracle source to reach the gateway.
resource "aws_eip" "gateway" {
  domain   = "vpc"
  instance = aws_instance.gateway.id
  tags     = merge(var.tags, { Name = "${var.project_name}-${var.environment}-tunnel-eip" })
}
