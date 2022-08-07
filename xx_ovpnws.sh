#!/bin/bash
cp /usr/share/zoneinfo/Asia/Riyadh /etc/localtime

install_require()
{
  clear
  echo "Updating your system."
  {
    apt-get -o Acquire::ForceIPv4=true update
  } &>/dev/null
  clear
  echo "Installing dependencies."
  {
    apt-get -o Acquire::ForceIPv4=true install mysql-client -y
    apt-get -o Acquire::ForceIPv4=true install mariadb-server stunnel4 openvpn -y
    apt-get -o Acquire::ForceIPv4=true install dos2unix easy-rsa nano curl unzip jq virt-what net-tools -y
    apt-get -o Acquire::ForceIPv4=true install php-cli net-tools cron php-fpm php-json php-pdo php-zip php-gd  php-mbstring php-curl php-xml php-bcmath php-json -y
    apt-get -o Acquire::ForceIPv4=true install gnutls-bin pwgen python -y
  } &>/dev/null
}

install_squid()
{
clear
echo "Installing proxy."
{
sudo touch /etc/apt/sources.list.d/trusty_sources.list
echo "deb http://us.archive.ubuntu.com/ubuntu/ trusty main universe" | sudo tee --append /etc/apt/sources.list.d/trusty_sources.list > /dev/null
sudo apt update -y

sudo apt install -y squid3=3.3.8-1ubuntu6 squid=3.3.8-1ubuntu6 squid3-common=3.3.8-1ubuntu6
/bin/cat <<"EOM" >/etc/init.d/squid3
#! /bin/sh
#
# squid		Startup script for the SQUID HTTP proxy-cache.
#
# Version:	@(#)squid.rc  1.0  07-Jul-2006  luigi@debian.org
#
### BEGIN INIT INFO
# Provides:          squid
# Required-Start:    $network $remote_fs $syslog
# Required-Stop:     $network $remote_fs $syslog
# Should-Start:      $named
# Should-Stop:       $named
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Squid HTTP Proxy version 3.x
### END INIT INFO

NAME=squid3
DESC="Squid HTTP Proxy"
DAEMON=/usr/sbin/squid3
PIDFILE=/var/run/$NAME.pid
CONFIG=/etc/squid3/squid.conf
SQUID_ARGS="-YC -f $CONFIG"

[ ! -f /etc/default/squid ] || . /etc/default/squid

. /lib/lsb/init-functions

PATH=/bin:/usr/bin:/sbin:/usr/sbin

[ -x $DAEMON ] || exit 0

ulimit -n 65535

find_cache_dir () {
	w=" 	" # space tab
        res=`$DAEMON -k parse -f $CONFIG 2>&1 |
		grep "Processing:" |
		sed s/.*Processing:\ // |
		sed -ne '
			s/^['"$w"']*'$1'['"$w"']\+[^'"$w"']\+['"$w"']\+\([^'"$w"']\+\).*$/\1/p;
			t end;
			d;
			:end q'`
        [ -n "$res" ] || res=$2
        echo "$res"
}

grepconf () {
	w=" 	" # space tab
        res=`$DAEMON -k parse -f $CONFIG 2>&1 |
		grep "Processing:" |
		sed s/.*Processing:\ // |
		sed -ne '
			s/^['"$w"']*'$1'['"$w"']\+\([^'"$w"']\+\).*$/\1/p;
			t end;
			d;
			:end q'`
	[ -n "$res" ] || res=$2
	echo "$res"
}

create_run_dir () {
	run_dir=/var/run/squid3
	usr=`grepconf cache_effective_user proxy`
	grp=`grepconf cache_effective_group proxy`

	if [ "$(dpkg-statoverride --list $run_dir)" = "" ] &&
	   [ ! -e $run_dir ] ; then
		mkdir -p $run_dir
	  	chown $usr:$grp $run_dir
		[ -x /sbin/restorecon ] && restorecon $run_dir
	fi
}

start () {
	cache_dir=`find_cache_dir cache_dir`
	cache_type=`grepconf cache_dir`
	run_dir=/var/run/squid3

	#
	# Create run dir (needed for several workers on SMP)
	#
	create_run_dir

	#
	# Create spool dirs if they don't exist.
	#
	if test -d "$cache_dir" -a ! -d "$cache_dir/00"
	then
		log_warning_msg "Creating $DESC cache structure"
		$DAEMON -z -f $CONFIG
		[ -x /sbin/restorecon ] && restorecon -R $cache_dir
	fi

	umask 027
	ulimit -n 65535
	cd $run_dir
	start-stop-daemon --quiet --start \
		--pidfile $PIDFILE \
		--exec $DAEMON -- $SQUID_ARGS < /dev/null
	return $?
}

stop () {
	PID=`cat $PIDFILE 2>/dev/null`
	start-stop-daemon --stop --quiet --pidfile $PIDFILE --exec $DAEMON
	#
	#	Now we have to wait until squid has _really_ stopped.
	#
	sleep 2
	if test -n "$PID" && kill -0 $PID 2>/dev/null
	then
		log_action_begin_msg " Waiting"
		cnt=0
		while kill -0 $PID 2>/dev/null
		do
			cnt=`expr $cnt + 1`
			if [ $cnt -gt 24 ]
			then
				log_action_end_msg 1
				return 1
			fi
			sleep 5
			log_action_cont_msg ""
		done
		log_action_end_msg 0
		return 0
	else
		return 0
	fi
}

cfg_pidfile=`grepconf pid_filename`
if test "${cfg_pidfile:-none}" != "none" -a "$cfg_pidfile" != "$PIDFILE"
then
	log_warning_msg "squid.conf pid_filename overrides init script"
	PIDFILE="$cfg_pidfile"
fi

case "$1" in
    start)
	res=`$DAEMON -k parse -f $CONFIG 2>&1 | grep -o "FATAL: .*"`
	if test -n "$res";
	then
		log_failure_msg "$res"
		exit 3
	else
		log_daemon_msg "Starting $DESC" "$NAME"
		if start ; then
			log_end_msg $?
		else
			log_end_msg $?
		fi
	fi
	;;
    stop)
	log_daemon_msg "Stopping $DESC" "$NAME"
	if stop ; then
		log_end_msg $?
	else
		log_end_msg $?
	fi
	;;
    reload|force-reload)
	res=`$DAEMON -k parse -f $CONFIG 2>&1 | grep -o "FATAL: .*"`
	if test -n "$res";
	then
		log_failure_msg "$res"
		exit 3
	else
		log_action_msg "Reloading $DESC configuration files"
	  	start-stop-daemon --stop --signal 1 \
			--pidfile $PIDFILE --quiet --exec $DAEMON
		log_action_end_msg 0
	fi
	;;
    restart)
	res=`$DAEMON -k parse -f $CONFIG 2>&1 | grep -o "FATAL: .*"`
	if test -n "$res";
	then
		log_failure_msg "$res"
		exit 3
	else
		log_daemon_msg "Restarting $DESC" "$NAME"
		stop
		if start ; then
			log_end_msg $?
		else
			log_end_msg $?
		fi
	fi
	;;
    status)
	status_of_proc -p $PIDFILE $DAEMON $NAME && exit 0 || exit 3
	;;
    *)
	echo "Usage: /etc/init.d/$NAME {start|stop|reload|force-reload|restart|status}"
	exit 3
	;;
