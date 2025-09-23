Steps to run icmetricsPopulateUserAttributes.sh

Step 1: Gather profile extension attributes from oracle db as a csv file using below set of SQL queries:

create view userAtt2 as select emp.prof_guid, emp.prof_uid, pe.prof_property_id, pe.prof_value from EMPINST.employee emp join EMPINST.profile_extensions pe on pe.prof_key=emp.prof_key where pe.prof_property_id in ('region')  ;

create view userAtt3 as select emp.prof_guid, emp.prof_uid, pe.prof_property_id, pe.prof_value from EMPINST.employee emp join EMPINST.profile_extensions pe on pe.prof_key=emp.prof_key where pe.prof_property_id in ('compassDivision')  ;

commit;

select (CASE WHEN ua2.prof_guid is null THEN ua3.prof_guid ELSE ua2.prof_guid END) AS prof_guid,
(CASE WHEN ua2.prof_uid is null THEN ua3.prof_uid ELSE ua2.prof_uid END) AS prof_uid,
ua2.prof_property_id, ua2.prof_value, ua3.prof_property_id, ua3.prof_value from userAtt2 ua2 full outer join userAtt3 ua3 on ua2.prof_guid=ua3.prof_guid;

Step 2: Export the result of above query to a csv. sample.csv is attached for reference. The csv should not include header and fields should be enclosed in ""

Step 3: Copy the icmetricsPopulateUserAttributes.sh and csv file to /opt/elasticsearch-5.5.1/probe directory within elasticsearch5 pod. Use below commands

kubectl cp <source-dir>/icmetricsPopulateUserAttributes.sh connections/es-data-0:/opt/elasticsearch-5.5.1/probe/icmetricsPopulateUserAttributes.sh
kubectl cp <source-dir>/<your-csv-file>.csv connections/es-data-0:/opt/elasticsearch-5.5.1/probe/<your-csv-file>.csv
example: kubectl cp <source-dir>/sample.csv connections/es-data-0:/opt/elasticsearch-5.5.1/probe/sample.csv

Step 4: Go to command line inside elasticsearch5 pod using below command

kubectl exec -ti es-data-0 bash -n connections

Step 5: go to directory /opt/elasticsearch-5.5.1/probe

Step 6: Change permissions for icmetricsPopulateUserAttributes.sh

chmod +x icmetricsPopulateUserAttributes.sh

Step 7: If you are working on elasticsearch 5.5, edit icmetricsPopulateUserAttributes.sh in vi or any equivalent editor. Replace the word "source" with "inline" 

For reference change below line 
"source":"ctx._source.userAttribute2=params.userAttribute2; ctx._source.userAttribute3=params.userAttribute3;",
to
"inline":"ctx._source.userAttribute2=params.userAttribute2; ctx._source.userAttribute3=params.userAttribute3;",

Important variation in elasticsearch 5 vs elasticsearch 7: the script parameter in elasticsearch 5.5 is "inline". This was changed to "source" in elasticsearch 7

Step 8: Execute the script. Provide your csv file name as arguement.

./icmetricsPopulateUserAttributes.sh <your-csv-file>.csv
example: ./icmetricsPopulateUserAttributes.sh sample.csv

Note: Please check the pod's name is es-data-0 by running kubectl get pods -n connections | grep es
Please replace the name in above commands as necessary.

Note: The above steps will be same for elasticsearch 7. Only paths and pod names will change. 

Refer below documentation for script parameter changes in elasticsearch 5.5 vs elasticsearch 7
https://www.elastic.co/guide/en/elasticsearch/reference/5.5/modules-scripting-using.html
https://www.elastic.co/guide/en/elasticsearch/reference/7.2/modules-scripting-using.html

Note for updateTargetItemsCreatorUuid.sh
Remove /event in all queries while executing script for ES7 and replace "inline" with "source"
Steps to execute updateTargetItemsCreatorUuid.sh
1. Customer needs to go to kubernetes pod of elasticsearch
2. cd /probe 
3. copy the script to this location
4. run the script using:
./updateTargetItemsCreatorUuid.sh >> output.log
