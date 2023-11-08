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
# This cron job is already configured in the Ansible playbook.yml in the infrastructure > server-setup directory.
# Change SSH connection settings and IPs to suit your deployment, and re-run the Ansible script to update.
# A label string i.e. 'v1.0.1' can also be provided to the script to be appended to the filenames
#------------------------------------------------------------------------------------------------------------------
set -e

print_usage_and_exit() {
  echo 'Usage: ./backup-check.sh with environment variables'
  echo "Script will check if a backup has been successfully created for the given label"
  exit 1
}


if [ -z "$SSH_USER" ]; then
    echo 'Error: Missing environment variable SSH_USER.'
    print_usage_and_exit
fi
if [ -z "$SSH_HOST" ]; then
    echo 'Error: Missing environment variable SSH_HOST.'
    print_usage_and_exit
fi
if [ -z "$REMOTE_DIR" ]; then
    echo 'Error: Missing environment variable REMOTE_DIR.'
    print_usage_and_exit
fi
if [ -z "$LABEL" ]; then
    echo 'Error: Missing environment variable LABEL.'
    print_usage_and_exit
fi

REMOTE_DIR="$REMOTE_DIR/${LABEL}"

REMOTE_HEARTH_BACKUP=$REMOTE_DIR/mongo/hearth-dev-${LABEL}.gz
REMOTE_OPENHIM_BACKUP=$REMOTE_DIR/mongo/openhim-dev-${LABEL}.gz
REMOTE_USER_MGNT_BACKUP=$REMOTE_DIR/mongo/user-mgnt-${LABEL}.gz
REMOTE_APP_CONFIG_BACKUP=$REMOTE_DIR/mongo/application-config-${LABEL}.gz
REMOTE_METRICS_BACKUP=$REMOTE_DIR/mongo/metrics-${LABEL}.gz
REMOTE_WEBHOOKS_BACKUP=$REMOTE_DIR/mongo/webhooks-${LABEL}.gz
REMOTE_PERFORMANCE_BACKUP=$REMOTE_DIR/mongo/performance-${LABEL}.gz
REMOTE_MINIO_BACKUP=$REMOTE_DIR/minio/ocrvs-${LABEL}.tar.gz
REMOTE_METABASE_BACKUP=$REMOTE_DIR/metabase/ocrvs-${LABEL}.tar.gz
REMOTE_VSEXPORT_BACKUP=$REMOTE_DIR/vsexport/ocrvs-${LABEL}.tar.gz


# SSH into the remote server and check if the files exist
ssh "$SSH_USER@$SSH_HOST" "[ -e '$REMOTE_HEARTH_BACKUP' ] && echo '$REMOTE_HEARTH_BACKUP exists' || echo '$REMOTE_HEARTH_BACKUP does not exist'"
ssh "$SSH_USER@$SSH_HOST" "[ -e '$REMOTE_OPENHIM_BACKUP' ] && echo '$REMOTE_OPENHIM_BACKUP exists' || echo '$REMOTE_OPENHIM_BACKUP does not exist'"
ssh "$SSH_USER@$SSH_HOST" "[ -e '$REMOTE_USER_MGNT_BACKUP' ] && echo '$REMOTE_USER_MGNT_BACKUP exists' || echo '$REMOTE_USER_MGNT_BACKUP does not exist'"
ssh "$SSH_USER@$SSH_HOST" "[ -e '$REMOTE_APP_CONFIG_BACKUP' ] && echo '$REMOTE_APP_CONFIG_BACKUP exists' || echo '$REMOTE_APP_CONFIG_BACKUP does not exist'"
ssh "$SSH_USER@$SSH_HOST" "[ -e '$REMOTE_METRICS_BACKUP' ] && echo '$REMOTE_METRICS_BACKUP exists' || echo '$REMOTE_METRICS_BACKUP does not exist'"
ssh "$SSH_USER@$SSH_HOST" "[ -e '$REMOTE_WEBHOOKS_BACKUP' ] && echo '$REMOTE_WEBHOOKS_BACKUP exists' || echo '$REMOTE_WEBHOOKS_BACKUP does not exist'"
ssh "$SSH_USER@$SSH_HOST" "[ -e '$REMOTE_PERFORMANCE_BACKUP' ] && echo '$REMOTE_PERFORMANCE_BACKUP exists' || echo '$REMOTE_PERFORMANCE_BACKUP does not exist'"
ssh "$SSH_USER@$SSH_HOST" "[ -e '$REMOTE_METABASE_BACKUP' ] && echo '$REMOTE_METABASE_BACKUP exists' || echo '$REMOTE_METABASE_BACKUP does not exist'"
ssh "$SSH_USER@$SSH_HOST" "[ -e '$REMOTE_MINIO_BACKUP' ] && echo '$REMOTE_MINIO_BACKUP exists' || echo '$REMOTE_MINIO_BACKUP does not exist'"
echo 'VSExport backup will only exist 1 month after go live date:'
ssh "$SSH_USER@$SSH_HOST" "[ -e '$REMOTE_VSEXPORT_BACKUP' ] && echo '$REMOTE_VSEXPORT_BACKUP exists' || echo '$REMOTE_VSEXPORT_BACKUP does not exist'"
