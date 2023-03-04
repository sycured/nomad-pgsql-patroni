#!/bin/bash
KEY_FILE=$PGDATA/pgsodium_root.key

if [ ! -f "$KEY_FILE" ]; then
    echo "$PGSODIUM_KEY" > $PGDATA/pgsodium_root.key
fi
cat $KEY_FILE
