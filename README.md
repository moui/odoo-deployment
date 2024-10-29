# Odoo 18 deployment on Ubuntu

This script and configuration files are used to deploy Odoo 17 on Ubuntu. For testing purposes, I used Ubuntu 22.04 LTS in an AWS EC2 instance.

## Prerequisites

- AWS EC2 instance with Ubuntu 22.04 LTS
- Git

## Installing Git

To install Git on Ubuntu, run the following commands:

```bash
sudo apt update
sudo apt install git
```

## Installing Odoo 18

### Clone this repository

```bash
git clone
```

### Configure

Edit the odoo.conf file and set the desired values for the parameters.
Edit the pgsql.conf file and set the desired values for the parameters.

### Run the installation script

```bash
cd odoo-17-ubuntu-deployment
./deploy.sh
```

### Access Odoo

Open your browser and go to your server's IP address or domain name.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
