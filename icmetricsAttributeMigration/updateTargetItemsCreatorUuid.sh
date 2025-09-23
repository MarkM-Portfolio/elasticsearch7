#!/bin/bash

# turn off expansion to avoid asterisk becoming current directory
set -f

counter=1
until [ $counter = 0 ]
do
count=$(./sendRequest.sh GET "/icmetrics_a/event/_count" -H "Accept: application/json" -H 'Content-Type: application/json' -d'
{
    "query": {
        "bool": {
            "filter": {
                    "term": {
                        "targetItemCreatorUuidToBeUpdated": true
                    }
                }
        }
    }
}
')

count=$(grep -o '"count":[[:digit:]]*' <<< "${count}")
IFS=: read -r field1 countValue <<< $count

((counter=countValue))

echo "Documents remaining to update: "$counter

if [[ ${countValue} > 0 ]]
then




itemsToUpdate=$(./sendRequest.sh GET "/icmetrics_a/event/_search?size=1000" -H "Accept: application/json" -H 'Content-Type: application/json' -d'
{
    "query": {
        "bool": {
            "filter": {
                    "term": {
                        "targetItemCreatorUuidToBeUpdated": true
                    }
                }
        }
    },
	
  "_source": "targetItemUuid"
}
')



itemsToUpdate=$(grep -o '"targetItemUuid":"[^"]*"' <<< "${itemsToUpdate}")

> itemsToUpdate.txt

echo ${itemsToUpdate} | tr " " "\n" >> itemsToUpdate.txt

sed -i 's/targetItemUuid/itemUuid/' itemsToUpdate.txt

> distinctItemsToUpdate.txt

uniq itemsToUpdate.txt distinctItemsToUpdate.txt

while IFS=":" read -r field3 value
do

resp=$(./sendRequest.sh GET "/icmetrics_a/event/_search" -H "Accept: application/json" -H 'Content-Type: application/json' -d'
{
    "size": 1,
    "query": {
        "bool": {
            "filter": [{
                    "term": {
                        "itemUuid": '${value}'
                    }
                }, {
                    "term": {
                        "eventOpId": 2
                    }
                }
            ]
        }
    },
	
  "_source": "creatorUuid"
}
')



creator=$(grep -o '"creatorUuid":"[^"]*"' <<< "${resp}")


IFS=: read -r field2 creatorId <<< $creator


if test -z "$creatorId" 
then

./sendRequest.sh POST "/icmetrics_a/event/_update_by_query?conflicts=proceed&pretty" -H "Accept: application/json" -H 'Content-Type: application/json' -d'{
"query": {
        "bool": {
            "filter": [{
                    "term": {
                        "targetItemUuid": '${value}'
                    }
                }, {
                    "term": {
                        "targetItemCreatorUuidToBeUpdated": true
                    }
                }
            ]
        }
    },
"script": {
"inline":"ctx._source.targetItemCreatorUuidToBeUpdated=params.targetItemCreatorUuidToBeUpdated;",
"lang": "painless",
"params": {
"targetItemCreatorUuidToBeUpdated": 'false'
}}
}'

else

./sendRequest.sh POST "/icmetrics_a/event/_update_by_query?conflicts=proceed&pretty" -H "Accept: application/json" -H 'Content-Type: application/json' -d'{
"query": {
        "bool": {
            "filter": [{
                    "term": {
                        "targetItemUuid": '${value}'
                    }
                }, {
                    "term": {
                        "targetItemCreatorUuidToBeUpdated": true
                    }
                }
            ]
        }
    },
"script": {
"inline":"ctx._source.targetItemCreatorUuid=params.targetItemCreatorUuid; ctx._source.targetItemCreatorUuidToBeUpdated=params.targetItemCreatorUuidToBeUpdated;",
"lang": "painless",
"params": {
"targetItemCreatorUuid": '"${creatorId}"',
"targetItemCreatorUuidToBeUpdated": 'false'
}}
}'
fi
done < distinctItemsToUpdate.txt
else
echo "Finished the update process."

fi
done
# turn expansion back to 'on'
set +f
