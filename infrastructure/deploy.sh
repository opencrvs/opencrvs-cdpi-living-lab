# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# OpenCRVS is also distributed under the terms of the Civil Registration
# & Healthcare Disclaimer located at http://opencrvs.org/license.
#
# Copyright (C) The OpenCRVS Authors located at https://github.com/opencrvs/opencrvs-core/blob/master/AUTHORS.
set -e

BASEDIR=$(dirname $0)
PARENT_DIR=$(dirname $(dirname $0))

# Reading Names parameters
for i in "$@"; do
    case $i in
    --clear_data=*)
        CLEAR_DATA="${i#*=}"
        shift
        ;;
    --host=*)
        HOST="${i#*=}"
        shift
        ;;
    --ssh_host=*)
        SSH_HOST="${i#*=}"
        shift
        ;;
    --ssh_user=*)
        SSH_USER="${i#*=}"
        shift
        ;;
    --environment=*)
        ENV="${i#*=}"
        shift
        ;;
    --version=*)
        VERSION="${i#*=}"
        shift
        ;;    
    --country_config_version=*)
        COUNTRY_CONFIG_VERSION="${i#*=}"
        shift
        ;;
    --replicas=*)
        REPLICAS="${i#*=}"
        shift
        ;;    
    *) ;;

    esac
done

# Read environment variable file for the environment
# .env.qa
# .env.development
# .env.production
if [ -f .env.$environment ]
then
    export $(cat $BASEDIR/../.env.$environment | sed 's/#.*//g' | xargs)
fi

trap trapint SIGINT SIGTERM
function trapint {
    exit 0
}

print_usage_and_exit () {
    echo 'Usage: ./deploy.sh --clear_data=yes|no --host --environment --ssh_host --ssh_user --version --country_config_version --replicas'
    echo "  --clear_data must have a value of 'yes' or 'no' set e.g. --clear_data=yes"
    echo "  --environment can be 'production' or 'development' or 'qa' or 'demo'"
    echo '  --host    is the server to deploy to'
    echo "  --version can be any OpenCRVS Core docker image tag or 'latest'"
    echo "  --country_config_version can be any OpenCRVS Country Configuration docker image tag or 'latest'"
    echo "  --replicas number of supported mongo databases in your replica set.  Can be 1, 3 or 5"
    exit 1
}

if [ -z "$CLEAR_DATA" ] || { [ $CLEAR_DATA != 'no' ] && [ $CLEAR_DATA != 'yes' ] ;} ; then
    echo 'Error: Argument --clear_data is required & must be either yes or no.'
    print_usage_and_exit
fi

if [ -z "$ENV" ] ; then
    echo 'Error: Argument --environment is required.'
    print_usage_and_exit
fi

if [ -z "$HOST" ] ; then
    echo 'Error: Argument --host is required'
    print_usage_and_exit
fi

if [ -z "$VERSION" ] ; then
    echo 'Error: Argument --version is required.'
    print_usage_and_exit
fi

if [ -z "$SSH_HOST" ] ; then
    echo 'Error: Argument --ssh_host is required.'
    print_usage_and_exit
fi

if [ -z "$SSH_USER" ] ; then
    echo 'Error: Argument --ssh_user is required.'
    print_usage_and_exit
fi

if [ -z "$COUNTRY_CONFIG_VERSION" ] ; then
    echo 'Error: Argument --country_config_version is required.'
    print_usage_and_exit
fi

if [ -z "$REPLICAS" ] ; then
    echo 'Error: Argument --replicas is required in position 8.'
    print_usage_and_exit
fi

# if [ -z "$SMTP_HOST" ] ; then
#     echo 'Error: Missing environment variable SMTP_HOST.'
#     print_usage_and_exit
# fi

# if [ -z "$SMTP_PORT" ] ; then
#     echo 'Error: Missing environment variable SMTP_PORT.'
#     print_usage_and_exit
# fi

# if [ -z "$SMTP_USERNAME" ] ; then
#     echo 'Error: Missing environment variable SMTP_USERNAME.'
#     print_usage_and_exit
# fi

