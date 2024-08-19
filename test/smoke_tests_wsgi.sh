#!/bin/bash
URL=http://localhost:8984/

echo -n "$0: Testing pre..."
PRE_HTTP_RESPONSE_CODE=$(curl --write-out %{http_code} --silent --output /dev/null -F xml=@./xml/elife45905.xml $URL/schematron/pre)
if [ $PRE_HTTP_RESPONSE_CODE -ne 200 ] ; then
    echo "FAILED!"
    exit 1
fi
echo "SUCCESS!"

echo -n "$0: Testing final..."
FINAL_HTTP_RESPONSE_CODE=$(curl --write-out %{http_code} --silent --output /dev/null -F xml=@./xml/elife45905.xml $URL/schematron/final)
if [ $FINAL_HTTP_RESPONSE_CODE -ne 200 ] ; then
    echo "FAILED!"
    exit 1
fi
echo "SUCCESS!"

echo -n "$0: Testing xsl..."
XSL_HTTP_RESPONSE_CODE=$(curl --write-out %{http_code} --silent --output /dev/null -F xml=@./xml/595301.xml $URL/xsl)
if [ $XSL_HTTP_RESPONSE_CODE -ne 200 ] ; then
    echo "FAILED!"
    exit 1
fi
echo "SUCCESS!"