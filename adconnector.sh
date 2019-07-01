#!/bin/bash  


#UUID 생성
sudo dmidecode -t 1 | grep UUID|sudo awk '{print "HamoniKR-" $2 > "/etc/uuid"}'

#변수 설정
HIZID="administrator"
HIZPW="exitem0*"
HIZDOMAIN="ivsad.invesume.com"
HIZIP="localhost"
HIZCENTERURL="http://localhost:8088/hmsvc/process"
HIZCOLLECTDIP="localhost"
HIZSGBNM=""
HIZADJOINOU="http://localhost:8088/hmsvc/getou"

#device info make Json
SERVER_API=$HIZCENTERURL
DATETIME=`date +'%Y-%m-%d %H:%M:%S'`
#UUID=`sudo dmidecode -t 1|grep UUID | awk -F ':' '{print $2}'`
UUID=`cat /etc/uuid |head -1`
CPUID=`dmidecode -t 4|grep ID`
CPUINFO=`cat /proc/cpuinfo | grep "model name" | head -1 | cut  -d" " -f3- | sed "s/^ *//g"`
#HDDID=`hdparm -I /dev/sda | grep 'Serial\ Number' |awk -F ':' '{print $2}'`
IPADDR=`ifconfig | awk '/inet .*broadcast/'|awk '{print $2}'`
MACADDR=`ifconfig | awk '/ether/'|awk '{print $2}'`
HOSTNAME=`hostname`
MEMORY=`awk '{ printf "%.2f", $2/1024/1024 ; exit}' /proc/meminfo`
HDDTMP=`fdisk -l | head -1 | awk '{print $2}'| awk -F':' '{print $1}'`
HDDID=`hdparm -I $HDDTMP  | grep 'Serial\ Number' |awk -F ':' '{print $2}'`
HDDINFO=`hdparm -I $HDDTMP  | grep 'Model\ Number' |awk -F ':' '{print $2}'`
SGBNAME='111'




# pbis leave
#sudo domainjoin-cli leave 2>error.log
#sudo apt-get purge collectd collectd-core -y 



dialog --title "Hamonize PC 관리 프로그램" --backtitle "Hamonize" --ok-label "Save" --cancel-label "Cancle" \
          --stdout --form "" 15 50 2 \
          "조직번호  " 1 1 "$HIZSGBNM" 1 15 30 0 > output.txt

retval=$?

HIZSGBNM=$(cat output.txt | head -1)
rm -fr output.txt

