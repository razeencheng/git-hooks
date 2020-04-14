#!/bin/sh

COMMIT_MSG=`cat $1 | egrep "^(feat|fix|docs|chore)(\(\w+\))?:\s(\S|\w)+"`

if [ "$COMMIT_MSG" = "" ]; then
	echo "Commit Message Irregular，Please check!\n"
	exit 1
fi

if [ ${#COMMIT_MSG} -lt 15 ]; then
	echo "Commit Message Too Short，Please show me more detail!\n"
	exit 1
fi
