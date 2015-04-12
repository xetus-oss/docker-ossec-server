#!/bin/bash

#
# Initialize the custom data directory layout
#
source /data_dirs.env

cd /var/ossec
for ossecdir in "${DATA_DIRS[@]}"; do
  mv ${ossecdir} ${ossecdir}-template
  ln -s data/${ossecdir} ${ossecdir}
done

cd bin && ln -s ../data/process_list .process_list && cd ..

