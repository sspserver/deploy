#!/bin/bash

REPLICATED=${REPLICATED:-false}
PREFIX_REPLACE=${PREFIX:-'s/${RDB_PREFIX}//g'}

if [[ "$REPLICATED" == "true" ]]; then
  PREFIX_REPLACE='s/${RDB_PREFIX}/Replicated/g'
fi

apply_migrations() {
  FILE=/state/clickhouse-$2
  if [[ -e $FILE ]]; then
    echo 'Already applied!'
  else
    for file in $1/*.up.sql; do
        if [[ "$REPLICATED" == "true" ]] && [[ "$file" == *.noreplicated.* ]]; then
          continue
        fi
        if [[ "$REPLICATED" == "false" ]] && [[ "$file" == *.replicated.* ]]; then
          continue
        fi
        if [ -n "$file" ] && [ -e "$file" ]; then
          echo "$file"
        fi
        if [[ -n "$3" ]]; then
          sed -e "$3" "$file" | clickhouse-client --host clickhouse-server
        else
          clickhouse-client --host clickhouse-server --queries-file $file
        fi
    done
    touch $FILE
  fi
}

apply_migrations /migrations migrations $PREFIX_REPLACE
# apply_migrations /migrations-gen migrations-gen
