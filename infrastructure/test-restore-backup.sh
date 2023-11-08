# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# OpenCRVS is also distributed under the terms of the Civil Registration
# & Healthcare Disclaimer located at http://opencrvs.org/license.
#
# Copyright (C) The OpenCRVS Authors located at https://github.com/opencrvs/opencrvs-core/blob/master/AUTHORS.

#------------------------------------------------------------------------------------------------------------------
# THIS SCRIPT RUNS FROM A GITHUB ACTION TO TEST RESTORE A BACKUP ONTO A QA SERVER AS A REGULAR MONITORING EXERCISE
#------------------------------------------------------------------------------------------------------------------

# Uncomment if your SSH user is not root
#
#if [ -z "$SUDO_PASSWORD" ] ; then
#    echo 'Error: Missing environment variable SUDO_PASSWORD.'
#   exit 1
#fi

if [ -z "$SSH_USER" ] ; then
    echo 'Error: Missing environment variable SSH_USER.'
    exit 1
fi

if [ -z "$SSH_HOST" ] ; then
    echo 'Error: Missing environment variable SSH_HOST.'
    exit 1
fi

if [ -z "$BACKUP_HOST" ] ; then
    echo 'Error: Missing environment variable BACKUP_HOST.'
    exit 1
fi

if [ -z "$BACKUP_DIRECTORY" ] ; then
    echo 'Error: Missing environment variable BACKUP_DIRECTORY.'
    exit 1
fi

if [ -z "$RESTORE_DIRECTORY" ] ; then
    echo 'Error: Missing environment variable RESTORE_DIRECTORY.'
    exit 1
fi

if [ -z "$REPLICAS" ] ; then
    echo 'Error: Missing environment variable REPLICAS.'
    exit 1
fi

if [ -z "$QA_BACKUP_LABEL" ] ; then
    echo 'Error: Missing environment variable QA_BACKUP_LABEL.'
    exit 1
fi

if [[ $REVERTING == "no" && -z "$PROD_BACKUP_LABEL" ]] ; then
    echo 'Error: Missing environment variable PROD_BACKUP_LABEL when restoring a production backup.'
    exit 1
fi

if [ -z "$REVERTING" ] ; then
    echo 'Error: Missing environment variable REVERTING.'
    exit 1
fi

if [ $REVERTING == "no" ] ; then
    # Backup QA environment first
    ssh "$SSH_USER@$SSH_HOST" "echo $SUDO_PASSWORD | sudo -S bash /opt/opencrvs/infrastructure/emergency-backup-metadata.sh --ssh_user=$SSH_USER --ssh_host=$BACKUP_HOST --ssh_port=22 --production_ip=$SSH_HOST --remote_dir=$BACKUP_DIRECTORY/qa --replicas=$REPLICAS --label=$QA_BACKUP_LABEL"
    LABEL="$PROD_BACKUP_LABEL"
    REMOTE_DIR="$BACKUP_DIRECTORY/$LABEL"
else
    LABEL="$QA_BACKUP_LABEL"
    REMOTE_DIR="$BACKUP_DIRECTORY/qa/$LABEL"
fi

# Copy production backup into restore folder
ssh "$SSH_USER@$SSH_HOST" "rm -rf $RESTORE_DIRECTORY/elasticsearch"
ssh "$SSH_USER@$SSH_HOST" "rm -rf $RESTORE_DIRECTORY/elasticsearch/indices"
ssh "$SSH_USER@$SSH_HOST" "rm -rf $RESTORE_DIRECTORY/influxdb"
ssh "$SSH_USER@$SSH_HOST" "rm -rf $RESTORE_DIRECTORY/mongo"
ssh "$SSH_USER@$SSH_HOST" "rm -rf $RESTORE_DIRECTORY/minio"
ssh "$SSH_USER@$SSH_HOST" "rm -rf $RESTORE_DIRECTORY/metabase"
ssh "$SSH_USER@$SSH_HOST" "rm -rf $RESTORE_DIRECTORY/vsexport"
ssh "$SSH_USER@$SSH_HOST" "rm -rf $RESTORE_DIRECTORY/metabase"