esac

exit 0
EOM

sudo chmod +x /etc/init.d/squid3
sudo update-rc.d squid3 defaults

echo "acl SSH dst $(curl -s https://api.ipify.org)
acl SSL_ports port 443
acl Safe_ports port 80
acl Safe_ports port 21
acl Safe_ports port 443
acl Safe_ports port 70
acl Safe_ports port 210
acl Safe_ports port 1025-65535
acl Safe_ports port 280
acl Safe_ports port 488
acl Safe_ports port 591
acl Safe_ports port 777
acl CONNECT method CONNECT
http_access allow SSH
http_access deny manager
http_access deny all
http_port 8080
http_port 3128
coredump_dir /var/spool/squid3
refresh_pattern ^ftp: 1440 20% 10080
refresh_pattern ^gopher: 1440 0% 1440
refresh_pattern -i (/cgi-bin/|\?) 0 0% 0
refresh_pattern . 0 20% 4320
visible_hostname Firenet-Proxy
error_directory /usr/share/squid3/errors/English"| sudo tee /etc/squid3/squid.conf
sudo service squid3 restart
} &>/dev/null
}

install_openvpn()
{
clear
echo "Installing openvpn."
{
mkdir -p /etc/openvpn/easy-rsa/keys
mkdir -p /etc/openvpn/login
mkdir -p /etc/openvpn/server
mkdir -p /var/www/html/stat
touch /etc/openvpn/server.conf
touch /etc/openvpn/server2.conf

echo 'DNS=1.1.1.1
DNSStubListener=no' >> /etc/systemd/resolved.conf
sudo ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf

echo '# Openvpn Configuration by Firenet Philippines :)
dev tun
port 53
proto udp
topology subnet
server 10.30.0.0 255.255.252.0
ca /etc/openvpn/easy-rsa/keys/ca.crt 
cert /etc/openvpn/easy-rsa/keys/server.crt 
key /etc/openvpn/easy-rsa/keys/server.key 
dh none
tls-server
tls-version-min 1.2
tls-cipher TLS-ECDHE-RSA-WITH-AES-128-GCM-SHA256
cipher none
ncp-disable
auth none
sndbuf 0
rcvbuf 0
keepalive 10 120
persist-key
persist-tun
ping-timer-rem
reneg-sec 0
user nobody
group nogroup
client-to-client
username-as-common-name
verify-client-cert none
client-cert-not-required
script-security 3
max-clients 1024
client-connect /etc/openvpn/login/connect.sh
client-disconnect /etc/openvpn/login/disconnect.sh
ifconfig-pool-persist /etc/openvpn/server/ip_udp.txt
auth-user-pass-verify "/etc/openvpn/login/auth_vpn" via-env # 
push "persist-key"
push "persist-tun"
push "dhcp-option DNS 8.8.8.8"
push "redirect-gateway def1 bypass-dhcp"
push "sndbuf 0"
push "rcvbuf 0"
log /etc/openvpn/server/udpserver.log
status /etc/openvpn/server/udpclient.log
verb 3' > /etc/openvpn/server.conf

echo '# Openvpn Configuration by Firenet Philippines :)
tls-server 
port 1194
proto tcp 
duplicate-cn
dev tun
keepalive 1 180
resolv-retry infinite 
max-clients 1000
ca /etc/openvpn/easy-rsa/keys/ca.crt 
cert /etc/openvpn/easy-rsa/keys/server.crt 
key /etc/openvpn/easy-rsa/keys/server.key 
dh /etc/openvpn/easy-rsa/keys/dh2048.pem 
client-cert-not-required 
username-as-common-name 
auth-user-pass-verify "/etc/openvpn/login/auth_vpn" via-file # 
tmp-dir "/etc/openvpn/" # 
server 172.20.0.0 255.255.0.0
push "redirect-gateway def1" 
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"
push "sndbuf 393216"
push "rcvbuf 393216"
tun-mtu 1400 
mssfix 1360
verb 3
script-security 2
cipher AES-128-CBC
tcp-nodelay
up /etc/openvpn/update-resolv-conf                                                                                      
down /etc/openvpn/update-resolv-conf
client-connect /etc/openvpn/login/connect.sh
client-disconnect /etc/openvpn/login/disconnect.sh
log server_log
status /var/www/html/stat/tcpstatus.txt
ifconfig-pool-persist /var/www/html/stat/ipp.txt' > /etc/openvpn/server.conf

cat <<\EOM >/etc/openvpn/login/config.sh
#!/bin/bash
HOST='162.250.124.218'
USER='mediatek_bdvpn'
PASS='F1005r90@'
DB='mediatek_bdvpn'

EOM




/bin/cat <<"EOM" >/etc/openvpn/login/auth_vpn
#!/bin/bash
username=`head -n1 $1 | tail -1`   
password=`head -n2 $1 | tail -1`

HOST='162.250.124.218'
USER='mediatek_bdvpn'
PASS='F1005r90@'
DB='mediatek_bdvpn'

Query="SELECT user_name FROM users WHERE user_name='$username' AND user_encryptedPass=md5('$password') AND is_freeze='0' AND user_duration > 0"
user_name=`mysql -u $USER -p$PASS -D $DB -h $HOST -sN -e "$Query"`
[ "$user_name" != '' ] && [ "$user_name" = "$username" ] && echo "user : $username" && echo 'authentication ok.' && exit 0 || echo 'authentication failed.'; exit 1
EOM

#client-connect file
cat <<'LENZ05' >/etc/openvpn/login/connect.sh
#!/bin/bash

tm="$(date +%s)"
dt="$(date +'%Y-%m-%d %H:%M:%S')"
timestamp="$(date +'%FT%TZ')"

. /etc/openvpn/login/config.sh

##set status online to user connected
mysql -u $USER -p$PASS -D $DB -h $HOST -e "UPDATE users SET is_active='1' AND device_connected='1' WHERE user_name='$common_name' "
LENZ05

#TCP client-disconnect file
cat <<'LENZ06' >/etc/openvpn/login/disconnect.sh
#!/bin/bash
tm="$(date +%s)"
dt="$(date +'%Y-%m-%d %H:%M:%S')"
timestamp="$(date +'%FT%TZ')"

. /etc/openvpn/login/config.sh

mysql -u $USER -p$PASS -D $DB -h $HOST -e "UPDATE users SET is_active='0' WHERE user_name='$common_name' "
LENZ06
cat << EOF > /etc/openvpn/easy-rsa/keys/ca.crt
-----BEGIN CERTIFICATE-----
MIIExDCCA6ygAwIBAgIJAKyvksf/QCcwMA0GCSqGSIb3DQEBCwUAMIGcMQswCQYD
VQQGEwJVUzELMAkGA1UECBMCUEgxEDAOBgNVBAcTB01heW5pbGExDjAMBgNVBAoT
BVRvbmRvMRQwEgYDVQQLEwtQaW5veUdyb3VuZDERMA8GA1UEAxMIVG9uZG8gQ0Ex
DzANBgNVBCkTBnNlcnZlcjEkMCIGCSqGSIb3DQEJARYVcGlub3lncm91bmRAZ21h
aWwuY29tMB4XDTE3MDYxNzEwMjMxM1oXDTI3MDYxNTEwMjMxM1owgZwxCzAJBgNV
BAYTAlVTMQswCQYDVQQIEwJQSDEQMA4GA1UEBxMHTWF5bmlsYTEOMAwGA1UEChMF
VG9uZG8xFDASBgNVBAsTC1Bpbm95R3JvdW5kMREwDwYDVQQDEwhUb25kbyBDQTEP
MA0GA1UEKRMGc2VydmVyMSQwIgYJKoZIhvcNAQkBFhVwaW5veWdyb3VuZEBnbWFp
bC5jb20wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCrfMyxOcaPROlq
TOrRfwixx/5vMdSyDh1b9j9zE/BDaWF1UtkZORXjI5YCdQNsk+86qHxVamZmC6jm
Tq5sC0XrZr725/qFANvj13rw7Bt3q+/Q5lCt5zwpuaSOem6YIlvqzBYbteShEaX8
h7ppL+bk6i+S9MOX5bc+m8zt0DwrLbC6tqBvC+1Btj8kvnhtoXI+uQoUxRa6PbsK
DcdW1iyjcjG+ARWKEXMSOjxL3RtWfoG6sRL4mkALNH/ghejvtXjYYeU3hUDyWGGy
QWux3WzreVYnoXyozEijwGPCCLdZ+Sdn8F4D7yXoPKsLxfqFvtt76zFVajNpszsX
cKbiBB5JAgMBAAGjggEFMIIBATAdBgNVHQ4EFgQUAvGhH/Tis+YRCGKQLUKaMcCE
hsgwgdEGA1UdIwSByTCBxoAUAvGhH/Tis+YRCGKQLUKaMcCEhsihgaKkgZ8wgZwx
CzAJBgNVBAYTAlVTMQswCQYDVQQIEwJQSDEQMA4GA1UEBxMHTWF5bmlsYTEOMAwG
A1UEChMFVG9uZG8xFDASBgNVBAsTC1Bpbm95R3JvdW5kMREwDwYDVQQDEwhUb25k
byBDQTEPMA0GA1UEKRMGc2VydmVyMSQwIgYJKoZIhvcNAQkBFhVwaW5veWdyb3Vu
ZEBnbWFpbC5jb22CCQCsr5LH/0AnMDAMBgNVHRMEBTADAQH/MA0GCSqGSIb3DQEB
CwUAA4IBAQCa5JUgtw6j3poZEug6cV9Z/ndYqxvYkoOLNCaMG1xZYBch061qjqB1
8TvAqBpp4zF6w0i4P4Mwh1p+bUgOV04p7HB6aUMm14ALwn+hHhWlkVQ5bPqVEr9B
L8/xjcbBVGj1lgv6UCjzmx1Aq+VBlvy0wU1NQT3QuQXSIpEvGMAn3ApsNMmQQ8CW
hYWYMFbAcjF9vWi+FKoDtWQ6SyHvgcpkOuqWs4p9AEwI6WS1IpJPRiHIPYwAzA3u
824ER9Gn4OKoBLqVyhQvW3etMjMc/baWd6p0K06NSCwZsjchD+ayf5SjfUfhYTTM
llJ5x8d1nZT7CWpogTTvqDdK6iiKPb/+
-----END CERTIFICATE-----
EOF

cat << EOF > /etc/openvpn/easy-rsa/keys/server.crt
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number: 1 (0x1)
    Signature Algorithm: sha256WithRSAEncryption
        Issuer: C=US, ST=PH, L=Maynila, O=Tondo, OU=PinoyGround, CN=Tondo CA/name=server/emailAddress=pinoyground@gmail.com
        Validity
            Not Before: Jun 17 10:23:30 2017 GMT
            Not After : Jun 15 10:23:30 2027 GMT
        Subject: C=US, ST=PH, L=Maynila, O=Tondo, OU=PinoyGround, CN=server/name=server/emailAddress=pinoyground@gmail.com
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                Public-Key: (2048 bit)
                Modulus:
                    00:e2:78:00:40:ca:de:85:d3:2d:63:54:cc:3c:49:
                    72:98:a9:76:bd:1b:62:95:aa:36:1f:eb:b6:86:4b:
                    da:a9:c0:50:7b:c0:bf:3f:6f:d4:38:32:b9:ad:33:
                    b8:13:fb:6b:b8:41:c1:98:05:ac:3e:49:64:3e:1b:
                    9f:8f:07:b8:b5:b6:7c:86:59:be:a3:93:31:8c:b7:
                    77:b8:50:a4:b1:19:3b:34:a9:21:4a:a6:25:83:48:
                    60:cb:0d:1f:13:5b:d5:af:eb:2a:1d:55:41:8d:76:
                    c5:05:0d:98:7a:9a:f8:22:58:4c:11:01:99:e3:b3:
                    40:0a:9d:4c:cc:8b:1e:86:bf:9b:63:26:61:19:86:
                    5a:88:a9:99:93:66:0e:74:82:31:83:b3:7f:cc:cd:
                    57:03:e5:5b:ce:3c:97:5d:c8:62:c8:e8:94:d8:5a:
                    e9:a8:3b:be:ba:a6:b0:85:59:e4:10:d3:a2:c4:d3:
                    4d:fb:8f:a9:6e:98:bb:b6:69:9d:63:c4:01:df:46:
                    1a:5d:d2:26:b7:0f:3d:74:22:fe:bb:16:75:28:43:
                    ec:9c:e5:ad:d4:b6:af:42:eb:26:76:c6:83:29:b9:
                    d0:50:44:cd:f1:d1:0f:68:7b:2d:8c:86:7f:24:fc:
                    8f:4d:05:6e:47:8b:7c:c0:04:e1:e8:c9:97:4c:bb:
                    fe:a7
                Exponent: 65537 (0x10001)
        X509v3 extensions:
            X509v3 Basic Constraints: 
                CA:FALSE
            Netscape Cert Type: 
                SSL Server
            Netscape Comment: 
                Easy-RSA Generated Server Certificate
            X509v3 Subject Key Identifier: 
                E0:C5:67:F2:F7:5D:B4:65:B8:71:0A:5D:58:C0:16:B5:09:D9:73:B7
            X509v3 Authority Key Identifier: 
                keyid:02:F1:A1:1F:F4:E2:B3:E6:11:08:62:90:2D:42:9A:31:C0:84:86:C8
                DirName:/C=US/ST=PH/L=Maynila/O=Tondo/OU=PinoyGround/CN=Tondo CA/name=server/emailAddress=pinoyground@gmail.com
                serial:AC:AF:92:C7:FF:40:27:30

            X509v3 Extended Key Usage: 
                TLS Web Server Authentication
            X509v3 Key Usage: 
                Digital Signature, Key Encipherment
            X509v3 Subject Alternative Name: 
                DNS:server
    Signature Algorithm: sha256WithRSAEncryption
         3b:19:a5:22:34:0e:7b:51:12:8d:37:6e:10:19:58:d8:a1:3b:
         a2:c5:f8:62:3b:37:1d:06:5a:f3:a6:35:bd:0f:22:61:7d:e2:
         f3:54:00:a5:7b:9c:a7:e2:3b:e0:6f:35:a0:1d:23:02:c7:f0:
         2b:8a:b0:51:24:2d:87:b6:5d:ce:81:4a:f2:32:dd:42:a4:b5:
         f0:4d:1e:ac:5f:36:52:c9:c0:ba:1f:c7:3c:6a:f2:88:e1:14:
         1b:84:e7:53:84:ee:88:15:39:10:24:bc:8d:64:ca:65:75:55:
         0d:7d:09:dd:a3:d2:94:2b:d5:7e:46:72:70:91:69:02:a6:79:
         58:a1:4f:1b:18:c0:9a:4b:96:16:b2:70:a5:cd:bb:bf:33:b5:
         1a:76:51:93:8a:ca:4b:45:50:be:52:bd:28:cf:94:7e:d9:84:
         6c:93:43:b3:d0:2f:a5:3e:32:bd:0d:46:8a:d1:46:2d:64:f0:
         50:2f:c6:7d:54:54:88:3f:f5:02:17:71:6f:1c:4b:cd:2c:d4:
         c0:fc:39:15:bc:46:62:36:eb:d0:fe:fc:c2:c1:f5:fb:18:6f:
         7c:91:61:0e:2c:e1:17:08:44:9f:66:e4:d5:99:30:bf:f5:0a:
         96:b6:1e:8f:ea:c6:bb:6b:b4:0c:82:ef:ef:85:6e:74:94:c2:
         0c:2b:94:de
-----BEGIN CERTIFICATE-----
MIIFNTCCBB2gAwIBAgIBATANBgkqhkiG9w0BAQsFADCBnDELMAkGA1UEBhMCVVMx
CzAJBgNVBAgTAlBIMRAwDgYDVQQHEwdNYXluaWxhMQ4wDAYDVQQKEwVUb25kbzEU
MBIGA1UECxMLUGlub3lHcm91bmQxETAPBgNVBAMTCFRvbmRvIENBMQ8wDQYDVQQp
EwZzZXJ2ZXIxJDAiBgkqhkiG9w0BCQEWFXBpbm95Z3JvdW5kQGdtYWlsLmNvbTAe
Fw0xNzA2MTcxMDIzMzBaFw0yNzA2MTUxMDIzMzBaMIGaMQswCQYDVQQGEwJVUzEL
MAkGA1UECBMCUEgxEDAOBgNVBAcTB01heW5pbGExDjAMBgNVBAoTBVRvbmRvMRQw
EgYDVQQLEwtQaW5veUdyb3VuZDEPMA0GA1UEAxMGc2VydmVyMQ8wDQYDVQQpEwZz
ZXJ2ZXIxJDAiBgkqhkiG9w0BCQEWFXBpbm95Z3JvdW5kQGdtYWlsLmNvbTCCASIw
DQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAOJ4AEDK3oXTLWNUzDxJcpipdr0b
YpWqNh/rtoZL2qnAUHvAvz9v1Dgyua0zuBP7a7hBwZgFrD5JZD4bn48HuLW2fIZZ
vqOTMYy3d7hQpLEZOzSpIUqmJYNIYMsNHxNb1a/rKh1VQY12xQUNmHqa+CJYTBEB
meOzQAqdTMyLHoa/m2MmYRmGWoipmZNmDnSCMYOzf8zNVwPlW848l13IYsjolNha
6ag7vrqmsIVZ5BDTosTTTfuPqW6Yu7ZpnWPEAd9GGl3SJrcPPXQi/rsWdShD7Jzl
rdS2r0LrJnbGgym50FBEzfHRD2h7LYyGfyT8j00FbkeLfMAE4ejJl0y7/qcCAwEA
AaOCAYAwggF8MAkGA1UdEwQCMAAwEQYJYIZIAYb4QgEBBAQDAgZAMDQGCWCGSAGG
+EIBDQQnFiVFYXN5LVJTQSBHZW5lcmF0ZWQgU2VydmVyIENlcnRpZmljYXRlMB0G
A1UdDgQWBBTgxWfy9120ZbhxCl1YwBa1CdlztzCB0QYDVR0jBIHJMIHGgBQC8aEf
9OKz5hEIYpAtQpoxwISGyKGBoqSBnzCBnDELMAkGA1UEBhMCVVMxCzAJBgNVBAgT
AlBIMRAwDgYDVQQHEwdNYXluaWxhMQ4wDAYDVQQKEwVUb25kbzEUMBIGA1UECxML
UGlub3lHcm91bmQxETAPBgNVBAMTCFRvbmRvIENBMQ8wDQYDVQQpEwZzZXJ2ZXIx
JDAiBgkqhkiG9w0BCQEWFXBpbm95Z3JvdW5kQGdtYWlsLmNvbYIJAKyvksf/QCcw
MBMGA1UdJQQMMAoGCCsGAQUFBwMBMAsGA1UdDwQEAwIFoDARBgNVHREECjAIggZz
ZXJ2ZXIwDQYJKoZIhvcNAQELBQADggEBADsZpSI0DntREo03bhAZWNihO6LF+GI7
Nx0GWvOmNb0PImF94vNUAKV7nKfiO+BvNaAdIwLH8CuKsFEkLYe2Xc6BSvIy3UKk
tfBNHqxfNlLJwLofxzxq8ojhFBuE51OE7ogVORAkvI1kymV1VQ19Cd2j0pQr1X5G
cnCRaQKmeVihTxsYwJpLlhaycKXNu78ztRp2UZOKyktFUL5SvSjPlH7ZhGyTQ7PQ
L6U+Mr0NRorRRi1k8FAvxn1UVIg/9QIXcW8cS80s1MD8ORW8RmI269D+/MLB9fsY
b3yRYQ4s4RcIRJ9m5NWZML/1Cpa2Ho/qxrtrtAyC7++FbnSUwgwrlN4=
-----END CERTIFICATE-----
EOF

cat << EOF > /etc/openvpn/easy-rsa/keys/server.key
-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDieABAyt6F0y1j
VMw8SXKYqXa9G2KVqjYf67aGS9qpwFB7wL8/b9Q4MrmtM7gT+2u4QcGYBaw+SWQ+
G5+PB7i1tnyGWb6jkzGMt3e4UKSxGTs0qSFKpiWDSGDLDR8TW9Wv6yodVUGNdsUF
DZh6mvgiWEwRAZnjs0AKnUzMix6Gv5tjJmEZhlqIqZmTZg50gjGDs3/MzVcD5VvO
PJddyGLI6JTYWumoO766prCFWeQQ06LE0037j6lumLu2aZ1jxAHfRhpd0ia3Dz10
Iv67FnUoQ+yc5a3Utq9C6yZ2xoMpudBQRM3x0Q9oey2Mhn8k/I9NBW5Hi3zABOHo
yZdMu/6nAgMBAAECggEAH9fduT6NQWXrKN9ghE2ThnG1l2uFViQDzkM3e/Sof1vi
NTRp78KKpYhEYV03Ud/1Sog8b2LE0FFDfhQmQFdGmo5ZPg7aZmeo/O9DLzBvp9Mz
ZvktDDEGb0o7CfIDX5Z3GnBHkK5PNFPx6f76ZKrrnvCpaW6/M6wdoiByDwS0ux9s
Pr8ALFFKPgYwc5QNt/R0iFOYqQfSA3UrzdOolklbfQRB9+n5kBqQ69PlKd+JwhGy
tO07DysEmNGlMQoNw7pm6nDVwYO+KdmFcj23jTgcgsmvdqh6ucreFYWYn9pf6wGo
0HJ9E7J2BRXdfgZ26WdDicPONFCmuQBvsCnW+pVGiQKBgQD3Dv8W17ZtAZTwP1m3
uNRn2mYcI4+0MufXwaT3yqQ2G8NY5kTvEeqAO/+LubzOC231FAU+359YQHK/f1X0
NpmiGfOtu4iQxjGujBr1PndIIhJZAJYgbr9F6rMnRpcVfhTZO5e/5nr92mksMrK2
zzZLw0QObLw0nJqnL1hrmBBH0wKBgQDqqj1EVLfTizxf8BtN7SbQqwyFgirpGBOC
zJKORNQsDgYs949sWOsQz+q09NIhOkd1jlvE7GA5g/v6+UkWuN7ZGAhFnre3u9Aa
pn3xyqO9Sur6h2S17EUlRVYww7OITTquSsjZT6l5cKA6FRIuEm3PuBypuHLo3CAB
+rZXSDUdXQKBgQDbAvdNV6LHVTykEXTGMlpRSkF0tm2g7/Oox2gnpgMWWFw/Bbqc
OESqswVh5yChg25RcRMJXpHSWSef7RDUckaVde4X2ARDWv8V3evT9jElx9Z+AdAU
Jjj3kQyKR8CNc/ylanemzXnAagsL/FGDT4OxfANryia5eQ58ILOAhggAswKBgBEx
vB9/naCQeTIGY9nH4Ko1fktiCEbgDr3sw2hNPsajmGw/D3E+6qpmsankrmjk3kuM
zMiXEU3lj9cJ4QMbNKjvi9ueD5QU3OC3Bk9rK6g5DxKgTQ7PaxmaBQC5tjPshLo0
nJbfsWlGiVb4KEbb7tPjh6Yf77uENYwvlKC8l7e5AoGANeITeKJPjrzvHjx27Zdf
8brrZV1zbQZoeOWR6qj/0XSufNOnGK5KJXjNE8zKovmGoZjjspnQBzoTN5uJ1IoM
QpNYIm3S1oSDImrrNeRjIaUrVo3FAfu4vf3eKNqHLe9kUSriLU5DSu/Wfep3fFn1
nkd5vWo7A6vkZX/Iu6MzKDE=
-----END PRIVATE KEY-----
EOF

cat << EOF > /etc/openvpn/easy-rsa/keys/dh2048.pem
-----BEGIN DH PARAMETERS-----
MIIBCAKCAQEAohzwXz9fsjw+G9Q14qINNOhZnTt/b30zzJYm4o2NIzAngM6E6GPm
N5USUt0grZw6h3VP9LyqQoGi/bHFz33YFG5lgDF8FAASEh07/leF7s0ohhK8pspC
JVD+mRatwBrIImXUpJvYI2pXKxtCOnDa2FFjAOHKixiAXqVcmJRwNaSklQcrpXdn
/09cr0rbFoovn+f1agly4FxYYs7P0XkvSHm3gVW/mhAUr1hvZlbBaWFSVUdgcVOi
FXQ/AVkvxYaO8pFI2Vh+CNMk7Vvi8d3DTayvoL2HTgFi+OIEbiiE/Nzryu+jDGc7
79FkBHWOa/7eD2nFrHScUJcwWiSevPQjQwIBAg==
-----END DH PARAMETERS-----
EOF

chmod 755 /etc/openvpn/server.conf
chmod 755 /etc/openvpn/server2.conf
chmod 755 /etc/openvpn/login/connect.sh
chmod 755 /etc/openvpn/login/disconnect.sh
chmod 755 /etc/openvpn/login/config.sh
chmod 755 /etc/openvpn/login/auth_vpn
}&>/dev/null
}