# if [ -z "$SMTP_PASSWORD" ] ; then
#     echo 'Error: Missing environment variable SMTP_PASSWORD.'
#     print_usage_and_exit
# fi

# if [ -z "$ALERT_EMAIL" ] ; then
#     echo 'Error: Missing environment variable ALERT_EMAIL.'
#     print_usage_and_exit
# fi

if [ -z "$KIBANA_USERNAME" ] ; then
    echo 'Error: Missing environment variable KIBANA_USERNAME.'
    print_usage_and_exit
fi

if [ -z "$KIBANA_PASSWORD" ] ; then
    echo 'Error: Missing environment variable KIBANA_PASSWORD.'
    print_usage_and_exit
fi

if [ -z "$ELASTICSEARCH_SUPERUSER_PASSWORD" ] ; then
    echo 'Error: Missing environment variable ELASTICSEARCH_SUPERUSER_PASSWORD.'
    print_usage_and_exit
fi

if [ -z "$MINIO_ROOT_USER" ] ; then
    echo 'Error: Missing environment variable MINIO_ROOT_USER.'
    print_usage_and_exit
fi

if [ -z "$MINIO_ROOT_PASSWORD" ] ; then
    echo 'Error: Missing environment variable MINIO_ROOT_PASSWORD.'
    print_usage_and_exit
fi

if [ -z "$MONGODB_ADMIN_USER" ] ; then
    echo 'Error: Missing environment variable MONGODB_ADMIN_USER.'
    print_usage_and_exit
fi

if [ -z "$MONGODB_ADMIN_PASSWORD" ] ; then
    echo 'Error: Missing environment variable MONGODB_ADMIN_PASSWORD.'
    print_usage_and_exit
fi

if [ -z "$SUPER_USER_PASSWORD" ] ; then
    echo 'Error: Missing environment variable SUPER_USER_PASSWORD.'
    print_usage_and_exit
fi

if [ -z "$DOCKERHUB_ACCOUNT" ] ; then
    echo 'Error: Missing environment variable DOCKERHUB_ACCOUNT.'
    print_usage_and_exit
fi

if [ -z "$DOCKERHUB_REPO" ] ; then
    echo 'Error: Missing environment variable DOCKERHUB_REPO.'
    print_usage_and_exit
fi

if [ -z "$CONTENT_SECURITY_POLICY_WILDCARD" ] ; then
    echo 'Error: Missing environment variable CONTENT_SECURITY_POLICY_WILDCARD.'
    print_usage_and_exit
fi

if [ -z "$DOCKER_USERNAME" ] ; then
    echo 'Error: Missing environment variable DOCKER_USERNAME.'
    print_usage_and_exit
fi

if [ -z "$SSH_KEY" ] ; then
    echo 'Error: Missing environment variable SSH_KEY.'
    print_usage_and_exit
fi

if [ -z "$DOCKER_TOKEN" ] ; then
    echo 'Error: Missing environment variable DOCKER_TOKEN.'
    print_usage_and_exit
fi

if [ -z "$KNOWN_HOSTS" ] ; then
    echo 'Error: Missing environment variable KNOWN_HOSTS.'
    print_usage_and_exit
fi

if [ -z "$SUDO_PASSWORD" ] ; then
    echo 'Info: Missing optional sudo password'
fi

if [ -z "$TOKENSEEDER_MOSIP_AUTH__PARTNER_MISP_LK" ] ; then
    echo 'Info: Missing optional MOSIP environment variable TOKENSEEDER_MOSIP_AUTH__PARTNER_MISP_LK.'
    TOKENSEEDER_MOSIP_AUTH__PARTNER_MISP_LK=''
fi

if [ -z "$TOKENSEEDER_MOSIP_AUTH__PARTNER_APIKEY" ] ; then
    echo 'Info: Missing optional MOSIP environment variable TOKENSEEDER_MOSIP_AUTH__PARTNER_APIKEY.'
    TOKENSEEDER_MOSIP_AUTH__PARTNER_APIKEY=''
fi

