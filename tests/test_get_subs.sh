#!/bin/bash

x=$(az account list )
length=$(jq -n "$x" | jq '. | length')
$index =0



START=0
END=$length-1
## save $START, just in case if we need it later ##
i=$START
while [[ $i -le $END ]]
do
	
	echo "$((i+1))" $(jq -n "$x" | jq .["$i"].name )  $(jq -n "$x" | jq .["$i"].id )
	((i++))
done


#echo "Subscriptions Found: " + jq -n "$x" | jq '. | length'




#s=$((az account list --query [*].[name,id]) | jq .[])
#echo $s
#echo -e "\n\n=======\n\n"
#echo $s |jq '.[0]'
#echo $s |jq '.[0][index]'
#echo $s |jq '.[1]'




#get length of the array
#jq -n "$x" | jq '. | length'
#jq -n "$x" | jq .[].id
#jq -n "$x" | jq .[].name

#get specipic item in from the array
#jq -n "$x" | jq .[0].id 

#echo "$x" | jq .id | jq -s .[3]




#for index in ${!d[@]}
#do
#    printf "   %d\n" $index
#done


#printf '%s\n' "${s[@]}"

#$index =0
#for i in $( echo $s |jq .[] ); do
#	echo "$index. Subscription : $i" 
#	((index++))
#done


#echo $s [*] | jq .[]
#printf '%s\n' "${s}"

#echo "The first value was ${value[0]} and the second ${value[1]}"

#for index in ${!s[0]}
#do
#    printf "   %d\n" $index
#done

#SUBSCRIPTION_IDS=$(jq .[].id $SUBS)
#SUBSCRIPTION_NAMES=$(jq .[].name $SUBS)
#index=0
 
#echo "Select subscription number:"
#echo ${SUBSCRIPTION_IDS[1]}


#for i in $( echo $SUBSCRIPTION_IDS ); do
#	echo "$index. subscription : $i" 
#	((index++))
#donessss