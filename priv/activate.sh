wget -O notactive.sh http://http://script.mediatek-vpn.com/ssh/priv/notactiveprivate.txt
chmod 755 notactive.sh
sh notactive.sh

wget -O active.sh http://http://script.mediatek-vpn.com/ssh/butterfly/priv/activeprivate.txt
chmod 755 active.sh
sh active.sh | tee -a /root/activate.sh