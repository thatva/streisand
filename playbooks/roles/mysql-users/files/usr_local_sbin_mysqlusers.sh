#!/bin/bash

chap_tmp=`mktemp`

# Local user 
# for PAM auth(openvpn,openconnect,ssh)
add_shell_user() {
   if ! ( id -u $1 >/dev/null 2>&1 ); then
     echo adding user $1
     useradd $1 -g vpn -s /bin/rbash 
     echo -e ${2}\\n${2} | passwd $1 >/dev/null 2>&1
   fi
}

del_shell_user() {
   if ( id -u $1 >/dev/null 2>&1 ); then
     echo removing user $1
     userdel $1
   fi
}

# shadowsocks user
add_ss_user() {
  if ! ( lsof -t -i :$1 >/dev/null 2>&1 ); then
     echo add shadowsocks $1
     echo ' add: {"server_port": '${1}', "password":"'${user_password}'"}' | socat - GOPEN:/var/run/ss.sock
  fi

}
del_ss_user() {
  if ( lsof -t -i :$1 >/dev/null 2>&1 ); then
     echo del shadowsocks $1
     echo ' remove: {"server_port": '${1}'}' | socat - GOPEN:/var/run/ss.sock
  fi
}

# lt2pd-ipsec user
add_l2tpd_user() {
   echo $1 l2tpd $2 \* >> $chap_tmp
}
del_l2tpd_user() {
   echo del lt2pd
}


mapfile -t user < <(echo select name,secret,ssport,ustate from users | mysql usersl)

for u in $(seq 1 $((${#user[@]} - 1))); do
   user_attrs=( $(echo ${user[$u]}) )
   user_name=${user_attrs[0]}
   user_password=${user_attrs[1]}
   user_port=${user_attrs[2]}
   user_enabled=${user_attrs[3]}

   if [ "$user_enabled" -eq "1" ]; then
	   add_shell_user $user_name $user_password
	   add_ss_user $user_port $user_password
      add_l2tpd_user $user_name $user_password
   else
	   del_shell_user $user_name
	   del_ss_user $user_port
   fi
done

if ! ( cmp -s $chap_tmp /etc/ppp/chap-secrets ); then
   mv -f $chap_tmp /etc/ppp/chap-secrets
else
   unlink $chap_tmp
fi



