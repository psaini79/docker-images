# LICENSE UPL 1.0
#
# Copyright (c) 2024 Oracle and/or its affiliates. All rights reserved.
#
# ORACLE DOCKERFILES PROJECT
# --------------------------
# This is the Dockerfile for Oracle Database with Fast Fail Over support
#
# REQUIREMETNS FOR THIS IMAGE
# ----------------------------------
# Any release of prebuilt oracle/database base docker image
#
# HOW TO BUILD THIS IMAGE
# -----------------------
#
# Run:
#      $ docker build -t <extended_image_name> . --build-arg BASE_IMAGE=oracle/database:23.26.0-ee
#

USER oracle
ARG BASE_IMAGE_VERSION=23.26.0
ARG BASE_IMAGE=oracle/database:${BASE_IMAGE_VERSION}-ee

# Creating another stage for sharding extension creation
FROM ${BASE_IMAGE}

# Extn name
ARG EXTENSION_NAME=truecache
ENV CRYPTOGRAPHY_OPENSSL_NO_LEGACY=1

# Environment variables required for this build (do NOT change)
# -------------------------------------------------------------
ENV  SETUPTC="setup.sh" \
     BLOBREADER="blobReader.py" \
     CREATE_TC_SVCS_SCRIPT="createService.sh" \
     CREATE_BLOB_SCRIPT="createBlob.sh" \
     REGISTER_TC_SVCS_SCRIPT="registerService.sh"

# backup original runOracle
RUN if test -e "$ORACLE_BASE/$RUN_FILE.orig"; then EXTN='extended'; else EXTN='orig'; fi ; \
    mv "$ORACLE_BASE/$RUN_FILE" "$ORACLE_BASE/$RUN_FILE.$EXTN"

# Copy updated scripts for TC support
COPY --chown=oracle:dba $RUNFILE $SETUPTC $BLOBREADER $CREATE_TC_SVCS_SCRIPT $CREATE_BLOB_SCRIPT $ORACLE_BASE/
RUN   mv "$ORACLE_BASE/$RUN_FILE" "$ORACLE_BASE/$RUN_FILE.$EXTENSION_NAME" 
COPY  --chown=oracle:dba $REGISTER_TC_SVCS_SCRIPT $ORACLE_BASE/scripts/extensions/setup/

# Set perms and append a call to main runOracle
RUN if test -e "$ORACLE_BASE/$RUN_FILE.extended"; then \
        mv "$ORACLE_BASE/$RUN_FILE.extended" "$ORACLE_BASE/$RUN_FILE" ; \
    else echo ". $ORACLE_BASE/$RUN_FILE.orig" > "$ORACLE_BASE/$RUN_FILE" ; fi ; \
    if ! grep "$RUN_FILE.$EXTENSION_NAME" "$ORACLE_BASE/$RUN_FILE"; then \
        sed  -i "1i . $ORACLE_BASE/$RUN_FILE.$EXTENSION_NAME" "$ORACLE_BASE/$RUN_FILE"; \
    fi && \
    chmod ug+x "$ORACLE_BASE"/*.sh && sync