if [ "$retval" = "0" ]
then

	sudo apt-get install curl -y >> curlinstall.log

	RETOU=`curl  -X  POST  -f -s -d "name=$HIZSGBNM" $HIZADJOINOU` >> output.log
	echo $RETOU >> retou.log

	if [ "$RETOU" = "NOSGB" ]
	then
	    dialog --title "Hamonize Pc 관리프로그램" --backtitle "Hamonikr-ME" --msgbox  \ "[조직 이름 오류]\n 입력하신 조직명이 잘못되었습니다." 0 0
	    #clear
	    exit 
	fi


	echo percentage | dialog --gauge "text" height width percent
	echo "10" | dialog --gauge "Hamonize Pc 관리프로그램 설치중..." 10 70 0

	#PACKAGE check  & instll ###
	dpkg -l | service sshd status  >/dev/null 2>&1 || {
		sudo apt install openssh-server -y 2>&1 >output.log 
	}
	dpkg -l | grep resolvconf  >/dev/null 2>&1 || {
		sudo apt install resolvconf -y 2>&1 >output.log 
	}
	dpkg -l | grep pbis  >/dev/null 2>&1 || {
		wget https://github.com/BeyondTrust/pbis-open/releases/download/9.0.1/pbis-open-9.0.1.525.linux.x86_64.deb.sh 2>&1 >output.log 
		sudo chmod +x pbis-open-9.0.1.525.linux.x86_64.deb.sh 2>&1 >output.log 
		yes | sudo sh pbis-open-9.0.1.525.linux.x86_64.deb.sh 2>&1 >output.log 
	}
	dpkg -l | grep collectd > /dev/null 2>&1 || {
		sudo apt-get install collectd -y 2>&1 >output.log 
	}

	echo "20" | dialog --gauge "Hamonize Pc 관리프로그램 설치중..." 10 70 0
	
	sudo rm /etc/resolv.conf
	sudo ln -s /run/resolvconf/resolv.conf /etc/resolv.conf
	
	sudo sed -i "$ a\search $HIZDOMAIN \nnameserver $HIZIP" /etc/resolv.conf
	sudo echo "nameserver $HIZIP" | sudo tee /etc/resolvconf/resolv.conf.d/head &


	echo "30" | dialog --gauge "Hamonize Pc 관리프로그램 설치중..." 10 70 0
	#sudo sed -i  "$s/$/nameserver $HIZIP/g" /etc/resolvconf/resolv.conf.d/head
	sudo service resolvconf restart

	sudo sed -i "s/send host-name = gethostname();/supersede domain-name $HIZDOMAIN \nprepend domain-name-servers $HIZIP\nsend host-name = gethostname();/" /etc/dhcp/dhclient.conf
	sudo sed -i "/admin ALL=(ALL) ALL/i\%domain^users ALL=(ALL) ALL " /etc/sudoers
	sudo sed -i "/allow-guest=false/i\greeter-show-manual-login=true" /usr/share/lightdm/lightdm.conf.d/50-disable-guest.conf
       

	#==== AD Join Action ==============================================
   	domainCut=`echo "$HIZDOMAIN" | cut -d'.' -f1`
	domainCut2=`echo "$HIZDOMAIN" | cut -d'.' -f2`
	domainCut3=`echo "$HIZDOMAIN" | cut -d'.' -f3`

	sudo domainjoin-cli join --ou "$RETOU",DC="$domainCut",DC="$domainCut2",DC="$domainCut3" "$HIZDOMAIN" "$HIZID" "$HIZPW" 2>&1 >output.log 
 	sudo domainjoin-cli query >> domainjoin-query.log
 	CHKDOMAINJOIN=$(sudo tail -1 ./domainjoin-query.log | awk '{print $NF}')

	if [ "$CHKDOMAINJOIN" = '=' ] then
		dialog --title "Hamonize Pc 관리프로그램" --backtitle "Hamonikr-ME" --msgbox  \ "도메인 계정 가입 오류\n 관계자에게 문의 바랍니다. " 0 0
		exit
	fi

	echo "40" | dialog --gauge "Hamonize Pc 관리프로그램 설치중..." 10 70 0

	loginchk=$(grep -r 'ERROR' ./output.log)
	if [ "$loginchk" != "" ]  then
		domainAccountError=$(cat output.log  | tail -1)
	        dialog --title "Hamonize Pc 관리프로그램" --backtitle "Hamonikr-ME" --msgbox  \ "도메인 계정 가입 오류\n $domainAccountError" 0 0
    		exit
	fi

	#==== AD PBIS 환경설정 ==============================================
      	sudo service ssh restart
      	sudo /opt/pbis/bin/config UserDomainPrefix $domainCut
      	sudo /opt/pbis/bin/config AssumeDefaultDomain true
      	sudo /opt/pbis/bin/config LoginShellTemplate /bin/bash
      	sudo /opt/pbis/bin/config HomeDirTemplate %H/%U
      	sudo /opt/pbis/bin/config RequireMembershipOf $a\\\Domain^Users
      	sudo /opt/pbis/bin/ad-cache --delete-all >> output.log
  	sudo /opt/pbis/bin/update-dns >> output.log 

  	echo "60" | dialog --gauge "Hamonize Pc 관리프로그램 설치중..." 10 70 0



	
fi