install_stunnel() {
  {
cd /etc/stunnel/

echo "-----BEGIN RSA PRIVATE KEY-----
MIIEowIBAAKCAQEAqBptpzCvwPqN1nZHVlY2du2D/MXdiALyvPJDp1G+TKW7+FUd
IZnW8udc6IVJZ2RZUtN/Edzvis0b2XXB9t3o6jR2CShn0uqmdTS14BjsNyrXBZRk
8tWDZawClIWKOkSq76UpTKVOlXhq+Uk1eoT/zB5qlgaZv5L0ye3c/n/eJUzqjOgV
Rez+5XaEyI5A4+83NxALcz10coMP4Qr4Mcp2NALPbXj4KKiIguemiaD9tgp7iQqs
GxTxWhfvMsbYL7FcJpGwWpv5GcxeCyR+L2t/67hC7dAvB5NSnLTioD1e2qu0Zcd5
dhII8wr/pgC+7Y2GjTtITnHIogx3Q2LzCjF4owIDAQABAoIBAQCNfcEx6l7kdYAR
NXkSCHrLW1uu1PSD2MdrlhavrLQaW519hlaAw7YSuf6PkDCan/I3LuFTrbzJ/Z4l
SWK7YUj8aK+5QZMyCmOVX4p+Vzvrq1lUzvSxGFoCp+d8D3KrXMTr9P5wDuu4D6Uq
sh4bQ/ryWd+o62FZyF3V4SoT5Jicl2U1O3xC20nbZJMglXzuhQRaI3ZnuG4d0zHX
Eonp7wbcoKbDFJyrtSDhdwS9vylm5oo02+pgUZ1ELXglHw1ezuHekSOhIJBVdrER
3Ch9mJ0fqGQKofD1PaIGpFviBF3YJEskiVSpAAiZ5pmwFvzWxqAnlYi59nlHSvwB
tO7n51ChAoGBANw1uwTGhnU30Xgbx0KY+3J8kGHSJZeRjhZwt4646WxDT7EkAqjg
TovR80yNf7vVqwDt07j1Q5DNo7MVGbvyXwPaMsAXiYbBppaGRDQtp6UylIv+tmDo
DhYEbwQSQtGsdADjvtiBqt2tYdFW+omB88ZCfEuS7va5wcneP/Xq2UTrAoGBAMNs
snuSAzXhJaxyE6AvYFoFJxWW0H8FPhQ5g+xS+jBNpj9SbARzn7yZFRGXy2xzmbK+
wQA3IN40upIIy8ZiTIppvi/b/O8eaQqwQzsevzENMCKNGEjsrBpQ51wwzq1ix42Y
8Fn1AMsMaitC1YymvLOvtuIA29OBQ1a1pslrUI0pAoGAGGhcMktO2+8z6HwrudX7
CNWFq1H/mK0pcpNLxSX5uWY8jwXOxakXC6hZr0J/xfII4jF6JiYJNyOT4WWVVJ+o
qGSm+2Ogeq88J7L6HE5zJnxUuq+gx1zxMr+LDoh3n4Xd1btoi9bTeX6eOPXLDzK4
MmFsJXRDyFUOhbF8pWVCb8ECgYBfYEBnoKZieGS7md1MM3MR3CvsFHPjWjqnAj8J
aqHiSzNU+jPvpEKUeB3ZPT0xy+V6YDCvmzg2WoOn3BUf2D/E2cDReMskJLJdXhMh
2mqzVN1mL3hntuJz4YJY8xUbd/cuezLqpHFjp8Z1IKQ6hfHYvGxENukSe6bSvcsN
yItCqQKBgG/nF1FTFjM97x049sP7iAlxhRxg2Yi6qthvmmFo8xBnLO66CG9PEC3G
1MYWIzB6YtJG89NFFIGog/G2Cz95JjJDLDUOO41K/z1pBnArP54jvxx+iDuZlFMB
mWorw0zwnwbBhrQ3hH+YsQ5uI9eg7RN+8ZbmoXUweeUlzpsiaMaw
-----END RSA PRIVATE KEY-----
-----BEGIN CERTIFICATE-----
MIIEHTCCAwWgAwIBAgIJAIciQafGgIDvMA0GCSqGSIb3DQEBBQUAMIGkMQswCQYD
VQQGEwJCRDEOMAwGA1UECAwFRGhha2ExDjAMBgNVBAcMBURoYWthMRgwFgYDVQQK
DA9BMlogU0VSVkVSUyBMVEQxFzAVBgNVBAsMDmEyenNlcnZlcnMuY29tMRswGQYD
VQQDDBJ3d3cuYTJ6c2VydmVycy5jb20xJTAjBgkqhkiG9w0BCQEWFnN1cHBvcnRA
YTJ6c2VydmVycy5jb20wHhcNMjAwNjI3MDQzODU5WhcNNDgwMjE2MDQzODU5WjCB
pDELMAkGA1UEBhMCQkQxDjAMBgNVBAgMBURoYWthMQ4wDAYDVQQHDAVEaGFrYTEY
MBYGA1UECgwPQTJaIFNFUlZFUlMgTFREMRcwFQYDVQQLDA5hMnpzZXJ2ZXJzLmNv
bTEbMBkGA1UEAwwSd3d3LmEyenNlcnZlcnMuY29tMSUwIwYJKoZIhvcNAQkBFhZz
dXBwb3J0QGEyenNlcnZlcnMuY29tMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIB
CgKCAQEAqBptpzCvwPqN1nZHVlY2du2D/MXdiALyvPJDp1G+TKW7+FUdIZnW8udc
6IVJZ2RZUtN/Edzvis0b2XXB9t3o6jR2CShn0uqmdTS14BjsNyrXBZRk8tWDZawC
lIWKOkSq76UpTKVOlXhq+Uk1eoT/zB5qlgaZv5L0ye3c/n/eJUzqjOgVRez+5XaE
yI5A4+83NxALcz10coMP4Qr4Mcp2NALPbXj4KKiIguemiaD9tgp7iQqsGxTxWhfv
MsbYL7FcJpGwWpv5GcxeCyR+L2t/67hC7dAvB5NSnLTioD1e2qu0Zcd5dhII8wr/
pgC+7Y2GjTtITnHIogx3Q2LzCjF4owIDAQABo1AwTjAdBgNVHQ4EFgQUgKaZRa2J
NYxKkeTXnL1NQY5ueqowHwYDVR0jBBgwFoAUgKaZRa2JNYxKkeTXnL1NQY5ueqow
DAYDVR0TBAUwAwEB/zANBgkqhkiG9w0BAQUFAAOCAQEAX0kciouCCPcK3Wq9UPUY
DrrkOD3VC469rMGZFxw9sWRO/ZYomiF391lbVJ1JYtRNQBF01YaxdSGDHYzpTfbg
OXiuMo/s97wP67yzXbmFU9pU9767jJVDKwQXzAYmK668lloRRCzv7berxNXTOm5c
xoa97gnLUiGMU4nQS2G4rAsF56ddk3WnuXxH/3hIVjSSIdq9eg4+fsDgxVnH2ehN
DLkRM+jNpiLRpm9txGOTnyFAikNGOboNSDYNx9J/uM5uoPzJDOQAoW+gV7pTut3b
I//hEv0+/RO5PEfXQkK25mpOcXgJNmxJ5UuUvm7vm5j72hzF5lT3MFYtIDwZ7Pte
+A==
-----END CERTIFICATE-----" >> stunnel.pem

echo "cert=/etc/stunnel/stunnel.pem
socket = a:SO_REUSEADDR=1
socket = l:TCP_NODELAY=1
socket = r:TCP_NODELAY=1
client = no

[openvpn]
connect = 127.0.0.1:1194
accept = 443" >> stunnel.conf

cd /etc/default && rm stunnel4

echo 'ENABLED=1
FILES="/etc/stunnel/*.conf"
OPTIONS=""
PPP_RESTART=0
RLIMITS=""' >> stunnel4 

chmod 755 stunnel4
sudo service stunnel4 restart
  } &>/dev/null
}


