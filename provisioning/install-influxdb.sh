#!/bin/bash

sudo yum update -y

echo "Installing influxdb"
wget https://dl.influxdata.com/influxdb/releases/influxdb-1.7.6.x86_64.rpm
sudo yum localinstall -y influxdb-1.7.6.x86_64.rpm
sudo systemctl enable influxdb.service

echo "Creating data directories"
sudo mkdir -p /opt/influx/{wal,data,ssl}
sudo chown -R influxdb:influxdb /opt/influx/

echo "Altering configuration"
sudo cp /etc/influxdb/influxdb.conf{,-bak}
sudo sed -i 's./var/lib/influxdb/meta./opt/influx/data/meta.' /etc/influxdb/influxdb.conf
sudo sed -i 's./var/lib/influxdb/data./opt/influx/data/data.' /etc/influxdb/influxdb.conf
sudo sed -i 's./var/lib/influxdb/wal./opt/influx/wal.' /etc/influxdb/influxdb.conf
#sduo sed -i 's,# https-certificate = "/etc/ssl/influxdb.pem",https-certificate = "/opt/influx/ssl/bundle.pem",' /etc/influxdb/influxdb.conf
#sduo sed -i 's/# https-enabled = false/https-enabled = true/'' /etc/influxdb/influxdb.conf

echo "Starting influxdb"
sudo systemctl start influxdb
sleep 3
systemctl is-active --quiet influxdb || (echo "Influxdb could not be started" && exit 1)

echo "Creating users and database"
influx -execute "create user superadmin with password '$1' with all privileges"
influx -execute "create user grafana with password '$2' "
influx -execute "create database ruuvi"
influx -execute "grant ALL on ruuvi to grafana"

echo "Stopping influxdb"
sudo systemctl stop influxdb
sleep 3

echo "Enabling authentication"
sudo sed -i "s/# auth-enabled = false/auth-enabled = true/" /etc/influxdb/influxdb.conf

echo "Starting influxdb"
sudo systemctl start influxdb

echo "Installing Grafana"
wget https://dl.grafana.com/oss/release/grafana-6.1.6-1.x86_64.rpm
sudo yum localinstall -y grafana-6.1.6-1.x86_64.rpm

echo "Configuring Grafana"
sudo sed -i "s/;admin_password =.*/admin_password = $3/" /etc/grafana/grafana.ini
sudo sed -i "s/;enable_gzip = .*/enable_gzip = true/" /etc/grafana/grafana.ini
sudo sed -i "s/;allow_sign_up = .*/allow_sign_up = false/" /etc/grafana/grafana.ini

echo "Starting Grafana"
sudo /bin/systemctl daemon-reload
sudo /bin/systemctl enable grafana-server
sudo /bin/systemctl start grafana-server
sleep 3
systemctl is-active --quiet grafana-server || (echo "Grafana could not be started" && exit 2)

echo "Done."
