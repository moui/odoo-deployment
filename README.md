# Odoo 18 deployment on Ubuntu

A Bash script and configuration files that install Odoo 18 (Community, from source) on a single Ubuntu server, behind Nginx with a Let's Encrypt certificate.

It was written for and tried on Ubuntu 22.04 LTS on an AWS EC2 instance. It has not been tested on other releases.

## What the script does

`deploy.sh` runs these steps in order:

1. Installs build tools and the Python/system libraries Odoo needs (`apt`).
2. Creates an `odoo` system user with its home in `/opt/odoo`.
3. Adds the PostgreSQL (PGDG) apt repository, installs PostgreSQL, and starts and enables it.
4. Sets the password of the `postgres` superuser (see [Before you run it](#before-you-run-it)), creates an `odoo` database role with `PG_PASSWORD` and grants it `CREATEDB`.
5. Downloads and installs wkhtmltopdf 0.12.6.1 (the `jammy_amd64` package) for PDF reports.
6. Clones the `18.0` branch of [odoo/odoo](https://github.com/odoo/odoo) into `/opt/odoo/odoo`. If a clone already exists, it runs `git reset --hard` and pulls `18.0`.
7. Creates a virtualenv in `/opt/odoo/odoo-venv` and installs Odoo's `requirements.txt`.
8. Copies `odoo.conf` to `/etc/odoo.conf` and `odoo.service` to `/etc/systemd/system/`, then starts and enables the `odoo` service. Existing files are renamed to `.bak` first.
9. Installs Nginx and Certbot, and requests a certificate with `certbot --nginx`.
10. Installs `odoo-nginx.conf` as `/etc/nginx/sites-available/odoo`, enables it, removes the default site, tests and reloads Nginx.
11. Runs `ufw allow 'Nginx Full'`. It does not enable `ufw`.

Odoo's custom addons directory is `/opt/odoo/odoo-custom-addons`.

## Files

| File | Purpose |
| --- | --- |
| `deploy.sh` | The installation script. |
| `pgsql.conf` | Sourced by the script. Must define `PG_PASSWORD`. Empty in the repository. |
| `odoo.conf` | Odoo server configuration, copied to `/etc/odoo.conf`. |
| `odoo.service` | systemd unit that runs `odoo-bin` from the virtualenv as the `odoo` user. |
| `odoo-nginx.conf` | Nginx site: redirects HTTP to HTTPS and proxies to Odoo on port 8069. |

## Prerequisites

- A fresh Ubuntu 22.04 LTS server on x86_64 (amd64), with a user that can run `sudo`.
- Git.
- A domain name whose DNS record points to the server, and ports 80 and 443 open. Certbot needs both to issue the certificate.

To install Git:

```bash
sudo apt update
sudo apt install git
```

## Before you run it

Several values are hard-coded. Change them before running the script:

| What | Where | Default in the repository |
| --- | --- | --- |
| Odoo database role password | `pgsql.conf`: add `PG_PASSWORD=...` | not set (file is empty) |
| Same password, used by Odoo to connect | `odoo.conf`: `db_password` | `password` |
| Odoo master (database manager) password | `odoo.conf`: `admin_passwd` | `admin` |
| `postgres` superuser password | `deploy.sh`, the `ALTER USER postgres` line | `your_secure_password` |
| Domain for the certificate | `deploy.sh`, the `certbot` line (`-d`) | `odoo.example.com` |
| Let's Encrypt contact email | `deploy.sh`, the `certbot` line (`-m`) | `admin@example.com` |
| Nginx `server_name` and certificate paths | `odoo-nginx.conf` | `odoo.example.com` |

`db_password` in `odoo.conf` must match `PG_PASSWORD` in `pgsql.conf`.

Example `pgsql.conf`:

```bash
PG_PASSWORD='change-me'
```

## Install

```bash
git clone https://github.com/moui/odoo-deployment.git
cd odoo-deployment
# edit pgsql.conf, odoo.conf, odoo-nginx.conf and deploy.sh as described above
bash deploy.sh
```

Run the script from the repository directory: it sources `./pgsql.conf` relative to the current directory. The script is not committed with the executable bit, so call it with `bash` (or run `chmod +x deploy.sh` first).

When it finishes, open `https://<your-domain>` to reach Odoo's database setup page.

## Known limitations

- Only Ubuntu 22.04 on amd64 is targeted: the wkhtmltopdf package is the `jammy_amd64` build, and the PostgreSQL repository key is added with `apt-key`, which is deprecated.
- The script adds the PGDG repository but does not run `apt update` before installing PostgreSQL, so on a first run the PostgreSQL version may come from Ubuntu's own repositories.
- `set -x` is enabled, so commands are echoed to the terminal, including the database passwords.
- Re-running the script appends a duplicate line to `/etc/apt/sources.list.d/pgdg.list` and resets any local changes in `/opt/odoo/odoo`.
- `odoo.conf` does not enable workers, so Odoo runs in threaded mode on port 8069. The `/longpolling/` block in `odoo-nginx.conf` (port 8072) is not used by that setup.
- The systemd unit's `Description` still reads `Odoo17`. The service installs and runs Odoo 18.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
