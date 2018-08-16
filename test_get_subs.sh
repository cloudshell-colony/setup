#!/bin/bash
SUBSCRIPTION_IDS=$(jq .[].id data.json)
SUBSCRIPTION_NAMES=$(jq .[].name data.json)
index=0
 
echo "Select subscription number:"
echo ${SUBSCRIPTION_IDS[1]}


for i in $( echo $SUBSCRIPTION_IDS ); do

	echo "$index. subscription : $i" 
	((index++))
done