ssh "$SSH_USER@$SSH_HOST" "rsync -av --delete --progress $SSH_USER@$BACKUP_HOST:$REMOTE_DIR/elasticsearch $RESTORE_DIRECTORY"
ssh "$SSH_USER@$SSH_HOST" "rsync -av --delete --progress $SSH_USER@$BACKUP_HOST:$REMOTE_DIR/mongo/hearth-dev-$LABEL.gz $RESTORE_DIRECTORY/mongo/"
ssh "$SSH_USER@$SSH_HOST" "rsync -av --delete --progress $SSH_USER@$BACKUP_HOST:$REMOTE_DIR/mongo/openhim-dev-$LABEL.gz $RESTORE_DIRECTORY/mongo/"
ssh "$SSH_USER@$SSH_HOST" "rsync -av --delete --progress $SSH_USER@$BACKUP_HOST:$REMOTE_DIR/mongo/user-mgnt-$LABEL.gz $RESTORE_DIRECTORY/mongo/"
ssh "$SSH_USER@$SSH_HOST" "rsync -av --delete --progress $SSH_USER@$BACKUP_HOST:$REMOTE_DIR/mongo/application-config-$LABEL.gz $RESTORE_DIRECTORY/mongo/"
ssh "$SSH_USER@$SSH_HOST" "rsync -av --delete --progress $SSH_USER@$BACKUP_HOST:$REMOTE_DIR/mongo/metrics-$LABEL.gz $RESTORE_DIRECTORY/mongo/"
ssh "$SSH_USER@$SSH_HOST" "rsync -av --delete --progress $SSH_USER@$BACKUP_HOST:$REMOTE_DIR/mongo/webhooks-$LABEL.gz $RESTORE_DIRECTORY/mongo/"
ssh "$SSH_USER@$SSH_HOST" "rsync -av --delete --progress $SSH_USER@$BACKUP_HOST:$REMOTE_DIR/mongo/performance-$LABEL.gz $RESTORE_DIRECTORY/mongo/"
ssh "$SSH_USER@$SSH_HOST" "rsync -av --delete --progress $SSH_USER@$BACKUP_HOST:$REMOTE_DIR/influxdb/$LABEL $RESTORE_DIRECTORY/influxdb"
ssh "$SSH_USER@$SSH_HOST" "rsync -av --delete --progress $SSH_USER@$BACKUP_HOST:$REMOTE_DIR/minio/ocrvs-$LABEL.tar.gz $RESTORE_DIRECTORY/minio/"
ssh "$SSH_USER@$SSH_HOST" "rsync -av --delete --progress $SSH_USER@$BACKUP_HOST:$REMOTE_DIR/metabase/ocrvs-$LABEL.tar.gz $RESTORE_DIRECTORY/metabase/"
ssh "$SSH_USER@$SSH_HOST" "rsync -av --delete --progress $SSH_USER@$BACKUP_HOST:$REMOTE_DIR/vsexport/ocrvs-$LABEL.tar.gz $RESTORE_DIRECTORY/vsexport/"

# Restore
echo "Restoring"
# Uncomment if your SSH user is not root
#
# ssh "$SSH_USER@$SSH_HOST" "echo $SUDO_PASSWORD | sudo -S rm -rf /data/backups/elasticsearch && mv $RESTORE_DIRECTORY/elasticsearch /data/backups/"
# else 
ssh "$SSH_USER@$SSH_HOST" "rm -rf /data/backups/elasticsearch && mv $RESTORE_DIRECTORY/elasticsearch /data/backups/"

ssh "$SSH_USER@$SSH_HOST" "docker service update --force --update-parallelism 1 --update-delay 30s opencrvs_elasticsearch"
echo "Waiting 2 mins for elasticsearch to restart."
echo
sleep 120
# Uncomment if your SSH user is not root
#
# ssh "$SSH_USER@$SSH_HOST" "echo $SUDO_PASSWORD | sudo -S bash /opt/opencrvs/infrastructure/emergency-restore-metadata.sh --label=$LABEL --replicas=$REPLICAS --backup-dir=$RESTORE_DIRECTORY"
# else 
ssh "/opt/opencrvs/infrastructure/emergency-restore-metadata.sh --label=$LABEL --replicas=$REPLICAS --backup-dir=$RESTORE_DIRECTORY"