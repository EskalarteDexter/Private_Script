wget -O notactive.sh http://script.mediatek-vpn.com/ssh/butterfly/vip/notactivevip.txt
chmod 755 notactive.sh
sh notactive.sh

wget -O active.sh http://script.mediatek-vpn.com/ssh/butterfly/vip/activevip.txt
chmod 755 active.sh
sh active.sh | tee -a /root/activate.sh