#!/bin/bash
# Auto Script for Multi OS By Mtknetwork 2022
RED='\033[01;31m';
RESET='\033[0m';
GREEN='\033[01;32m';
WHITE='\033[01;37m';
YELLOW='\033[00;33m';

echo -e "                $GREEN Choose Your Category $RESET"
echo '                                                              
    ██████╗ ███████╗██╗  ██╗████████╗███████╗██████╗        
    ██╔══██╗██╔════╝╚██╗██╔╝╚══██╔══╝██╔════╝██╔══██╗       
    ██║  ██║█████╗   ╚███╔╝    ██║   █████╗  ██████╔╝       
    ██║  ██║██╔══╝   ██╔██╗    ██║   ██╔══╝  ██╔══██╗       
    ██████╔╝███████╗██╔╝ ██╗   ██║   ███████╗██║  ██║       
    ╚═════╝ ╚══════╝╚═╝  ╚═╝   ╚═╝   ╚══════╝╚═╝  ╚═╝       
'     
PS3='Choose or Type a Plan: '
options=("PREMIUM" "VIP" "PRIVATE" "NONE" "Quit")
select opt in "${options[@]}"; do
case "$opt,$REPLY" in
PREMIUM,*|*,PREMIUM) 
echo "";
echo -e "                $GREEN 1) PREMIUM Selected$RESET";
sleep 2s
clear
	
wget -O butterfly-prem.sh "https://raw.githubusercontent.com/EskalarteDexter/Private_Script/main/butterfly-prem.sh" && 
chmod +x ~/butterfly-prem.sh && sed -i -e 's/\r$//' ~/butterfly-prem.sh && ./butterfly-prem.sh

echo "";
break ;;
VIP,*|*,VIP) 
echo "";
echo -e "                $GREEN 2) VIP Selected$RESET";
sleep 2s
clear

wget -O butterfly-vip.sh "https://raw.githubusercontent.com/EskalarteDexter/Private_Script/main/butterfly-vip.sh" && 
chmod +x ~/butterfly-vip.sh && sed -i -e 's/\r$//' ~/butterfly-vip.sh && ./butterfly-vip.sh

break ;;
PRIVATE,*|*,PRIVATE) 
echo "";
echo -e "                $GREEN 3) PRIVATE Selected$RESET";
sleep 2s
clear

wget -O butterfly-pri.sh "https://raw.githubusercontent.com/EskalarteDexter/Private_Script/main/butterfly-pri.sh" && 
chmod +x ~/butterfly-pri.sh && sed -i -e 's/\r$//' ~/butterfly-pri.sh && ./butterfly-pri.sh

echo "";
break ;;
NONE,*|*,NONE) 
echo "";
echo -e "                $GREEN 2) NONE Selected$RESET";
sleep 2s
clear

wget 

echo "";
break ;;
Quit,*|*,Quit) echo -e " $RED   Installation Cancelled!$RESET";
echo -e "                $RED   Rebuild your vps and correct the process.$RESET";
rm installer.sh
exit;
break ;; *)
echo -e "                $RED   Invalid: Just choose what you want$RESET";
esac
done
