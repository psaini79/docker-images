#!/bin/bash
# LICENSE UPL 1.0
#
# Copyright (c) 2024 Oracle and/or its affiliates. All rights reserved.
#
# Since: Apr, 2024
# Author:ishaan.desai@oracle.com
#
# DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS HEADER.
#

AUTO_TRUE_CACHE_SETUP=${AUTO_TRUE_CACHE_SETUP:-true}
if [[ "${AUTO_TRUE_CACHE_SETUP}" == "true" &&  "${TRUE_CACHE}" == "true" ]]; then
 export TRUE_CACHE_BLOB=$("$ORACLE_BASE"/"$SETUPTC")
fi
