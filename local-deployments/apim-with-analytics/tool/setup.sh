#!/bin/sh

#APIM MySQL
mysql_apim_username="root"
mysql_apim_password="root"
am_db="am_db"
um_db="um_db"
reg_db="reg_db"

#Analytics MySQL
mysql_analytics_username="root"
mysql_analytics_password="root"
event_store_db="event_store_db"
processed_data_db="processed_data_db"
stats_db="stats_db"

APIM_PACK=wso2am-2.1.0.*.zip
ANALYTICS_PACK=wso2am-analytics-2.1.0.*.zip
MYSQL_DRIVER=mysql-connector-java-5.1.24.jar

if [ ! -f ../$APIM_PACK ]; then
    echo -e "\e[32m>> APIM 2.1.0 pack not found! \e[0m"
    exit 1
fi

if [ ! -f ../$ANALYTICS_PACK ]; then
    echo -e "\e[32m>> APIM Analytics 2.1.0 pack not found! \e[0m"
    exit 1
fi

if [ ! -f $MYSQL_DRIVER ]; then
    echo "Downloading $MYSQL_DRIVER..."
    wget http://central.maven.org/maven2/mysql/mysql-connector-java/5.1.24/mysql-connector-java-5.1.24.jar
fi

if [ ! -x "$(command -v mysql)" ]; then
    echo -e "\e[32m>> Please install MySQL client. \e[0m"
    exit 1
fi

if [ ! -x "$(command -v docker)" ]; then
    echo -e "\e[32m>> Please install Docker. \e[0m"
    exit 1
fi

if [ -d ../wso2am-2.1.0 ]; then
    echo "Killing Servers..."
    kill -9 $(cat ../wso2am-2.1.0/wso2carbon.pid)
    kill -9 $(cat ../wso2am-analytics-2.1.0/wso2carbon.pid)
    echo "Done!"

    echo "Removing Servers..."
    rm -rf ../wso2am-2.1.0
    rm -rf ../wso2am-analytics-2.1.0
fi

echo "Extracting Servers..."
unzip -q ../wso2am-2.1.0.*.zip -d ../
unzip -q ../wso2am-analytics-2.1.0.*.zip -d ../
echo "Servers extracted!"

