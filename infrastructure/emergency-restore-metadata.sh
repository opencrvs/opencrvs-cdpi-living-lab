# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# OpenCRVS is also distributed under the terms of the Civil Registration
# & Healthcare Disclaimer located at http://opencrvs.org/license.
#
# Copyright (C) The OpenCRVS Authors located at https://github.com/opencrvs/opencrvs-core/blob/master/AUTHORS.

#------------------------------------------------------------------------------------------------------------------
# By default OpenCRVS saves a backup of all data on a cron job every day in case of an emergency data loss incident
# This script clears all data and restores a specific day's data.  It is irreversable, so use with caution.
#------------------------------------------------------------------------------------------------------------------

if docker service ls > /dev/null 2>&1; then
  IS_LOCAL=false
else
  IS_LOCAL=true
fi


# Reading Named parameters
for i in "$@"; do
  case $i in
  --replicas=*)
    REPLICAS="${i#*=}"
    shift
    ;;
  --label=*)
    LABEL="${i#*=}"
    shift
    ;;
  *) ;;
  esac
done

print_usage_and_exit() {
  echo 'Usage: ./emergency-restore-metadata.sh --label=XXX --replicas=XXX'
<<<<<<< HEAD
  echo "This script CLEARS ALL DATA and RESTORES'S A SPECIFIC DAY'S or label's data.  This process is irreversable, so USE WITH CAUTION."
=======
  echo "This script CLEARS ALL DATA and RESTORES'S A SPECIFIC DAY'S or labels DATA.  This process is irreversable, so USE WITH CAUTION."
>>>>>>> dd541744 (Infrastructure deployment, monitoring and maintenance updates)
  echo "Script must receive a label parameter to restore data from that specific day in format +%Y-%m-%d i.e. 2019-01-01 or that label"
  echo "The Hearth, OpenHIM User and Application-config db backup zips you would like to restore from: hearth-dev-{label}.gz, openhim-dev-{label}.gz, user-mgnt-{label}.gz and  application-config-{label}.gz must exist in /data/backups/mongo/ folder"
  echo "The Elasticsearch backup folder /data/backups/elasticsearch must exist with all previous snapshots and indices. All files are required"
  echo "The InfluxDB backup files must exist in the /data/backups/influxdb/{label} folder"
  echo ""
  echo "If your MongoDB is password protected, an admin user's credentials can be given as environment variables:"
  echo "MONGODB_ADMIN_USER=your_user MONGODB_ADMIN_PASSWORD=your_pass"
  echo ""
  echo "If your Elasticsearch is password protected, an admin user's credentials can be given as environment variables:"
  echo "ELASTICSEARCH_ADMIN_USER=your_user ELASTICSEARCH_ADMIN_PASSWORD=your_pass"
  exit 1
}

if [ -z "$LABEL" ]; then
  echo "Error: Argument for the --label is required.  You must select which day's or which label's data you would like to roll back to."
  print_usage_and_exit
fi

if [ "$IS_LOCAL" = false ]; then
  ROOT_PATH=${ROOT_PATH:-/data}

  if [ -z "$REPLICAS" ]; then
    echo "Error: Argument for the --replicas is required."
    print_usage_and_exit
  fi
  # In this example, we load the MONGODB_ADMIN_USER, MONGODB_ADMIN_PASSWORD, ELASTICSEARCH_ADMIN_USER & ELASTICSEARCH_ADMIN_PASSWORD database access secrets from a file.
  # We recommend that the secrets are served via a secure API from a Hardware Security Module
  source /data/secrets/opencrvs.secrets
else
  ROOT_PATH=${ROOT_PATH:-../opencrvs-core/data}

  if [ ! -d "$ROOT_PATH" ]; then
    echo "Error: ROOT_PATH ($ROOT_PATH) doesn't exist"
    print_usage_and_exit
  fi

  ROOT_PATH=$(cd "$ROOT_PATH" && pwd)
fi

