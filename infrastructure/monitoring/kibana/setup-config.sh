# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# OpenCRVS is also distributed under the terms of the Civil Registration
# & Healthcare Disclaimer located at http://opencrvs.org/license.
#
# Copyright (C) The OpenCRVS Authors located at https://github.com/opencrvs/opencrvs-core/blob/master/AUTHORS.

set -e
curl --insecure --connect-timeout 60 -u elastic:${ELASTICSEARCH_SUPERUSER_PASSWORD} -X POST https://$HOST/api/saved_objects/_import?overwrite=true -H 'kbn-xsrf: true' --form file=@/opt/opencrvs/infrastructure/monitoring/kibana/config.ndjson > /dev/null

curl --insecure --connect-timeout 60 -u elastic:${ELASTICSEARCH_SUPERUSER_PASSWORD} \
https://$HOST/api/alerting/rules/_find\?page\=1\&per_page\=100\&default_search_operator\=AND\&sort_field\=name\&sort_order\=asc | \
jq -r '.data[].id' | \
while read -r id; do
  echo "$id";
  curl --insecure --connect-timeout 60 -X POST -H 'kbn-xsrf: true' -u elastic:${ELASTICSEARCH_SUPERUSER_PASSWORD} "https://$HOST/api/alerting/rule/$id/_disable"
  curl --insecure --connect-timeout 60 -X POST -H 'kbn-xsrf: true' -u elastic:${ELASTICSEARCH_SUPERUSER_PASSWORD} "https://$HOST/api/alerting/rule/$id/_enable"
done