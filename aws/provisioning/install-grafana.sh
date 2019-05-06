#!/bin/bash

echo "Installing Grafana"
wget https://dl.grafana.com/oss/release/grafana-6.1.6-1.x86_64.rpm
sudo yum localinstall -y grafana-6.1.6-1.x86_64.rpm

echo "Configuring Grafana"
sudo sed -i "s/;admin_password =.*/admin_password = $1/" /etc/grafana/grafana.ini
sudo sed -i "s/;enable_gzip = .*/enable_gzip = true/" /etc/grafana/grafana.ini
sudo sed -i "s/;allow_sign_up = .*/allow_sign_up = false/" /etc/grafana/grafana.ini

echo "Provisioning Grafana"
sudo cp /tmp/provisioning/grafana-datasource.yaml /etc/grafana/provisioning/datasources/datasource.yaml
sudo cp /tmp/provisioning/grafana-dashboards.yaml /etc/grafana/provisioning/dashboards/dashboards.yaml
# the password in $2 can contain a slash that would terminate the sed command
# so we use parameter expansion and escape all slashes in the password
sudo sed -i "s/INFLUX_PASSWORD/${2//\//\\/}/" /etc/grafana/provisioning/datasources/datasource.yaml

echo "Starting Grafana"
sudo /bin/systemctl daemon-reload
sudo /bin/systemctl enable grafana-server
sudo /bin/systemctl start grafana-server
sleep 3
systemctl is-active --quiet grafana-server || (echo "Grafana could not be started" && exit 2)

echo "Done."

