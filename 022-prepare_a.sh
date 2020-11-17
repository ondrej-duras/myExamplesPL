##
#!/bin/bash can not be used

if [ "$0" != "-bash" ]; then
  echo "prepare_a: Error: run it by command '. prepare_a.sh' !"
  exit -1
fi

read -p "Profile: " XPROFILE
read -p "Login: " XLOGIN
read -s -p "Password: " XPASSWORD

export CRED_${XPROFILE}="ssh:${XLOGIN}:${XPASSWORD}"
unset XLOGIN XPASSOWRD