if [ -z "$TOKENSEEDER_CRYPTO_SIGNATURE__SIGN_P12_FILE_PASSWORD" ] ; then
    echo 'Info: Missing optional MOSIP environment variable TOKENSEEDER_CRYPTO_SIGNATURE__SIGN_P12_FILE_PASSWORD.'
    TOKENSEEDER_CRYPTO_SIGNATURE__SIGN_P12_FILE_PASSWORD=''
fi

if [ -z "$NATIONAL_ID_OIDP_CLIENT_ID" ] ; then
  echo 'Info: Missing optional National ID verification environment variable NATIONAL_ID_OIDP_CLIENT_ID'
fi

if [ -z "$NATIONAL_ID_OIDP_BASE_URL" ] ; then
  echo 'Info: Missing optional National ID verification environment variable NATIONAL_ID_OIDP_BASE_URL'
fi

if [ -z "$NATIONAL_ID_OIDP_REST_URL" ] ; then
  echo 'Info: Missing optional National ID verification environment variable NATIONAL_ID_OIDP_REST_URL'
fi

if [ -z "$NATIONAL_ID_OIDP_ESSENTIAL_CLAIMS" ] ; then
  echo 'Info: Missing optional National ID verification environment variable NATIONAL_ID_OIDP_ESSENTIAL_CLAIMS'
fi

if [ -z "$NATIONAL_ID_OIDP_VOLUNTARY_CLAIMS" ] ; then
  echo 'Info: Missing optional National ID verification environment variable NATIONAL_ID_OIDP_VOLUNTARY_CLAIMS'
fi

if [ -z "$NATIONAL_ID_OIDP_CLIENT_PRIVATE_KEY" ] ; then
  echo 'Info: Missing optional National ID verification environment variable NATIONAL_ID_OIDP_CLIENT_PRIVATE_KEY'
fi

if [ -z "$NATIONAL_ID_OIDP_JWT_AUD_CLAIM" ] ; then
  echo 'Info: Missing optional National ID verification environment variable NATIONAL_ID_OIDP_CLIENT_PRIVATE_KEY'
fi

if [ -z "$EMAIL_API_KEY" ] ; then
    echo 'Info: Missing optional environment variable EMAIL_API_KEY.'
fi

if [ -z "$SENTRY_DSN" ] ; then
    echo 'Info: Missing optional Sentry DSN environment variable SENTRY_DSN'
fi

if [ -z "$INFOBIP_GATEWAY_ENDPOINT" ] ; then
  echo 'Info: Missing optional Infobip Gateway endpoint environment variable INFOBIP_GATEWAY_ENDPOINT'
fi

if [ -z "$INFOBIP_API_KEY" ] ; then
  echo 'Info: Missing optional Infobip API Key environment variable INFOBIP_API_KEY'
fi

if [ -z "$INFOBIP_SENDER_ID" ] ; then
  echo 'Info: Missing optional Infobip Sender ID environment variable INFOBIP_SENDER_ID'
fi

if [ -z "$SENDER_EMAIL_ADDRESS" ] ; then
  echo 'Info: Missing optional return sender email address environment variable SENDER_EMAIL_ADDRESS'
fi

LOG_LOCATION=${LOG_LOCATION:-/var/log/opencrvs}

