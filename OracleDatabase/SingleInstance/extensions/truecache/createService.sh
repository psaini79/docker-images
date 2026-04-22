#!/bin/bash
# LICENSE UPL 1.0
#
# Copyright (c) 2024 Oracle and/or its affiliates. All rights reserved.
#
# Since: Apr, 2024
# Author:paramdeep.saini@oracle.com
#
# DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS HEADER.
#

if [ $# -ne 6 ]; then
   echo "Usage : <$0> <PRIMARY_SVCNAME> <TC_SVCNAME> <PRIMARY_PDB_NAME> <TC_CONNECT_STR> <SOURCE_DB> <DECRYPT_PWD_FILE>"
   exit 1
fi

PRIMARY_SVCNAME=$1
TC_SVCNAME=$2
PRIMARY_PDB_NAME=$3
TC_CONNECT_STR=$4
SOURCE_DB=$5
DECRYPT_PWD_FILE=$6

PASSWORD=$($DECRYPT_PWD_FILE)

/opt/oracle/product/*/*/bin/dbca -silent -configureDatabase -configureTrueCacheInstanceService -sourceDB "${SOURCE_DB}" -trueCacheConnectString "${TC_CONNECT_STR}" -trueCacheServiceName "${TC_SVCNAME}" -serviceName "${PRIMARY_SVCNAME}" -pdbName "${PRIMARY_PDB_NAME}"  <<< "${PASSWORD}"
