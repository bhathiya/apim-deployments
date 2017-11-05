#!/bin/sh

if [ ! -x "$(command -v docker)" ]; then
    echo -e "\e[32m>>  Please install Docker. \e[0m"
    exit 1
fi

echo -e "\e[32m>> Killing MySQL docker container... \e[0m"
docker rm $(docker stop mysql-5.7) 
echo "Done!"

echo "Killing Servers..."
kill -9 $(cat ../wso2am-2.1.0/wso2carbon.pid)
kill -9 $(cat ../wso2am-analytics-2.1.0/wso2carbon.pid)
echo "Done!"

echo "Removing Servers..."
rm -rf ../wso2am-2.1.0
rm -rf ../wso2am-analytics-2.1.0
echo "Done!"
