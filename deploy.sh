#!/bin/bash
set -e
set -x

# Source the configuration file
. ./pgsql.conf

# Determine the directory of the script (useful for relative file operations)
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

echo "Installing Odoo..."

# Update system packages
sudo apt update

# Install pip
sudo apt install python3-pip -y

# Install other dependencies
sudo apt install -y build-essential wget python3-dev python3-venv python3-wheel \
    libfreetype6-dev libxml2-dev libzip-dev libldap2-dev libsasl2-dev python3-setuptools \
    node-less libjpeg-dev zlib1g-dev libpq-dev

# Create a system user for Odoo if it doesn't exist
if ! id "odoo" &>/dev/null; then
    sudo adduser --system --home=/opt/odoo --group odoo
fi

# Install and configure PostgreSQL
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ `lsb_release -cs`-pgdg main" >> /etc/apt/sources.list.d/pgdg.list'
wget -q https://www.postgresql.org/media/keys/ACCC4CF8.asc -O - | sudo apt-key add -
sudo apt install postgresql postgresql-contrib -y

# Start and enable PostgreSQL
sudo systemctl start postgresql || { echo "PostgreSQL failed to start"; exit 1; }
sudo systemctl enable postgresql

# Change the password of the PostgreSQL user
sudo -u postgres psql -c "ALTER USER postgres PASSWORD 'your_secure_password';"

# Create the database user and give it permission to create new databases
if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='odoo'" | grep -q 1; then
    sudo -u postgres psql -c "CREATE USER odoo WITH PASSWORD '$PG_PASSWORD';"
else
    echo "Role 'odoo' already exists, skipping creation."
fi

# Ensure the odoo user has permission to create databases
sudo -u postgres psql -c "ALTER USER odoo CREATEDB;"

# Install Wkhtmltopdf
sudo wget https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-2/wkhtmltox_0.12.6.1-2.jammy_amd64.deb
sudo apt install ./wkhtmltox_0.12.6.1-2.jammy_amd64.deb

# Create the necessary directories if they don't already exist
if [ ! -d "/opt/odoo" ]; then
    echo "Creating /opt/odoo directory..."
    sudo mkdir -p /opt/odoo/odoo /opt/odoo/odoo-custom-addons
    sudo chown -R odoo:odoo /opt/odoo
else
    echo "/opt/odoo directory already exists. Skipping creation."
fi

# Clone the Odoo repository if it doesn't already exist, or update it if it does
if [ ! -d "/opt/odoo/odoo/.git" ]; then
    echo "Cloning Odoo repository..."
    sudo -u odoo git clone https://www.github.com/odoo/odoo --depth 1 --branch 18.0 /opt/odoo/odoo
else
    echo "Odoo directory already exists. Updating the repository..."
    cd /opt/odoo/odoo
    sudo -u odoo git reset --hard  # Ensure no local changes interfere
    sudo -u odoo git pull origin 18.0
fi

# Create the Python virtual environment
sudo -u odoo python3 -m venv /opt/odoo/odoo-venv

# Install required Python modules in the virtual environment
sudo -u odoo /opt/odoo/odoo-venv/bin/pip3 install wheel
sudo -u odoo /opt/odoo/odoo-venv/bin/pip3 install -r /opt/odoo/odoo/requirements.txt

# Copy the configuration file for Odoo, back up if it exists
if [ -f "/etc/odoo.conf" ]; then
    echo "Backing up existing Odoo configuration..."
    sudo mv /etc/odoo.conf /etc/odoo.conf.bak
fi
sudo cp "$SCRIPT_DIR/odoo.conf" /etc/odoo.conf
sudo chown odoo:odoo /etc/odoo.conf

# Copy the systemd service unit file for Odoo, back up if it exists
if [ -f "/etc/systemd/system/odoo.service" ]; then
    echo "Backing up existing Odoo service unit..."
    sudo mv /etc/systemd/system/odoo.service /etc/systemd/system/odoo.service.bak
fi
sudo cp "$SCRIPT_DIR/odoo.service" /etc/systemd/system/odoo.service

# Reload systemd to recognize the new service file
sudo systemctl daemon-reload

# Start the Odoo service and check status
sudo systemctl start odoo || { echo "Odoo service failed to start"; exit 1; }
if ! sudo systemctl status odoo; then
    echo "Odoo service is not running."
    exit 1
fi

# Enable the Odoo service to start on boot
sudo systemctl enable odoo

# Install Nginx
echo "Installing Nginx..."
sudo apt install nginx -y

# Install Certbot and Nginx plugin
sudo apt install certbot python3-certbot-nginx -y

# Obtain an SSL certificate (replace <your-domain> with your actual domain)
sudo certbot --nginx -d odoo.moui.dev --non-interactive --agree-tos -m hola@moui.dev

# Copy the Nginx configuration file from the repo to the correct location
if [ -f "/etc/nginx/sites-available/odoo" ]; then
    echo "Backing up existing Nginx configuration for Odoo..."
    sudo mv /etc/nginx/sites-available/odoo /etc/nginx/sites-available/odoo.bak
fi
sudo cp "$SCRIPT_DIR/odoo-nginx.conf" /etc/nginx/sites-available/odoo

# Create a symbolic link to enable the site, only if it doesn't already exist
if [ ! -L /etc/nginx/sites-enabled/odoo ]; then
    echo "Creating symbolic link for Nginx site configuration..."
    sudo ln -s /etc/nginx/sites-available/odoo /etc/nginx/sites-enabled/
    # Remove the default site only if it exists
    if [ -L /etc/nginx/sites-enabled/default ]; then
        sudo rm /etc/nginx/sites-enabled/default
    fi
else
    echo "Symbolic link for Nginx site configuration already exists. Skipping creation."
fi

# Test Nginx configuration and reload the service
sudo nginx -t || { echo "Nginx configuration test failed"; exit 1; }
sudo systemctl reload nginx

# Allow HTTP traffic in the firewall (optional, depends on your setup)
sudo ufw allow 'Nginx Full'

echo "Odoo and Nginx have been installed and configured successfully."
