#!/bin/sh

COMMIT_MSG=`cat $1 | egrep "^(feat|fix|docs|chore)\(\w+\)?:\s(\S|\w)+"`

if [ "$COMMIT_MSG" = "" ]; then
	echo "Commit Message 不规范，请检查!\n"
	exit 1
fi

if [ ${#COMMIT_MSG} -lt 15 ]; then
	echo "Commit Message 太短了，请再详细点!\n"
	exit 1
fi