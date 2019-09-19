#!/bin/bash
name_servers=$@

while getopts "n:a:r:p:d:g:H:u:i:k:s:h" opt
do
   case "$opt" in
      n ) name_servers="$OPTARG" ;;
      a ) automation_mount="${OPTARG}" ;;
      r ) roaming_mount="$OPTARG" ;;
      p ) ip="$OPTARG" ;;
      d ) dc="$OPTARG" ;;
      g ) region="$OPTARG" ;;
      H ) hostname="$OPTARG" ;;
      u ) user="$OPTARG" ;;
      i ) userid="$OPTARG" ;;
      k ) public_key="$OPTARG" ;;
      s ) suse_repo="$OPTARG" ;;
   esac
done

UpdateNameServers(){

    RESOLVE_CNF="/etc/resolv.conf"
    HOSTS="/etc/hosts"

    echo -e "## Modifed by Automation Framework ######\ndomain ap-au.sf.priv\nsearch ap-au.sf.priv sf.priv openstack.${region}.cloud.sap" > $RESOLVE_CNF
    for dns in $(echo $name_servers | tr ',' '\n')
    do
        echo "nameserver $dns" >> $RESOLVE_CNF
    done
    echo "options timeout:2"  >> $RESOLVE_CNF
    echo "options rotate" >> $RESOLVE_CNF

    echo ${ip} ${hostname}.ap-au.sf.priv ${hostname} > $HOSTS
}

StorageNIC(){
  cp /etc/sysconfig/network/ifcfg-eth0 /etc/sysconfig/network/ifcfg-eth1
  service network restart
  sleep 5
}

RemoteMounts(){

    FSTAB="/etc/fstab"
    if [[ ! -z $automation_mount ]];then
     grep /automation /etc/fstab || mkdir -p /automation
     echo "${automation_mount} /automation nfs rw 0 2" >> /etc/fstab
 fi
    if [[ ! -z $roaming_mount ]];then
     grep /home/roaming /etc/fstab || mkdir -p /home/roaming
     echo "${roaming_mount} /home/roaming nfs vers=4,rsize=32768,wsize=32768,intr,_netdev 0 0" >> /etc/fstab
    fi
    mount -a
}

Adduser(){

    SUDOERS='/etc/sudoers'

    /usr/sbin/groupadd -g $userid $user
    /usr/sbin/useradd -u $userid -g $user $user
    /usr/sbin/usermod -u $userid $user
    /usr/sbin/groupmod -g $userid $user
    chown -R $user:$user /home/$user
    mkdir -p /home/${user}/.ssh/
    touch /home/${user}/.ssh/authorized_keys
    sed -i "/${user} ALL=(ALL) NOPASSWD: ALL/d" $SUDOERS
    echo "${user} ALL=(ALL) NOPASSWD: ALL" >> $SUDOERS
    sed -i "/$public_key/d" /home/${user}/.ssh/authorized_keys
    echo $public_key >> /home/${user}/.ssh/authorized_keys
    chown -R ${user}:${user} /home/${user}/
    chmod 644 /home/${user}/.ssh/authorized_keys
}

Repos(){
     
    for pid in $(ps -ef | grep -i "zypper" | grep -v grep| awk '{print $2}'); do kill -9 $pid; done
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        if [ $NAME == "SLES" ]; then
            zypper mr -d SLES12_SP3_update
            #remove spacewak repo if exists
            zypper ls -u | grep spacewalk | grep plugin > /dev/null  2>&1

            if [ $? -eq 0 ];then

                sudo systemctl stop osad
                sudo zypper --non-interactive rm -u spacewalksd spacewalk-check zypp-plugin-spacewalk spacewalk-client-tools osad
                rm -rf /etc/sysconfig/rhn/systemid
            fi

            zypper ar -G http://yum/hcm//common/yum/SLES/12.3/custom hcm_platform_common
            zypper ar -G http://yum/hcm//platform/yum/SLES/12.3 hcm_platform_services

        fi
    fi

}

StorageNIC
RemoteMounts
UpdateNameServers
Adduser
Repos
exit 0
