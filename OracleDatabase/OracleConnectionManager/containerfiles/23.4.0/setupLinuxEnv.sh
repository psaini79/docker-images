#!/bin/bash
# LICENSE UPL 1.0
#
# Copyright (c) 1982-2024 Oracle and/or its affiliates. All rights reserved.
#
# Since: April, 2024
# Author: aditya.x.jain@oracle.com
# Description: Sets up the unix environment to use oci yum instead of public yum.
# 
# DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS HEADER.
# 

## Use OCI yum repos on OCI instead of public yum
region=$(curl --noproxy '*' -sfm 3 -H "Authorization: Bearer Oracle" http://169.254.169.254/opc/v2/instance/ | sed -nE 's/^ *"regionIdentifier": "([^"]+)".*/\1/p')
if [ -n "$region" ]; then 
    echo "Detected OCI Region: $region"
    for proxy in $(printenv | grep -i _proxy | cut -d= -f1); do unset $proxy; done
    echo "-$region" > /etc/yum/vars/ociregion
fi 