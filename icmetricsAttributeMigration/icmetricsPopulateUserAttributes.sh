#!/bin/bash

# turn off expansion to avoid asterisk becoming current directory
set -f

if [ "${1:-}" = "" ]; then
echo "Please enter file name as an arguement"
else
file_name=$1

while IFS="," read -r useruuid username userAtt2 userVal2 userAtt3 userVal3
do
echo ${useruuid}
echo ${username}
echo ${userAtt2}
echo ${userVal2}
echo ${userAtt3}	
echo ${userVal3}


sh ./sendRequest.sh POST "/icmetrics_*/_update_by_query?conflicts=proceed&pretty" -H "Accept: application/json" -H 'Content-Type: application/json' -d'{
"query": {
"term": {
"userUuid": '${useruuid}'
}
},
"script": {
"source":"ctx._source.userAttribute2=params.userAttribute2; ctx._source.userAttribute3=params.userAttribute3;",
"lang": "painless",
"params": {
"userAttribute2": '"${userVal2}"',
"userAttribute3": '"${userVal3}"'
}}

}'


done < ${file_name}
fi
# turn expansion back to 'on'
set +f