(cd /tmp/ && curl -O https://raw.githubusercontent.com/opencrvs/opencrvs-core/$VERSION/docker-compose.yml)
(cd /tmp/ && curl -O https://raw.githubusercontent.com/opencrvs/opencrvs-core/$VERSION/docker-compose.deps.yml)

COMPOSE_FILED_FROM_CORE="docker-compose.deps.yml docker-compose.yml"
COMMON_COMPOSE_FILES="$COMPOSE_FILED_FROM_CORE docker-compose.deploy.yml"

# Rotate MongoDB credentials
# https://unix.stackexchange.com/a/230676
generate_password() {
  local password=`openssl rand -base64 25 | tr -cd '[:alnum:]._-' ; echo ''`
  echo $password
}

# Create new passwords for all MongoDB users created in
# infrastructure/mongodb/docker-entrypoint-initdb.d/create-mongo-users.sh
#
# If you're adding a new MongoDB user, you'll need to also create a new update statement in
# infrastructure/mongodb/on-deploy.sh

USER_MGNT_MONGODB_PASSWORD=`generate_password`
HEARTH_MONGODB_PASSWORD=`generate_password`
CONFIG_MONGODB_PASSWORD=`generate_password`
METRICS_MONGODB_PASSWORD=`generate_password`
PERFORMANCE_MONGODB_PASSWORD=`generate_password`
OPENHIM_MONGODB_PASSWORD=`generate_password`
WEBHOOKS_MONGODB_PASSWORD=`generate_password`

#
# Elasticsearch credentials
#
# Notice that all of these passwords change on each deployment.

# Application password for OpenCRVS Search
ROTATING_SEARCH_ELASTIC_PASSWORD=`generate_password`
# If new applications require access to ElasticSearch, new passwords should be generated here.
# Remember to add the user to infrastructure/elasticsearch/setup-users.sh so it is created when you deploy.

# Used by Metricsbeat when writing data to ElasticSearch
ROTATING_METRICBEAT_ELASTIC_PASSWORD=`generate_password`

# Used by APM for writing data to ElasticSearch
ROTATING_APM_ELASTIC_PASSWORD=`generate_password`

echo
echo "Deploying VERSION $VERSION to $SSH_HOST..."
echo
echo "Deploying COUNTRY_CONFIG_VERSION $COUNTRY_CONFIG_VERSION to $SSH_HOST..."
echo

mkdir -p /tmp/opencrvs/infrastructure/cryptfs

# Copy decrypt script
cp $BASEDIR/decrypt.sh /tmp/opencrvs/infrastructure/cryptfs/decrypt.sh

# Copy emergency backup script
cp $BASEDIR/emergency-backup-metadata.sh /tmp/opencrvs/infrastructure/emergency-backup-metadata.sh

# Copy emergency restore script
cp $BASEDIR/emergency-restore-metadata.sh /tmp/opencrvs/infrastructure/emergency-restore-metadata.sh

# Copy authorized keys
cp $BASEDIR/authorized_keys /tmp/opencrvs/infrastructure/authorized_keys

# Copy metabase database
cp $PARENT_DIR/src/api/dashboards/file/metabase.init.db.sql /tmp/opencrvs/infrastructure/metabase.init.db.sql

echo -e "$SSH_KEY" > /tmp/private_key_tmp
chmod 600 /tmp/private_key_tmp
echo -e "$KNOWN_HOSTS" > /tmp/known_hosts
chmod 600 /tmp/known_hosts
# Read private ssh key from SSH_KEY environment variable, convert to a public key and append to /tmp/opencrvs/infrastructure/authorized_keys file
echo $(ssh-keygen -y -f /tmp/private_key_tmp) >> /tmp/opencrvs/infrastructure/authorized_keys

rotate_authorized_keys() {
  # file exists and has a size of more than 0 bytes
  if [ -s "/tmp/opencrvs/infrastructure/authorized_keys" ]; then
    ssh $SSH_USER@$SSH_HOST 'cat /opt/opencrvs/infrastructure/authorized_keys > ~/.ssh/authorized_keys'
  else
    echo "File /tmp/opencrvs/infrastructure/authorized_keys is empty. Did not rotate authorized keys!"
  fi
}

# Download base docker compose files to the server

rsync -e 'ssh -o UserKnownHostsFile=/tmp/known_hosts -i /tmp/private_key_tmp' -rP /tmp/docker-compose* infrastructure $SSH_USER@$SSH_HOST:/opt/opencrvs/

rsync -e 'ssh -o UserKnownHostsFile=/tmp/known_hosts -i /tmp/private_key_tmp' -rP $BASEDIR/docker-compose* infrastructure $SSH_USER@$SSH_HOST:/opt/opencrvs/

# Copy all country compose files to the server
rsync -e 'ssh -o UserKnownHostsFile=/tmp/known_hosts -i /tmp/private_key_tmp' -rP $BASEDIR/docker-compose.countryconfig* infrastructure $SSH_USER@$SSH_HOST:/opt/opencrvs/

# Override configuration files with country specific files
rsync -e 'ssh -o UserKnownHostsFile=/tmp/known_hosts -i /tmp/private_key_tmp' -rP /tmp/opencrvs/infrastructure $SSH_USER@$SSH_HOST:/opt/opencrvs

# IF USING SUDO PASSWORD, YOU MAY NEED TO ADJUST COMMANDS LIKE THIS:
# ssh $SSH_USER@$SSH_HOST "echo $SUDO_PASSWORD | sudo -S 

rotate_secrets() {
  files_to_rotate=$1
  echo "ROTATING SECRETS ON: $files_to_rotate"
  ssh $SSH_USER@$SSH_HOST '/opt/opencrvs/infrastructure/rotate-secrets.sh '$files_to_rotate' | tee -a '$LOG_LOCATION'/rotate-secrets.log'
}

# Setup configuration files and compose file for the deployment domain
ssh $SSH_USER@$SSH_HOST "SSH_USER=$SSH_USER SMTP_HOST=$SMTP_HOST SMTP_PORT=$SMTP_PORT SMTP_USERNAME=$SMTP_USERNAME SMTP_PASSWORD=$SMTP_PASSWORD ALERT_EMAIL=$ALERT_EMAIL MINIO_ROOT_USER=$MINIO_ROOT_USER MINIO_ROOT_PASSWORD=$MINIO_ROOT_PASSWORD /opt/opencrvs/infrastructure/setup-deploy-config.sh $HOST | tee -a $LOG_LOCATION/setup-deploy-config.log"

# Takes in a space separated string of docker-compose.yml files
# returns a new line separated list of images defined in those files
# This function gets a clean list of images and substitutes environment variables
# So that we have a clean list to download
get_docker_tags_from_compose_files() {
   COMPOSE_FILES=$1

   SPACE_SEPARATED_COMPOSE_FILE_LIST=$(printf " %s" "${COMPOSE_FILES[@]}")
   SPACE_SEPARATED_COMPOSE_FILE_LIST=${SPACE_SEPARATED_COMPOSE_FILE_LIST:1}

   IMAGE_TAG_LIST=$(cat $SPACE_SEPARATED_COMPOSE_FILE_LIST \
   `# Select rows with the image tag` \
   | grep image: \
   `# Only keep the image version` \
   | sed "s/image://")

   # SOME_VARIABLE:-some-default VERSION:-latest
   IMAGE_TAGS_WITH_VARIABLE_SUBSTITUTIONS_WITH_DEFAULTS=$(echo $IMAGE_TAG_LIST \
   `# Matches variables with default values like VERSION:-latest` \
   | grep -o "[A-Za-z_0-9]\+:-[A-Za-z_0-9.-]\+" \
   | sort --unique)

   # This reads Docker image tag definitions with a variable substitution
   # and defines the environment variables with the defaults unles the variable is already present.
   # Done as a preprosessing step for envsubs
   for VARIABLE_NAME_WITH_DEFAULT_VALUE in ${IMAGE_TAGS_WITH_VARIABLE_SUBSTITUTIONS_WITH_DEFAULTS[@]}; do
      IFS=':' read -r -a variable_and_default <<< "$VARIABLE_NAME_WITH_DEFAULT_VALUE"
      VARIABLE_NAME="${variable_and_default[0]}"
      # Read default value and remove the leading hyphen
      DEFAULT_VALUE=$(echo ${variable_and_default[1]} | sed "s/^-//")
      CURRENT_VALUE=$(echo "${!VARIABLE_NAME}")

      if [ -z "${!VARIABLE_NAME}" ]; then
         IMAGE_TAG_LIST=$(echo $IMAGE_TAG_LIST | sed "s/\${$VARIABLE_NAME:-$DEFAULT_VALUE}/$DEFAULT_VALUE/g")
      else
         IMAGE_TAG_LIST=$(echo $IMAGE_TAG_LIST | sed "s/\${$VARIABLE_NAME:-$DEFAULT_VALUE}/$CURRENT_VALUE/g")
      fi
   done

   IMAGE_TAG_LIST_WITHOUT_VARIABLE_SUBSTITUTION_DEFAULT_VALUES=$(echo $IMAGE_TAG_LIST \
   | sed -E "s/:-[A-Za-z_0-9]+//g" \
   | sed -E "s/[{}]//g")

   echo $IMAGE_TAG_LIST_WITHOUT_VARIABLE_SUBSTITUTION_DEFAULT_VALUES \
   | envsubst \
   | sed 's/ /\n/g'
}

split_and_join() {
   separator_for_splitting=$1
   separator_for_joining=$2
   text=$3
   SPLIT=$(echo $text | sed -e "s/$separator_for_splitting/$separator_for_joining/g")
   echo $SPLIT
}

docker_stack_deploy() {
  environment_compose=$1
  replicas_compose=$2
  echo "DEPLOYING THIS ENVIRONMENT: $environment_compose"
  echo "DEPLOYING THESE REPLICAS: $replicas_compose"

  ENVIRONMENT_COMPOSE_WITH_LOCAL_PATHS=$(echo "$environment_compose" | sed "s|docker-compose|$BASEDIR/docker-compose|g")
  REPLICAS_COMPOSE_WITH_LOCAL_PATHS=$(echo "$replicas_compose" | sed "s|docker-compose|$BASEDIR/docker-compose|g")

  CORE_COMPOSE_FILES_WITH_LOCAL_PATHS=$(echo "$COMPOSE_FILED_FROM_CORE" | sed "s|docker-compose|/tmp/docker-compose|g")
  COMMON_COMPOSE_FILES_WITH_LOCAL_PATHS="$BASEDIR/docker-compose.deploy.yml $CORE_COMPOSE_FILES_WITH_LOCAL_PATHS"

  ENV_VARIABLES="HOSTNAME=$HOST
  VERSION=$VERSION
  COUNTRY_CONFIG_VERSION=$COUNTRY_CONFIG_VERSION
  PAPERTRAIL=$PAPERTRAIL
  USER_MGNT_MONGODB_PASSWORD=$USER_MGNT_MONGODB_PASSWORD
  HEARTH_MONGODB_PASSWORD=$HEARTH_MONGODB_PASSWORD
  CONFIG_MONGODB_PASSWORD=$CONFIG_MONGODB_PASSWORD
  METRICS_MONGODB_PASSWORD=$METRICS_MONGODB_PASSWORD
  PERFORMANCE_MONGODB_PASSWORD=$PERFORMANCE_MONGODB_PASSWORD
  OPENHIM_MONGODB_PASSWORD=$OPENHIM_MONGODB_PASSWORD
  WEBHOOKS_MONGODB_PASSWORD=$WEBHOOKS_MONGODB_PASSWORD
  MONGODB_ADMIN_USER=$MONGODB_ADMIN_USER
  MONGODB_ADMIN_PASSWORD=$MONGODB_ADMIN_PASSWORD
  MINIO_ROOT_USER=$MINIO_ROOT_USER
  MINIO_ROOT_PASSWORD=$MINIO_ROOT_PASSWORD
  EMAIL_API_KEY=$EMAIL_API_KEY
  SENTRY_DSN=$SENTRY_DSN
  INFOBIP_GATEWAY_ENDPOINT=$INFOBIP_GATEWAY_ENDPOINT
  INFOBIP_API_KEY=$INFOBIP_API_KEY
  INFOBIP_SENDER_ID=$INFOBIP_SENDER_ID
  SENDER_EMAIL_ADDRESS=$SENDER_EMAIL_ADDRESS
  DOCKERHUB_ACCOUNT=$DOCKERHUB_ACCOUNT
  DOCKERHUB_REPO=$DOCKERHUB_REPO
  ELASTICSEARCH_SUPERUSER_PASSWORD=$ELASTICSEARCH_SUPERUSER_PASSWORD
  ROTATING_METRICBEAT_ELASTIC_PASSWORD=$ROTATING_METRICBEAT_ELASTIC_PASSWORD
  ROTATING_APM_ELASTIC_PASSWORD=$ROTATING_APM_ELASTIC_PASSWORD
  ROTATING_SEARCH_ELASTIC_PASSWORD=$ROTATING_SEARCH_ELASTIC_PASSWORD
  KIBANA_USERNAME=$KIBANA_USERNAME
  KIBANA_PASSWORD=$KIBANA_PASSWORD
  SUPER_USER_PASSWORD=$SUPER_USER_PASSWORD
  TOKENSEEDER_MOSIP_AUTH__PARTNER_MISP_LK=$TOKENSEEDER_MOSIP_AUTH__PARTNER_MISP_LK
  TOKENSEEDER_MOSIP_AUTH__PARTNER_APIKEY=$TOKENSEEDER_MOSIP_AUTH__PARTNER_APIKEY
  TOKENSEEDER_CRYPTO_SIGNATURE__SIGN_P12_FILE_PASSWORD=$TOKENSEEDER_CRYPTO_SIGNATURE__SIGN_P12_FILE_PASSWORD
  NATIONAL_ID_OIDP_CLIENT_ID=$NATIONAL_ID_OIDP_CLIENT_ID
  NATIONAL_ID_OIDP_BASE_URL=$NATIONAL_ID_OIDP_BASE_URL
  NATIONAL_ID_OIDP_REST_URL=$NATIONAL_ID_OIDP_REST_URL
  NATIONAL_ID_OIDP_ESSENTIAL_CLAIMS=$NATIONAL_ID_OIDP_ESSENTIAL_CLAIMS
  NATIONAL_ID_OIDP_VOLUNTARY_CLAIMS=$NATIONAL_ID_OIDP_VOLUNTARY_CLAIMS
  NATIONAL_ID_OIDP_CLIENT_PRIVATE_KEY=$NATIONAL_ID_OIDP_CLIENT_PRIVATE_KEY
  NATIONAL_ID_OIDP_JWT_AUD_CLAIM=$NATIONAL_ID_OIDP_JWT_AUD_CLAIM
  CONTENT_SECURITY_POLICY_WILDCARD=$CONTENT_SECURITY_POLICY_WILDCARD"

  echo "Pulling all docker images. This might take a while"

  EXISTING_IMAGES=$(ssh $SSH_USER@$SSH_HOST "docker images --format '{{.Repository}}:{{.Tag}}'")
  IMAGE_TAGS_TO_DOWNLOAD=$(get_docker_tags_from_compose_files "$COMMON_COMPOSE_FILES_WITH_LOCAL_PATHS $ENVIRONMENT_COMPOSE_WITH_LOCAL_PATHS $REPLICAS_COMPOSE_WITH_LOCAL_PATHS")

  for tag in ${IMAGE_TAGS_TO_DOWNLOAD[@]}; do
    if [[ $EXISTING_IMAGES == *"$tag"* ]]; then
      echo "$tag already exists on the machine. Skipping..."
      continue
    fi

    echo "Downloading $tag"

    until ssh $SSH_USER@$SSH_HOST "cd /opt/opencrvs && docker pull $tag"
    do
      echo "Server failed to download $tag. Retrying..."
      sleep 5
    done
  done

  echo "Updating docker swarm stack with new compose files"
  ssh $SSH_USER@$SSH_HOST 'cd /opt/opencrvs && \
    '$ENV_VARIABLES' docker stack deploy --prune -c '$(split_and_join " " " -c " "$COMMON_COMPOSE_FILES $environment_compose $replicas_compose")' --with-registry-auth opencrvs'
}

FILES_TO_ROTATE="/opt/opencrvs/docker-compose.deploy.yml"

if [ "$REPLICAS" = "3" ]; then
  REPLICAS_COMPOSE="docker-compose.replicas-3.yml docker-compose.countryconfig.replicas-3.yml"
  FILES_TO_ROTATE="${FILES_TO_ROTATE} /opt/opencrvs/docker-compose.replicas-3.yml"
elif [ "$REPLICAS" = "5" ]; then
  REPLICAS_COMPOSE="docker-compose.replicas-5.yml docker-compose.countryconfig.replicas-5.yml"
  FILES_TO_ROTATE="${FILES_TO_ROTATE} /opt/opencrvs/docker-compose.replicas-5.yml"
elif [ "$REPLICAS" = "1" ]; then
  REPLICAS_COMPOSE="docker-compose.countryconfig.replicas-1.yml"
else
  echo "Unknown error running docker-compose on server as REPLICAS is not 1, 3 or 5."
  exit 1
fi

# Deploy the OpenCRVS stack onto the swarm
if [[ "$ENV" = "staging" ]]; then
  ENVIRONMENT_COMPOSE="docker-compose.countryconfig.staging-deploy.yml docker-compose.staging-deploy.yml"
  FILES_TO_ROTATE="${FILES_TO_ROTATE} /opt/opencrvs/docker-compose.countryconfig.staging-deploy.yml /opt/opencrvs/docker-compose.staging-deploy.yml"
elif [[ "$ENV" = "qa" ]]; then
  ENVIRONMENT_COMPOSE="docker-compose.countryconfig.qa-deploy.yml docker-compose.qa-deploy.yml"
  FILES_TO_ROTATE="${FILES_TO_ROTATE} /opt/opencrvs/docker-compose.countryconfig.qa-deploy.yml /opt/opencrvs/docker-compose.qa-deploy.yml"
elif [[ "$ENV" = "production" ]]; then
  ENVIRONMENT_COMPOSE="docker-compose.countryconfig.prod-deploy.yml docker-compose.prod-deploy.yml docker-compose.dci.yml"
  FILES_TO_ROTATE="${FILES_TO_ROTATE} /opt/opencrvs/docker-compose.countryconfig.prod-deploy.yml /opt/opencrvs/docker-compose.prod-deploy.yml /opt/opencrvs/docker-compose.dci.yml"
elif [[ "$ENV" = "demo" ]]; then
  ENVIRONMENT_COMPOSE="docker-compose.countryconfig.demo-deploy.yml docker-compose.prod-deploy.yml"
  FILES_TO_ROTATE="${FILES_TO_ROTATE} /opt/opencrvs/docker-compose.countryconfig.demo-deploy.yml /opt/opencrvs/docker-compose.prod-deploy.yml"
else
  echo "Unknown error running docker-compose on server as ENV is not staging, qa, demo or production."
  exit 1
fi

rotate_secrets "$FILES_TO_ROTATE"
rotate_authorized_keys
docker_stack_deploy "$ENVIRONMENT_COMPOSE" "$REPLICAS_COMPOSE"

echo
echo "This script doesnt ensure that all docker containers successfully start, just that docker_stack_deploy ran successfully."
echo
echo "Waiting 2 mins for mongo to deploy before working with data. Please note it can take up to 10 minutes for the entire stack to deploy in some scenarios."
echo
sleep 120


if [ $CLEAR_DATA == "yes" ] ; then
    echo
    echo "Clearing all existing data..."
    echo
    ssh $SSH_USER@$SSH_HOST "
        ELASTICSEARCH_ADMIN_USER=elastic \
        ELASTICSEARCH_ADMIN_PASSWORD=$ELASTICSEARCH_SUPERUSER_PASSWORD \
        MONGODB_ADMIN_USER=$MONGODB_ADMIN_USER \
        MONGODB_ADMIN_PASSWORD=$MONGODB_ADMIN_PASSWORD \
        /opt/opencrvs/infrastructure/clear-all-data.sh $REPLICAS"

    echo
    echo "Running migrations..."
    echo
    ssh $SSH_USER@$SSH_HOST "
        ELASTICSEARCH_ADMIN_USER=elastic \
        ELASTICSEARCH_ADMIN_PASSWORD=$ELASTICSEARCH_SUPERUSER_PASSWORD \
        /opt/opencrvs/infrastructure/run-migrations.sh"
fi

# echo "Setting up Kibana config & alerts"

# while true; do
#   if ssh $SSH_USER@$SSH_HOST "ELASTICSEARCH_SUPERUSER_PASSWORD=$ELASTICSEARCH_SUPERUSER_PASSWORD HOST=kibana.$HOST /opt/opencrvs/infrastructure/monitoring/kibana/setup-config.sh"; then
#     break
#   fi
# sleep 5
# done