if [ ! "$(docker ps -q -f name=mysql-5.7)" ]; then
    echo -e "\e[32m>> Pulling MySQL docker image... \e[0m"
    docker pull mysql/mysql-server:5.7

    echo -e "\e[32m>> Starting MySQL docker container... \e[0m"
    container_id=$(docker run -d --name mysql-5.7 -p 3306:3306 -e MYSQL_ROOT_HOST=% -e MYSQL_ROOT_PASSWORD=$mysql_apim_password mysql/mysql-server:5.7)
    echo $container_id
    #detects the docker ip
    docker_ip=$(docker inspect $container_id | grep -w \"IPAddress\" | head -n 1 | cut -d '"' -f 4)
    echo $docker_id
    mysql_analytics_host=$docker_ip
    mysql_apim_host=$docker_ip

    docker ps -a
    echo -e "\e[32m>> Waiting for MySQL to start on 3306... \e[0m"
    while ! nc -z $mysql_apim_host 3306; do
        sleep 1
        printf "."
    done
    echo ""
    echo -e "\e[32m>> MySQL Started. \e[0m"

    echo "Creating databases..."
    mysql -h $mysql_apim_host -u $mysql_apim_username -p$mysql_apim_password -e "DROP DATABASE IF EXISTS "$am_db"; DROP DATABASE IF EXISTS "$um_db"; DROP DATABASE IF EXISTS "$reg_db"; CREATE DATABASE "$am_db"; CREATE DATABASE "$um_db"; CREATE DATABASE "$reg_db";"
    mysql -h $mysql_analytics_host -u $mysql_analytics_username -p$mysql_analytics_password -e "DROP DATABASE IF EXISTS "$event_store_db"; DROP DATABASE IF EXISTS "$processed_data_db"; DROP DATABASE IF EXISTS "$stats_db"; CREATE DATABASE "$event_store_db"; CREATE DATABASE "$processed_data_db"; CREATE DATABASE "$stats_db";"
    echo "Done!"

    echo "Creating tables..."
    mysql -h $mysql_apim_host -u $mysql_apim_username -p$mysql_apim_password -e "USE "$am_db"; SOURCE ../wso2am-2.1.0/dbscripts/apimgt/mysql5.7.sql; USE "$um_db"; SOURCE ../wso2am-2.1.0/dbscripts/mysql5.7.sql; USE "$reg_db"; SOURCE ../wso2am-2.1.0/dbscripts/mysql5.7.sql;"
    echo "Done!"
else
    echo -e "\e[32m>> MySQL is already running... Not creating databases nor tables... Existing data will be used.\e[0m"
    docker ps -a
fi

echo "Copying configuration files..."
cp -r apim_conf/* ../wso2am-2.1.0/repository/conf/
cp -r apim_analytics_conf/* ../wso2am-analytics-2.1.0/repository/conf/
cp $MYSQL_DRIVER ../wso2am-2.1.0/repository/components/lib/
cp $MYSQL_DRIVER ../wso2am-analytics-2.1.0/repository/components/lib/
cp _HealthCheck_.xml ../wso2am-2.1.0/repository/deployment/server/synapse-configs/default/api/
echo "Done!"

echo "Configuring files..."
find ../wso2am-* -type f \( -iname "*.properties" -o -iname "*.xml" \) -print0 | xargs -0 sed -i 's/#_MySQL_APIM_HOST_#/'$mysql_apim_host'/g'
find ../wso2am-* -type f \( -iname "*.properties" -o -iname "*.xml" \) -print0 | xargs -0 sed -i 's/#_MySQL_APIM_USERNAME_#/'$mysql_apim_username'/g'
find ../wso2am-* -type f \( -iname "*.properties" -o -iname "*.xml" \) -print0 | xargs -0 sed -i 's/#_MySQL_APIM_PASSWORD_#/'$mysql_apim_password'/g'
find ../wso2am-* -type f \( -iname "*.properties" -o -iname "*.xml" \) -print0 | xargs -0 sed -i 's/#_AM_DB_#/'$am_db'/g'
find ../wso2am-* -type f \( -iname "*.properties" -o -iname "*.xml" \) -print0 | xargs -0 sed -i 's/#_UM_DB_#/'$um_db'/g'
find ../wso2am-* -type f \( -iname "*.properties" -o -iname "*.xml" \) -print0 | xargs -0 sed -i 's/#_REG_DB_#/'$reg_db'/g'
find ../wso2am-* -type f \( -iname "*.properties" -o -iname "*.xml" \) -print0 | xargs -0 sed -i 's/#_MySQL_ANALYTICS_HOST_#/'$mysql_analytics_host'/g'
find ../wso2am-* -type f \( -iname "*.properties" -o -iname "*.xml" \) -print0 | xargs -0 sed -i 's/#_MySQL_ANALYTICS_USERNAME_#/'$mysql_analytics_username'/g'
find ../wso2am-* -type f \( -iname "*.properties" -o -iname "*.xml" \) -print0 | xargs -0 sed -i 's/#_MySQL_ANALYTICS_PASSWORD_#/'$mysql_analytics_password'/g'
find ../wso2am-* -type f \( -iname "*.properties" -o -iname "*.xml" \) -print0 | xargs -0 sed -i 's/#_EVENT_STORE_DB_#/'$event_store_db'/g'
find ../wso2am-* -type f \( -iname "*.properties" -o -iname "*.xml" \) -print0 | xargs -0 sed -i 's/#_PROCESSED_DATA_DB_#/'$processed_data_db'/g'
find ../wso2am-* -type f \( -iname "*.properties" -o -iname "*.xml" \) -print0 | xargs -0 sed -i 's/#_STATS_DB_#/'$stats_db'/g'
echo "Done!"

echo "Starting Servers..."
sh ../wso2am-analytics-2.1.0/bin/wso2server.sh start
echo "APIM Analytics Server is starting up..."
sleep 30
sh ../wso2am-2.1.0/bin/wso2server.sh start
echo "APIM Server is starting up..."
echo ""
echo "What's Next? View APIM/Analytics logs by running below commands..."
echo ""
echo "tail -f ../wso2am-2.1.0/repository/logs/wso2carbon.log"
echo "tail -f ../wso2am-analytics-2.1.0/repository/logs/wso2carbon.log"
echo ""
