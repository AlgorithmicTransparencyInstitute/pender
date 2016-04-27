#!/bin/bash


function usage() {
cat <<EOF
     Get a production token from Facebook that lasts 60 days

     usage:
          $0 <fb_app_id> <fb_app_secret> <fb_user_token>

     the README has some instructions

     get the app id and secret from
     https://developers.facebook.com/apps/367708839993582/dashboard/

     get the user token from
     https://developers.facebook.com/tools/accesstoken/

EOF
exit;

}

if [ "" = "$1" ]; then
   usage
fi

fb_app_id=$1
fb_app_secret=$2

fb_user_token=$3

curl -s "https://graph.facebook.com/oauth/access_token?grant_type=fb_exchange_token&client_id=${fb_app_id}&client_secret=${fb_app_secret}&fb_exchange_token=${fb_user_token}" | cut -d= -f2 | cut -d\& -f1
# echo
