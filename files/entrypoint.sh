#!/usr/bin/env bash

KEY_FILE=/alloc/pgdata/pgsodium_root

if [ ! -f "$KEY_FILE".key ]; then
    echo "$PGSODIUM_KEY" > $KEY_FILE.key
fi

echo "cat $KEY_FILE.key" > $KEY_FILE.sh
chmod +x $KEY_FILE.sh

exec /usr/bin/patroni /secrets/config.yml