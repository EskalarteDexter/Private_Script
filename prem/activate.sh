wget -O notactive.sh https://raw.githubusercontent.com/EskalarteDexter/Private_Script/main/prem/notactivepremium.txt
chmod 755 notactive.sh
sh notactive.sh

wget -O active.sh https://raw.githubusercontent.com/EskalarteDexter/Private_Script/main/prem/activepremium.txt
chmod 755 active.sh
sh active.sh | tee -a /root/activate.sh
