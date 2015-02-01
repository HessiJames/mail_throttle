#!/bin/bash
#
# Copyright (C) 2015 Daniel Faust <hessijames@gmail.com>
# Liscense: GPL-2
#
# Sends status mails using mailx in given time intervals.
# Status mails are identified by an email address and an identifier string.
# If emails can't be sent, they are cached and re-sent if possible.
# Everything is stored in an sqlite database.
# Note that mailx has to be configured properly and may be replaced by another mail application.
#
# Warning: Strings must not contain the pipe character "|"!
#
# Dependencies:
# sqlite3
# mailx
#
# Usage:
# mail_throttle <email_address> <email_subject> <email_body> <identifier> <interval>

mt_db_file_name="$HOME/.mail_throttle.db"

mt_now=$(date +%s)

function mt_send_mail {
  email_address="$1"
  email_subject="$2"
  email_body="$3"

  echo "$email_body" | /usr/bin/mailx -v -s "$email_subject" "$email_address" &> /dev/null
}

function mt_send_queue {
  rows=$(sqlite3 "$mt_db_file_name" "SELECT rowid, email_address, email_subject, email_body FROM queue WHERE send_tries<3 AND last_send_try<strftime('%s',datetime($mt_now,'unixepoch','-1 day','+1 minute'))")
  for row in $rows; do
    # sqlite3 returns a pipe separated string
    rowid=$(echo $row | awk '{split($0,a,"|"); print a[1]}')
    email_address=$(echo $row | awk '{split($0,a,"|"); print a[2]}')
    email_subject=$(echo $row | awk '{split($0,a,"|"); print a[3]}')
    email_body=$(echo $row | awk '{split($0,a,"|"); print a[4]}')
      
    mt_send_mail "$email_address" "$email_subject" "$email_body"
    if [ $? -eq 0 ]; then
      # success, remove from queue
      sqlite3 "$mt_db_file_name" "DELETE FROM queue WHERE rowid='$rowid'"
    else
      # failure, increment counter
      sqlite3 "$mt_db_file_name" "UPDATE queue SET send_tries=send_tries+1, last_send_try='$mt_now' WHERE rowid='$rowid'"
    fi
  done
}

function mt_send {
  email_address="$1"
  email_subject="$2"
  email_body="$3"

  mt_send_mail "$email_address" "$email_subject" "$email_body"
  if [ $? -eq 0 ]; then
    # success, now send everything in the queue
    mt_send_queue
  else
    # failure, add to queue
    sqlite3 "$mt_db_file_name" "INSERT INTO queue (email_address, email_subject, email_body, send_tries, last_send_try) VALUES ('$email_address', '$email_subject', '$email_body', '1', '$mt_now')"
    echo "sending mail failed, added to queue"
  fi
}

function mail_throttle {
  email_address="$1"
  email_subject="$2"
  email_body="$3"
  identifier="$4"
  interval="$5"

  db_structure="CREATE TABLE mail (email_address TEXT, identifier TEXT, last_sent TIMESTAMP);
CREATE TABLE queue (email_address TEXT, email_subject TEXT, email_body TEXT, send_tries INTEGER, last_send_try TIMESTAMP);"

  if [ ! -f "$mt_db_file_name" ]; then
    sqlite3 "$mt_db_file_name" "$db_structure"
  fi

  rows=$(sqlite3 "$mt_db_file_name" "SELECT rowid, last_sent FROM mail WHERE email_address='$email_address' AND identifier='$identifier'")
  found=0
  for row in $rows; do
    # sqlite3 returns a pipe separated string
    rowid=$(echo $row | awk '{split($0,a,"|"); print a[1]}')
    last_sent=$(echo $row | awk '{split($0,a,"|"); print a[2]}')
      
    if [ $(( last_sent + interval )) -lt $mt_now ]; then
      mt_send "$email_address" "$email_subject" "$email_body"
      sqlite3 "$mt_db_file_name" "UPDATE mail SET last_sent='$mt_now' WHERE rowid='$rowid'"
    fi

    found=1
  done

  if [ $found -eq 0 ]; then
    mt_send "$email_address" "$email_subject" "$email_body"
    sqlite3 "$mt_db_file_name" "INSERT INTO mail (email_address, identifier, last_sent) VALUES ('$email_address', '$identifier', '$mt_now')"
  fi
}
