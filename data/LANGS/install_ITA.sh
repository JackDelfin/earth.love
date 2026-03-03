#!/bin/bash

sudo cp -pv ITA.tgz /LOVE/earth.love/_ORBIT/MSG
cd /LOVE/earth.love/_ORBIT/MSG
sudo tar xzvf ITA.tgz
sudo chown -R www-data ITA
sudo chgrp -R www-data ITA

