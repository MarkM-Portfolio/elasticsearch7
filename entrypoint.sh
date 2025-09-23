#!/bin/bash

#change permission
LAUNCHPOINT=/opt/elasticsearch-${ES_VERSION}/run_es.sh
chown -R esuser:esgroup ${LAUNCHPOINT}
chmod -R 700 ${LAUNCHPOINT}

echo "elasticsearch user information is:"
echo `id esuser`

#support memory_lock feature in elasticsearch
ulimit -l unlimited

#start as esuser
exec gosu esuser:esgroup ${LAUNCHPOINT}