# Retrieve 2-step verification to continue
#-----------------------------------------
function ask_yes_or_no() {
  read -p "$1 ([y]es or [N]o): "
  case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
  y | yes) echo "yes" ;;
  *) echo "no" ;;
  esac
}

# We don't need confirmation when running from github action
if [[ "$CI" != "true" && ("no" == $(ask_yes_or_no "This script will clear all data from OpenCRVS and restore from a backup. Are you sure you are logged in as a root user?  ") ||
"no" == $(ask_yes_or_no "Are you *really* sure?  Have you tested these backup files in a restore process on a development environment first?")) ]]; then
  echo "Skipped."
  exit 0
fi

# Select docker network and replica set in production
#----------------------------------------------------
if [ "$IS_LOCAL" = true ]; then
  HOST=mongo1
  NETWORK=opencrvs_default
  echo "Working in local environment"
elif [ "$REPLICAS" = "0" ]; then
  HOST=mongo1
  NETWORK=opencrvs_default
  echo "Working with no replicas"
elif [ "$REPLICAS" = "1" ]; then
  HOST=rs0/mongo1
  NETWORK=opencrvs_overlay_net
  echo "Working with 1 replica"
elif [ "$REPLICAS" = "3" ]; then
  HOST=rs0/mongo1,mongo2,mongo3
  NETWORK=opencrvs_overlay_net
  echo "Working with 3 replicas"
elif [ "$REPLICAS" = "5" ]; then
  HOST=rs0/mongo1,mongo2,mongo3,mongo4,mongo5
  NETWORK=opencrvs_overlay_net
  echo "Working with 5 replicas"
else
  echo "Script must be passed an understandable number of replicas: 0,1,3 or 5"
  exit 1
fi

mongo_credentials() {
  if [ ! -z ${MONGODB_ADMIN_USER+x} ] || [ ! -z ${MONGODB_ADMIN_PASSWORD+x} ]; then
    echo "--username $MONGODB_ADMIN_USER --password $MONGODB_ADMIN_PASSWORD --authenticationDatabase admin"
  else
    echo ""
  fi
}

elasticsearch_host() {
  if [ ! -z ${ELASTICSEARCH_ADMIN_USER+x} ] || [ ! -z ${ELASTICSEARCH_ADMIN_PASSWORD+x} ]; then
    echo "$ELASTICSEARCH_ADMIN_USER:$ELASTICSEARCH_ADMIN_PASSWORD@elasticsearch:9200"
  else
    echo "elasticsearch:9200"
  fi
}

# Delete all data from Hearth, OpenHIM, User and Application-config and any other service related Mongo databases
#-----------------------------------------------------------------------------------
docker run --rm --network=$NETWORK mongo:4.4 mongo hearth-dev $(mongo_credentials) --host $HOST --eval "db.dropDatabase()"
docker run --rm --network=$NETWORK mongo:4.4 mongo openhim-dev $(mongo_credentials) --host $HOST --eval "db.dropDatabase()"
docker run --rm --network=$NETWORK mongo:4.4 mongo user-mgnt $(mongo_credentials) --host $HOST --eval "db.dropDatabase()"
docker run --rm --network=$NETWORK mongo:4.4 mongo application-config $(mongo_credentials) --host $HOST --eval "db.dropDatabase()"
docker run --rm --network=$NETWORK mongo:4.4 mongo metrics $(mongo_credentials) --host $HOST --eval "db.dropDatabase()"
docker run --rm --network=$NETWORK mongo:4.4 mongo webhooks $(mongo_credentials) --host $HOST --eval "db.dropDatabase()"
docker run --rm --network=$NETWORK mongo:4.4 mongo performance $(mongo_credentials) --host $HOST --eval "db.dropDatabase()"

# Delete all data from search
#----------------------------
echo "delete any previously created snapshot if any.  This may error on a fresh install with a repository_missing_exception error.  Just ignore it."
docker run --rm --network=$NETWORK appropriate/curl curl -X DELETE "http://$(elasticsearch_host)/_snapshot/ocrvs"
docker run --rm --network=$NETWORK appropriate/curl curl -X DELETE "http://$(elasticsearch_host)/*" -v

