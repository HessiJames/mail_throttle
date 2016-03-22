# mail_throttle
A library for shell scripts that sends status mails using mailx in given time intervals.

Status mails are identified by an email address and an identifier string.  
If emails can't be sent, they are cached and re-sent if possible.  
Everything is stored in an sqlite database.  
Note that mailx has to be configured properly and may be replaced by another mail application.

Warning: Strings must not contain the pipe character "|"!

## Depends on
sqlite3  
mailx

## Usage
```sh
source mail_throttle.sh

mail_throttle <email_address> <email_subject> <email_body> <identifier> <interval>
```
