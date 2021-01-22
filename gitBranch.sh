#!/bin/sh

function gitBranch(){
  for file in ` ls $1 `; do
    echo $1"/"$file
    if [ -d $file ]; then
        git -C $file branch
    fi
    echo
  done
}

DIR="."
if [[ -n $1 ]]; then
  DIR=$1
fi
echo $DIR
echo
gitBranch $DIR 