# Delete all data from metrics
#-----------------------------
docker run --rm --network=$NETWORK appropriate/curl curl -X POST 'http://influxdb:8086/query?db=ocrvs' --data-urlencode "q=DROP SERIES FROM /.*/" -v
docker run --rm --network=$NETWORK appropriate/curl curl -X POST 'http://influxdb:8086/query?db=ocrvs' --data-urlencode "q=DROP DATABASE \"ocrvs\"" -v

# Delete all data from minio
#-----------------------------
rm -rf $ROOT_PATH/minio/ocrvs
mkdir -p $ROOT_PATH/minio/ocrvs

# Delete all data from metabase
#-----------------------------
rm -rf $ROOT_PATH/metabase/*

# Delete all data from vsExport
#-----------------------------
rm -rf $ROOT_PATH/vsexport
mkdir -p $ROOT_PATH/vsexport

# Restore all data from a backup into Hearth, OpenHIM, User, Application-config and any other service related Mongo databases
#--------------------------------------------------------------------------------------------------
docker run --rm -v $ROOT_PATH/backups/mongo:/data/backups/mongo --network=$NETWORK mongo:4.4 bash \
  -c "mongorestore $(mongo_credentials) --host $HOST --drop --gzip --archive=/data/backups/mongo/hearth-dev-$LABEL.gz"
docker run --rm -v $ROOT_PATH/backups/mongo:/data/backups/mongo --network=$NETWORK mongo:4.4 bash \
  -c "mongorestore $(mongo_credentials) --host $HOST --drop --gzip --archive=/data/backups/mongo/openhim-dev-$LABEL.gz"
docker run --rm -v $ROOT_PATH/backups/mongo:/data/backups/mongo --network=$NETWORK mongo:4.4 bash \
  -c "mongorestore $(mongo_credentials) --host $HOST --drop --gzip --archive=/data/backups/mongo/user-mgnt-$LABEL.gz"
docker run --rm -v $ROOT_PATH/backups/mongo:/data/backups/mongo --network=$NETWORK mongo:4.4 bash \
  -c "mongorestore $(mongo_credentials) --host $HOST --drop --gzip --archive=/data/backups/mongo/application-config-$LABEL.gz"
docker run --rm -v $ROOT_PATH/backups/mongo:/data/backups/mongo --network=$NETWORK mongo:4.4 bash \
  -c "mongorestore $(mongo_credentials) --host $HOST --drop --gzip --archive=/data/backups/mongo/metrics-$LABEL.gz"
docker run --rm -v $ROOT_PATH/backups/mongo:/data/backups/mongo --network=$NETWORK mongo:4.4 bash \
  -c "mongorestore $(mongo_credentials) --host $HOST --drop --gzip --archive=/data/backups/mongo/webhooks-$LABEL.gz"
docker run --rm -v $ROOT_PATH/backups/mongo:/data/backups/mongo --network=$NETWORK mongo:4.4 bash \
  -c "mongorestore $(mongo_credentials) --host $HOST --drop --gzip --archive=/data/backups/mongo/performance-$LABEL.gz"

# Register backup folder as an Elasticsearch repository for restoring the search data
#-------------------------------------------------------------------------------------
docker run --rm --network=$NETWORK appropriate/curl curl -X PUT -H "Content-Type: application/json;charset=UTF-8" "http://$(elasticsearch_host)/_snapshot/ocrvs" -d '{ "type": "fs", "settings": { "location": "/data/backups/elasticsearch", "compress": true }}'

sleep 10
# Restore all data from a backup into search
#-------------------------------------------

docker run --rm --network=$NETWORK appropriate/curl curl -X POST -H "Content-Type: application/json;charset=UTF-8" "http://$(elasticsearch_host)/_snapshot/ocrvs/snapshot_$LABEL/_restore?pretty" -d '{ "indices": "ocrvs" }'

# Get the container ID and host details of any running InfluxDB container, as the only way to restore is by using the Influxd CLI inside a running opencrvs_metrics container
#----------------------------------------------------------------------------------------------------------------------------------------------------------------------------
if  [ "$IS_LOCAL" = true ]; then
  INFLUXDB_CONTAINER_ID=$(docker ps -aqf "name=influxdb")
else
  INFLUXDB_CONTAINER_ID=$(echo $(docker service ps --no-trunc -f "desired-state=running" opencrvs_influxdb) | awk '{print $11}')
  INFLUXDB_CONTAINER_NAME=$(echo $(docker service ps --no-trunc -f "desired-state=running" opencrvs_influxdb) | awk '{print $12}')
  INFLUXDB_HOSTNAME=$(echo $(docker service ps -f "desired-state=running" opencrvs_influxdb) | awk '{print $14}')
  INFLUXDB_HOST=$(docker node inspect --format '{{.Status.Addr}}' "$HOSTNAME")
  INFLUXDB_SSH_USER=${INFLUXDB_SSH_USER:-root}
  OWN_IP=$(echo $(hostname -I | cut -d' ' -f1))
fi

if [ "$IS_LOCAL" = true ]; then
  docker exec $INFLUXDB_CONTAINER_ID mkdir -p /home/user
  docker cp $ROOT_PATH/backups/influxdb/$LABEL/ $INFLUXDB_CONTAINER_ID:/home/user/$LABEL
  docker exec $INFLUXDB_CONTAINER_ID influxd restore -portable -db ocrvs /home/user/$LABEL
# If required, SSH into the node running the opencrvs_metrics container and restore the metrics data from an influxdb subfolder
#------------------------------------------------------------------------------------------------------------------------------
elif [[ "$OWN_IP" = "$INFLUXDB_HOST" ]]; then
  docker exec $INFLUXDB_CONTAINER_NAME.$INFLUXDB_CONTAINER_ID mkdir -p /home/user
  docker cp $ROOT_PATH/backups/influxdb/$LABEL/ $INFLUXDB_CONTAINER_NAME.$INFLUXDB_CONTAINER_ID:/home/user/$LABEL
  docker exec $INFLUXDB_CONTAINER_NAME.$INFLUXDB_CONTAINER_ID influxd restore -portable -db ocrvs /home/user/$LABEL
else
  scp -r /data/backups/influxdb $INFLUXDB_SSH_USER@$INFLUXDB_HOST:/data/backups/influxdb
  ssh $INFLUXDB_SSH_USER@$INFLUXDB_HOST "docker exec $INFLUXDB_CONTAINER_NAME.$INFLUXDB_CONTAINER_ID mkdir -p /home/user"
  ssh $INFLUXDB_SSH_USER@$INFLUXDB_HOST "docker cp /data/backups/influxdb/$LABEL/ $INFLUXDB_CONTAINER_NAME.$INFLUXDB_CONTAINER_ID:/home/user"
  ssh $INFLUXDB_SSH_USER@$INFLUXDB_HOST "docker exec $INFLUXDB_CONTAINER_NAME.$INFLUXDB_CONTAINER_ID influxd restore -portable -db ocrvs /home/user/$LABEL"
fi
# Restore all data from Minio
#----------------------------
tar -xzvf $ROOT_PATH/backups/minio/ocrvs-$LABEL.tar.gz -C $ROOT_PATH/minio

# Restore all data from Metabase
#----------------------------
tar -xzvf $ROOT_PATH/backups/metabase/ocrvs-$LABEL.tar.gz -C $ROOT_PATH/metabase

# Restore VSExport
tar -xzvf $ROOT_PATH/backups/vsexport/ocrvs-$LABEL.tar.gz -C $ROOT_PATH/vsexport

# Run migrations by restarting migration service
if [ "$IS_LOCAL" = false ]; then
  docker service update --force --update-parallelism 1 --update-delay 30s opencrvs_migration
fi