install_iptables(){
  {
echo -e "\033[01;31m Configure Sysctl \033[0m"
echo 'fs.file-max = 51200
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.core.netdev_max_backlog = 250000
net.core.somaxconn = 4096
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.ip_local_port_range = 10000 65000
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_max_tw_buckets = 5000
net.ipv4.tcp_mem = 25600 51200 102400
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.tcp_mtu_probing = 1
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.ipv4.ip_forward=1
net.ipv4.icmp_echo_ignore_all = 1' >> /etc/sysctl.conf
echo '* soft nofile 512000
* hard nofile 512000' >> /etc/security/limits.conf
ulimit -n 512000

iptables -t nat -A POSTROUTING -s 10.20.0.0/22 -o eth0 -j MASQUERADE
iptables -t nat -A POSTROUTING -s 10.30.0.0/22 -o eth0 -j MASQUERADE
iptables -t filter -A INPUT -p udp -m udp --dport 20100:20900 -m state --state NEW -m recent --update --seconds 30 --hitcount 10 --name DEFAULT --mask 255.255.255.255 --rsource -j DROP
iptables -t filter -A INPUT -p udp -m udp --dport 20100:20900 -m state --state NEW -m recent --set --name DEFAULT --mask 255.255.255.255 --rsource
iptables-save > /etc/iptables_rules.v4
ip6tables-save > /etc/iptables_rules.v6
sysctl -p
  }&>/dev/null
}

