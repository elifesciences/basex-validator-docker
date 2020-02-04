#!/bin/bash
COUNT="0"
HTTP_RESPONSE_CODE="200"
URL=http://localhost:8984/
while [ $HTTP_RESPONSE_CODE -eq 200 ]
do
    HTTP_RESPONSE_CODE=$(curl --write-out %{http_code} --silent --output /dev/null -F xml=@elife45905.xml $URL/schematron/pre)
    COUNT=$[$COUNT+1]
    echo "$COUNT: Got HTTP $HTTP_RESPONSE_CODE"
    sleep 1
done
