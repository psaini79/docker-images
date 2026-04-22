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

if [ $# -ne 3 ]; then
   echo "Usage : <$0> <BLOBDIR> <SOURCE_DB> <DECRYPT_PWD_FILE>"
   exit 1
fi

BLOBDIR=$1
SOURCE_DB=$2
DECRYPT_PWD_FILE=$3

mkdir -p ${BLOBDIR}

PASSWORD=$($DECRYPT_PWD_FILE)
/opt/oracle/product/*/*/bin/dbca -silent -configureDatabase -prepareTrueCacheInstanceBlob -trueCacheBlobLocation "${BLOBDIR}" -sourceDB "${SOURCE_DB}"  <<< "${PASSWORD}" > ${BLOBDIR}/..//genBlobdbca.out
/bin/mv ${BLOBDIR}/*.tar.gz ${BLOBDIR}/blobTestData.tar.gz
