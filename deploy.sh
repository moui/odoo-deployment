#!/bin/bash
set -e
set -x

# Source the configuration file
source pgsql.conf

echo "Installing Odoo..."

# Update system packages

sudo apt update

# Install Git

sudo apt install git -y

# Install pip

sudo apt install python3-pip -y

# Install other dependencies

sudo apt install -y build-essential wget python3-dev python3-venv python3-wheel libfreetype6-dev libxml2-dev libzip-dev libldap2-dev libsasl2-dev python3-setuptools node-less libjpeg-dev zlib1g-dev libpq-dev libxslt1-dev libldap2-dev libtiff5-dev libjpeg8-dev libopenjp2-7-dev liblcms2-dev libwebp-dev libharfbuzz-dev libfribidi-dev libxcb1-dev

# Create a system user for Odoo

sudo adduser --system --home=/opt/odoo --group odoo

# Install and configure PostgreSQL

sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ `lsb_release -cs`-pgdg main" >> /etc/apt/sources.list.d/pgdg.list'

wget -q https://www.postgresql.org/media/keys/ACCC4CF8.asc -O - | sudo apt-key add -

sudo apt install postgresql postgresql-contrib -y

# Start and enable PostgreSQL

sudo systemctl start postgresql || { echo "PostgreSQL failed to start"; exit 1; }

sudo systemctl enable postgresql

# Change the password of the PostgreSQL user

sudo passwd postgres -d

# Create the database user and give it permission to create new databases

sudo -u postgres psql -c "CREATE USER odoo WITH PASSWORD '$PG_PASSWORD';"
sudo -u postgres psql -c "ALTER USER odoo CREATEDB;"

# Install Wkhtmltopdf

sudo wget https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-2/wkhtmltox_0.12.6.1-2.jammy_amd64.deb

sudo apt install ./wkhtmltox_0.12.6.1-2.jammy_amd64.deb

# Create a directory for Odoo and set the owner to the Odoo user.

sudo mkdir -p /opt/odoo/odoo
sudo chown -R odoo /opt/odoo
sudo chgrp -R odoo /opt/odoo

# Switch to the odoo user account.

sudo su - odoo

# Clone the Odoo source code from the Odoo GitHub repository.

git clone https://www.github.com/odoo/odoo --depth 1 --branch 17.0 /opt/odoo/odoo

# Create a new Python virtual environment for Odoo.

cd /opt/odoo
python3 -m venv odoo-venv

# Activate the virtual environment.

source odoo-venv/bin/activate

# Install the required Python modules.

pip3 install wheel
pip3 install -r odoo/requirements.txt

# Deactivate the virtual environment.

deactivate

# Create a new directory for 3rd party add-ons.

sudo mkdir -p /opt/odoo/odoo-custom-addons
sudo chown -R odoo:odoo /opt/odoo/odoo-custom-addons

# Copy the configuration file for Odoo from the same folder this script is located in.

sudo cp odoo.conf /etc/odoo.conf

# Copy the service unit file for Odoo from the same folder this script is located in.

sudo cp odoo.service /etc/systemd/system/odoo.service

# Reload the systemd manager configuration.

sudo systemctl daemon-reload

# Start and enable the Odoo service.

sudo systemctl start odoo || { echo "Odoo service failed to start"; exit 1; }

sudo systemctl enable odoo

echo "Odoo has been installed successfully."