install_rclocal(){
  {
    wget https://pastebin.com/raw/faSsYhFf -O /etc/ubuntu
    dos2unix /etc/ubuntu
    chmod +x /etc/ubuntu    
    screen -dmS socks python /etc/ubuntu
    wget --no-check-certificate https://pastebin.com/raw/658HpnLd -O /etc/systemd/system/rc-local.service
    echo "#!/bin/sh -e
iptables-restore < /etc/iptables_rules.v4
ip6tables-restore < /etc/iptables_rules.v6
sysctl -p
service squid3 restart
service stunnel4 restart
service openvpn@server restart
service openvpn@server2 restart
screen -dmS socks python /etc/ubuntu
exit 0" >> /etc/rc.local
    sudo chmod +x /etc/rc.local
    sudo systemctl enable rc-local
    sudo systemctl start rc-local.service
  }&>/dev/null
}

install_done()
{
  clear
  echo "OPENVPN SERVER FIRENET"
  echo "IP : $(curl -s https://api.ipify.org)"
  echo "OPENVPN TCP port : 1194"
  echo "OPENVPN UDP port : 53"
  echo "OPENVPN SSL port : 442"
  echo "OPENVPN WS port : 80"
  echo "SOCKS port : 80"
  echo "PROXY port : 3128"
  echo "PROXY port : 8080"
  echo
  echo
  history -c;
  rm /root/.xx_ovpnws.sh
  echo "Server will secure this server and reboot after 5 seconds"
  sleep 5
  reboot
}

install_require
install_squid
install_openvpn
install_stunnel
install_rclocal
install_iptables
install_done
