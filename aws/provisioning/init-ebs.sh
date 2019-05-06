#!/bin/bash

if sudo file -s /dev/xvdh | grep ": data"
then
  echo "Uninitialized volume found, creating file system"
  sudo mkfs -t xfs /dev/xvdh
fi

echo "Creating mount point and mounting volume"
sudo mkdir /mnt/influx
sudo mount /dev/xvdh /mnt/influx
