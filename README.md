# Ruuvi-collector on Raspberry Pi with InfluxDB + Grafana in AWS

This repository contains instructions and a Terraform project for setting up a Raspberry Pi with Ruuvi-collector that transmits data to an InfluxDb in AWS. Grafana is set up as the UI for viewing the RuuviTag data.

## The Raspberry Pi part

These are mainly notes to self on how to set up the Raspberry Pi to have all needed software and settings and the ruuvi-collector software running. My older version of the Raspberry Pi (Model B Rev 2 that doesn't have wifi nor Bluetooth) requires some additional setup for my dongles to work. This might not be necessary depending on your version of the Pi.

### Setup Raspbian

- Download [Raspbian Lite](https://www.raspberrypi.org/downloads/raspbian/)
- Flash it onto an SD card with [Etcher](https://etcher.io)
- Re-insert card (into Mac, will make it mount the `boot` partition)
- Set up headless SSH access
    - `cd /Volumes/boot`
    - `touch ssh`
    - Create `wpa_supplicant.conf` from [this template](raspberry-pi/wpa_supplicant.conf), change it to match your environment
- Insert card into Raspberry Pi, boot
- Check IP with `arp -a` from OS X or use `raspberrypi.local`
- Connect
    - `ssh pi@raspberrypi.local`
- To add and switch between wifi networks on the RPi
    - Add network to `/etc/wpa_supplicant/wpa_supplicant.conf`
    - `wpa_cli reconfigure`
    - `sudo iwconfig wlan0 essid FrediPhone key s:password`
    - `sudo iwconfig wlan0 essid ManegenS key s:password`
    - `sudo iwconfig wlan0 essid Skedo key s:password`
- Check wifi connection with `iwconfig`
- Check wifi signal with `cat /proc/net/wireless`

This wasn't enough for me, I had to setup the wifi dongle using Ethernet connection before being able to connect over wifi

- Set the timezone using `sudo raspi-config > Localisation Options > Change Timezone > [Select timezone]`
- Install driver for the wifi dongle
    - `ssh pi@raspberrypi.local` over Ethernet (you can connect the Pi straight to your Mac if you enable Internet sharing in the System Preferences)
    - `wget https://gist.github.com/bostrom/da1e6d26fba47aa3144a02f09c635531/raw/7e04bd3dd4d76eb21eca9f602247d757b89648da/RPi-install-wifi.sh`
    - `sudo mv RPi-install-wifi.sh /usr/bin/install-wifi`
    - `chmod 755 /usr/bin/install-wifi`
    - `sudo install-wifi`
    - `sudo reboot`

### Install Ruuvi Collector

- `ssh pi@raspberrypi.local`
- `sudo apt update`
- `sudp apt full-upgrade`
- Note: if the linux kernel was upgraded in the above process, you might need to re-install the wifi driver with `sudo install-wifi` if you had to install it manually earlier (see above)
- `sudo apt install -y git bluez bluez-hcidump maven`
- Install a JDK (Java Development Kit). For newer Pi's and Raspbians it might be `sudo apt install openjdk-11-jdk-headless`. For older ones, you might have to select an older JDK, e.g. `openjdk-8-jdk-headless`. If your `/etc/alternatives/java` is a different version than the JDK you're installing, then uninstall the other JRE with `sudo apt remove openjdk-11-jre-headless` (or whatever version is installed).
- ``sudo setcap 'cap_net_raw,cap_net_admin+eip' `which hcitool` ``
- ``sudo setcap 'cap_net_raw,cap_net_admin+eip' `which hcidump` ``
- `git clone https://github.com/Scrin/RuuviCollector.git`
- `cd RuuviCollector`
- `mvn clean package`
- Edit `ruuvi-collector.properties` and `ruuvi-names.properties`, modify to match your needs
- Create `/etc/systemd/system/ruuvi-collector.service` from [this template](raspberry-pi/ruuvi-collector.service)
- `sudo systemctl enable ruuvi-collector.service`
- `sudo systemctl start ruuvi-collector.service`
- `sudo systemctl status ruuvi-collector.service`

## Backup your Raspberry SD card

In case (or rather, when) the SD card dies or gets corrupted you don't need to go through the whole process above if you make an image of the SD card using [these instruction](https://medium.com/better-programming/backing-up-your-raspberry-pi-sd-card-on-mac-the-simple-way-398a630f899c).

Then, when you need to re-flash your SD card just use your custom image.

## The AWS part

The AWS setup is managed with Terraform. The scripts take care of everything including provisioning the Grafana datasources and dashboards.

The setup includes:
- Elastic Load Balancer accepting requests from the Internet over HTTPS
- An EC2 instance running InfluxDb and Grafana
- Security Groups for controlling open ports to ELB and EC2 instance
- An EBS volume for persisting InfluxDb data
- An SSL certificate for your domain, so you can access Grafana over HTTPS on your own subdomain (DNS not included)

### Setup

- Enter aws dir
    - `cd aws`
- Install aws-cli
    - `brew install awscli`
- Install terraform
    - `brew install terraform`
- Configure aws-cli
    - Create a key pair in your AWS console for your user
    - `aws configure`
- Setup Terraform variables
    - `cp secrets.auto.tfvars.example secrets.auto.tfvars`
    - Modify `terraform.tfvars` and `secrets.auto.tfvars` to match your needs
    - Modify `main.tf` and `backend.tf` to match your needs, if needed
- Optionally set up an [S3 backend for Terraform](https://www.terraform.io/docs/backends/types/s3.html).
    - If omitted, remove `backend.tf`
- Run
    - `terraform init`
    - `terraform plan`
    - `terraform apply`

This might hang on the SSL Certificate creation since it waits for it to become verified. To continue, add the verification records to your DNS and wait for the certificate to become verified (see below, and check the AWS console for this). Then re-run `terraform apply`.

The Terraform outputs the EC2 instance's IP address (for SSH connections) and the ELB domain name where Grafana will be accessible (and InfluxDb on port 8086).

## The DNS part

I'm using my own domain name configured in Namecheap, so to get the custom domain name working, I had to do this in the Namecheap admin panel:

- Add a CNAME to the DNS configuration for verifying the AWS certificate (instructions in the AWS console when Terraform has created it)
- Add a CNAME which points to the ELB DNS name for the chosen subdomain (displayed as output from the Terraform script)


## References
- [https://blog.ruuvi.com/rpi-gateway-6e4a5b676510](https://blog.ruuvi.com/rpi-gateway-6e4a5b676510)
- [https://github.com/Scrin/RuuviCollector](https://github.com/Scrin/RuuviCollector)
- [https://medium.com/@ville.alatalo/oma-s%C3%A4%C3%A4asema-ruuvitagilla-ja-grafanalla-25c823f20a20](https://medium.com/@ville.alatalo/oma-s%C3%A4%C3%A4asema-ruuvitagilla-ja-grafanalla-25c823f20a20) (In Finnish)
- [https://medium.com/brightergy-engineering/install-and-configure-influxdb-on-amazon-linux-b0c82b38ba2c](https://medium.com/brightergy-engineering/install-and-configure-influxdb-on-amazon-linux-b0c82b38ba2c)
- [https://grem11n.github.io/blog/2017/03/11/terraform-for-instances-with-ebs/](https://grem11n.github.io/blog/2017/03/11/terraform-for-instances-with-ebs/)
