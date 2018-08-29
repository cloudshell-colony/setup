#!/bin/bash

x=$(az account list )
length=$(jq -n "$x" | jq '. | length')
$index =0
END=$length-1
i=0
subscription_number=0

echo "Please type subscription number:#"
while [[ $i -le $END ]]
do
	# prints subscription name and id
	echo "$((i+1))" $(jq -n "$x" | jq .["$i"].name )  $(jq -n "$x" | jq .["$i"].id )
	((i++))
done
echo "Enter number between 1 to " $length

read subscription_number

while [ $subscription_number -lt 1 -o $subscription_number -gt $length ]
do
	echo "Please enter number between 1 to " $length
	read subscription_number
done

echo "Chosen subscription:" $(jq -n "$x" | jq .["$((subscription_number-1))"].name )  $(jq -n "$x" | jq .["$((subscription_number-1))"].id )