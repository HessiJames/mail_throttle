#!/bin/bash
#
# Copyright (C) 2015 Daniel Faust <hessijames@gmail.com>
# Liscense: GPL-2
#
# Automated tests for mail_throttle

source mail_throttle.sh

return_code=0

function echo_red {
  echo -e "\e[1;31m$1\e[0m"
}

function echo_green {
  echo -e "\e[1;32m$1\e[0m"
}

function echo_success {
  echo_green "success"
}

function echo_failure {
  name=$1
  output=$2

  echo_red "failure"
  echo -e "$name:\n$output"
}

function return_function { 
  exit $1 
}

# fake mailx
function mt_send_mail {
  email_address="$1"
  email_subject="$2"
  email_body="$3"

  if [ $return_code -eq 0 ]; then
    echo "$email_address|$email_subject|$email_body"
  fi

  # fake return code of mailx
  $(return_function $return_code)
}

mt_db_file_name="/tmp/mail_throttle.$$.db"

mt_now=$(date +%s)

name="send a mail"
output=$(mail_throttle "test@example.com" "subject1" "body1" "test1" "60")
if [ "$output" == "test@example.com|subject1|body1" ]; then
  echo_success
else
  echo_failure "$name" "$output"
fi

name="don't send a mail within the next 60 seconds"
output=$(mail_throttle "test@example.com" "subject1" "body1" "test1" "60")
if [ "$output" == "" ]; then
  echo_success
else
  echo_failure "$name" "$output"
fi

mt_now=$((mt_now + 100))

name="send a mail 100 seconds later"
output=$(mail_throttle "test@example.com" "subject1" "body1" "test1" "60")
if [ "$output" == "test@example.com|subject1|body1" ]; then
  echo_success
else
  echo_failure "$name" "$output"
fi

name="send mail failure"
return_code=1
output=$(mail_throttle "test@example.com" "subject2" "body2" "test2" "60")
if [ "$output" == "sending mail failed, added to queue" ]; then
  echo_success
else
  echo_failure "$name" "$output"
fi

name="don't try to re-send failed mails within the next 24 hours"
return_code=0
output=$(mail_throttle "test@example.com" "subject3" "body3" "test3" "60")
if [ "$output" == "test@example.com|subject3|body3" ]; then
  echo_success
else
  echo_failure "$name" "$output"
fi

mt_now=$((mt_now + 24*60*60))

name="try to re-send failed mails 24 hours later"
return_code=0
output=$(mail_throttle "test@example.com" "subject3" "body3" "test3" "60")
if [ "$output" == "test@example.com|subject3|body3
test@example.com|subject2|body2" ]; then
  echo_success
else
  echo_failure "$name" "$output"
fi

mt_now=$((mt_now + 24*60*60))

name="queue must be empty another 24 hours later"
output=$(mail_throttle "test@example.com" "subject3" "body3" "test3" "60")
if [ "$output" == "test@example.com|subject3|body3" ]; then
  echo_success
else
  echo_failure "$name" "$output"
fi

rm "$mt_db_file_name"
