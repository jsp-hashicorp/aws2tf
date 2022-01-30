#!/bin/bash
if [ "$1" == "" ]; then
    echo "must specify resource type (ttft)"
    exit
fi
for st in `ls pi2/$1__*.tfstate` 
do
    ttft=$(echo $1)
    rname=${st/pi2\/${1}__/}
    rname=$(echo $rname | cut -f1 -d'.')
    
    sl=`echo $((1 + $RANDOM % 10))`
    comm=$(printf "terraform state mv -state %s -state-out=terraform.tfstate -lock=true %s.%s %s.%s" $st $ttft $rname $ttft $rname)
    #echo $comm
    eval $comm > /dev/null
    if [ $? -ne 0 ]; then
        sl=`echo $((1 + $RANDOM % 10))`
        sleep $sl
        echo "state mv retry for $st"
        eval $comm
        if [ $? -ne 0 ]; then
            echo "** error state mv $st"
        else
            #echo "ok2 - rm state $st"
            rm -f $st*
        fi
    else
        #echo "ok1 - rm state $st"
        rm -f $st*
    fi

echo "moved state $ttft.$rname"
done
rm -rf pi2