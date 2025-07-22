sudo apt update

# 1. Install OpenSSH
sudo apt install -y openssh-server
sudo systemctl enable ssh
sudo systemctl start ssh

# 2. Remove any old docker versions (optional)
sudo apt remove -y docker docker-engine docker.io containerd runc

# 3. Install required packages
sudo apt install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# 4. Add Docker’s official GPG key
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# 5. Add Docker's repository
echo \
  "deb [arch=$(dpkg --print-architecture) \
  signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 6. Install Docker Engine
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

sudo usermod -aG docker $USER
newgrp docker

# 7. Install QEMU guest
sudo apt update
sudo apt install -y qemu-guest-agent
sudo systemctl enable qemu-guest-agent
sudo systemctl start qemu-guest-agent