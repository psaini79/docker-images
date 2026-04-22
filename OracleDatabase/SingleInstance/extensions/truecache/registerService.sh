#!/bin/bash
# LICENSE UPL 1.0
#
# Copyright (c) 2024 Oracle and/or its affiliates. All rights reserved.
#
# Since: April, 2024
# Author:ishaan.desai@oracle.com
#
# DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS HEADER.
#

declare -x ORACLE_PWD
declare -x ORACLE_SID
declare -x PRIMARY_DB_CONNECT_STR
declare -x PRIMARY_PDB_CONNECT_STR
declare -x PRIMARY_DB_HOST
declare -x PRIMARY_DB_PORT
declare -x PRIMARY_DB_NAME
declare -x PRIMARY_PDB_NAME
declare -x DEBUG="TRUE"
declare -x pdbExists
declare -x tcInstanceCreated

export NOW=$(date +"%Y%m%d%H%M")
export TMP_LOC=${TMP_LOC:-"/var/tmp"}
export PRIMARY_DB_USER=${PRIMARY_DB_USER:-"sys as sysdba"}
export DB_PWD_FILE=${DB_PWD_FILE:-"oracle_pwd"}
export PWD_KEY=${PWD_KEY:-"oracle_pwd_privkey"}
export LOGDIR=${LOGDIR:-"/var/tmp"}
export LOGFILE="${LOGDIR}/tc_${NOW}.log"
export STD_OUT_FILE="/proc/1/fd/1"
export ORADATA="/opt/oracle/oradata"
export STD_ERR_FILE="/proc/1/fd/2"
declare -x SECRET_VOLUME='/run/secrets'      ## Secret Volume
export TOP_PID=$$
rm -f $LOGFILE

#################################### Print and Exit Functions Begin Here #######################

function error_exit {
 local NOW=$(date +"%m-%d-%Y %T %Z")
 echo "${NOW} : ${PROGNAME}: ${1:-"Unknown Error"}" | tee -a $LOGFILE > $STD_OUT_FILE
 kill -s TERM $TOP_PID
}

function print_message {
   local NOW=$(date +"%m-%d-%Y %T %Z")
   # Display  message and return
   echo "${NOW} : ${PROGNAME} : ${1:-"Unknown Message"}" | tee -a $LOGFILE > $STD_OUT_FILE
   return $?
}

#################################### Print and Exit Functions End Here #######################

# Function to delete a file
function delFile {
   local file_name=$1
   if [ -f "${file_name}" ]; then
      if [ "${DEBUG}" != "TRUE" ]; then
         rm -f "${file_name}"
      else
         print_message "delFile() : fname=[${file_name}]"
      fi
   fi
}

# Function to execute a sql script or sql query on a database
function getSQLOUTPUT {
  local sql_query=$1
  local connect_str=$2
  local type=$3
  local sql_script=$4
  local output
  if [ -z "${sql_query}" ]; then
    print_message "Empty sql_query passed to sqlplus. Operation Failed"
  fi

  if [ -z "${connect_str}" ]; then
      error_exit "Empty connect_str passed to sqlplus. Operation Failed"
  fi

  if [ -z "${type}" ]; then
      type='notSet'
  fi

  if [ -z "${sql_script}" ]; then
    sql_script='notSet'
  fi


  if  [ "${type}" == "sqlScript" ] && [ -f "${sql_script}" ]; then
    print_message "Executing sql script using connect string"
    output=$( "$ORACLE_HOME"/bin/sqlplus -s "$connect_str" << EOF | tee -a "$LOGFILE"
        set heading off verify off echo off PAGESIZE 0
        @$sql_script
        exit
EOF
)
  else
  output=$( "$ORACLE_HOME"/bin/sqlplus -s "${connect_str}" <<EOF
        set heading off feedback off verify off echo off PAGESIZE 0
        $sql_query
        exit
EOF
)
  fi
  echo  "${output}"
}

# Function to set the connect string to the primary database
function setConnectStr {
  read user priv <<< ${PRIMARY_DB_USER}
  local db_connect_str="${user}/${ORACLE_PWD}@${PRIMARY_DB_HOST}:${PRIMARY_DB_PORT}/${PRIMARY_DB_NAME} ${priv}"
  local pdb_connect_str="${user}/${ORACLE_PWD}@${PRIMARY_DB_HOST}:${PRIMARY_DB_PORT}/${PRIMARY_PDB_NAME} ${priv}"
  PRIMARY_DB_CONNECT_STR=${db_connect_str}
  PRIMARY_PDB_CONNECT_STR=${pdb_connect_str}
}

# Function to execute the remote truecache service creation file on the primary database
function executeRemoteTCSvcFile {

  local file_name
  local sql_file
  local connect_str
  local job_name
  local tc_connect_str
  local primary_source_db_name

  file_name=$1
  sql_file=$2
  connect_str=${PRIMARY_PDB_CONNECT_STR}
  job_name="bjob$(cat /dev/urandom | tr -dc '[:alpha:]' | fold -w 7 | head -n 1)$time_stamp"
  HOST_NAME=${ORACLE_HOSTNAME:-$(hostname)}
  tc_connect_str="$HOST_NAME:1521/${ORACLE_SID}"
  primary_source_db_name=${PRIMARY_DB_NAME}

  #### Execute the TCSvc-Remote file
  local sproc3="begin
          dbms_scheduler.create_job (job_name    => '${job_name}',
              job_type    => 'executable',
              job_action  => '${file_name}',
              number_of_arguments => 6,
              auto_drop   => TRUE);
          dbms_scheduler.set_job_argument_value(job_name => '${job_name}', argument_position => 1, argument_value => '${PRIMARY_DB_APP_SVC}');
          dbms_scheduler.set_job_argument_value(job_name => '${job_name}', argument_position => 2, argument_value => '${TRUE_CACHE_DB_APP_SVC}');
          dbms_scheduler.set_job_argument_value(job_name => '${job_name}', argument_position => 3, argument_value => '${PRIMARY_PDB_NAME}');
          dbms_scheduler.set_job_argument_value(job_name => '${job_name}', argument_position => 4, argument_value => '${tc_connect_str}');
          dbms_scheduler.set_job_argument_value(job_name => '${job_name}', argument_position => 5, argument_value => '${primary_source_db_name}');
          dbms_scheduler.set_job_argument_value(job_name => '${job_name}', argument_position => 6, argument_value => '${ORACLE_BASE}/${DECRYPT_PWD_FILE}');
          dbms_scheduler.run_job(job_name => '${job_name}',USE_CURRENT_SESSION => TRUE);
          end;
          /
  exec SYS.DBMS_SCHEDULER.DROP_JOB (job_name =>'${job_name}')
  "

  print_message "Executing shell script ${file_name} on primary database machine"
  echo "${sproc3}" > $sql_file
  output=$(getSQLOUTPUT "NULL" "${connect_str}" "sqlScript" "${sql_file}")
  print_message "Received Output: $output"

  delFile "${sql_file}"
}

# Function to create the primary service
function createPrimarySvc {
  if [ ! -z "${PRIMARY_DB_APP_SVC}" ]; then
    PRIMARY_DB_APP_SVC=${PRIMARY_DB_APP_SVC^^}
    local connect_str
    local output
    sql_query_1="SELECT name FROM ALL_SERVICES WHERE upper(name)='${PRIMARY_DB_APP_SVC}';"
    connect_str=${PRIMARY_PDB_CONNECT_STR}
    output=$(getSQLOUTPUT "${sql_query_1}" "${connect_str}")

    print_message "checking if the service exists"
    if [ "${output}" == "${PRIMARY_DB_APP_SVC}" ]; then
      print_message "Service ${PRIMARY_DB_APP_SVC} already exist on Primary"
    else
      local sql_query_1
      local sql_query_2
      local output1
      local output2
      sql_query_1="SELECT name FROM ALL_SERVICES WHERE upper(name)='${PRIMARY_DB_APP_SVC}';"
      sql_query_2="exec DBMS_SERVICE.CREATE_SERVICE('${PRIMARY_DB_APP_SVC}', '${PRIMARY_DB_APP_SVC}');"
      print_message "creating the primary service on the primary database container"
      output2=$( getSQLOUTPUT "${sql_query_2}" "${connect_str}")
      output1=$(getSQLOUTPUT "${sql_query_1}" "${connect_str}")
      if [ "${output1}" == "${PRIMARY_DB_APP_SVC}" ]; then
        print_message "Service ${PRIMARY_DB_APP_SVC} created on Primary"
      else
        print_message "Service ${PRIMARY_DB_APP_SVC} could NOT be created on Primary"
        print_message output2
      fi
    fi
  fi
}

# Start the Primary db service
function startSvc {
  local connect_str
  connect_str=${PRIMARY_PDB_CONNECT_STR}

  if [ ! -z "${PRIMARY_DB_APP_SVC}" ]; then
    PRIMARY_DB_APP_SVC=${PRIMARY_DB_APP_SVC^^}
    local sql_query
    local output
    sqlquery1="exec DBMS_SERVICE.START_SERVICE('${PRIMARY_DB_APP_SVC}');"
    output2=$( getSQLOUTPUT "${sqlquery1}" "${connect_str}")
  fi

  if [ ! -z "${TRUE_CACHE_DB_APP_SVC}" ]; then
    TRUE_CACHE_DB_APP_SVC=${TRUE_CACHE_DB_APP_SVC^^}
    local sql_query
    local output
    sqlquery2="exec DBMS_SERVICE.START_SERVICE('${TRUE_CACHE_DB_APP_SVC}');"
    output=$( getSQLOUTPUT "${sqlquery2}" "${connect_str}")
  fi
}

# Function to create the True Cache service
# shellcheck disable=SC2120
function createTCSvc {
  if [ ! -z "${TRUE_CACHE_DB_APP_SVC}" ]; then
    TRUE_CACHE_DB_APP_SVC=${TRUE_CACHE_DB_APP_SVC^^}
    executeRemoteTCSvcFile "${ORACLE_BASE}/${CREATE_TC_SVCS_SCRIPT}" "${TMP_LOC}/tc_svc_sqlquery.sql"
  fi
}

# Function to check the True Cache service
function checkTCSvc {
  TRUE_CACHE_DB_APP_SVC=${TRUE_CACHE_DB_APP_SVC^^}
  PRIMARY_DB_APP_SVC=${PRIMARY_DB_APP_SVC^^}
  local sql_query
  local connect_str
  local output
  sql_query="SELECT true_cache_service FROM ALL_SERVICES WHERE upper(name)='${PRIMARY_DB_APP_SVC}';"
  connect_str=${PRIMARY_PDB_CONNECT_STR}
  output=$( getSQLOUTPUT "${sql_query}" "${connect_str}")

  if [ "${output}" == "${TRUE_CACHE_DB_APP_SVC}" ]; then
    print_message "True Cache Service ${TRUE_CACHE_DB_APP_SVC} is asociated with primary service ${PRIMARY_DB_APP_SVC}."
  else
    print_message "True Cache Service ${TRUE_CACHE_DB_APP_SVC} is not asociated with primary service ${PRIMARY_DB_APP_SVC}. Exiting.."
  fi
}

# Check if the given pdb exists on the primary database
function checkPDBExists {
  local pdb_name
  local sql_query
  local connect_str
  local output
  pdb_name=$1
  sql_query="SELECT open_mode FROM v\$pdbs WHERE name='${pdb_name}';"
  connect_str="${PRIMARY_DB_CONNECT_STR}"

  output=$( getSQLOUTPUT "${sql_query}" "${connect_str}")

  echo "OPEN_MODE output=[$output]"

  if [ "${output}" == "READ WRITE" ]; then
      pdbExists="1"
  else
      pdbExists="0"
  fi
}

#####################################
#####  MAIN #########################
#####################################

AUTO_TRUE_CACHE_SETUP=${AUTO_TRUE_CACHE_SETUP:-true}
if [[ "${AUTO_TRUE_CACHE_SETUP}" == "true" &&  "${TRUE_CACHE}" == "true" ]]; then
  PRIMARY_DB_HOST=$(echo "$PRIMARY_DB_CONN_STR" | cut -d ':' -f1)
  PRIMARY_DB_PORT=$(echo "$PRIMARY_DB_CONN_STR" | cut -d ":" -f2 | cut -d '/' -f1)
  PRIMARY_DB_NAME=$(echo "$PRIMARY_DB_CONN_STR" | cut -d '/' -f2)

  ORACLE_PWD=$($ORACLE_BASE/$DECRYPT_PWD_FILE)
  PDB_TC_SVCS_STR=`echo ${PDB_TC_SVCS} | sed -e 's/.*?=\(.*\)/\1/g'`
  print_message "PDB_TC_SVCS_STR=${PDB_TC_SVCS_STR}"
  IFS=';' read  -a PDB_TC_VALUES <<< "${PDB_TC_SVCS_STR}"
  print_message "# of PDB_TC_VALUES=${#PDB_TC_VALUES[@]}"
  for PDB_TC_VALUE in "${PDB_TC_VALUES[@]}"
  do
    IFS=':' read PDB_NAME PRIMARY_SVC_NAME TC_SVC_NAME <<< "${PDB_TC_VALUE}"
    if [ "${PDB_NAME}" == "" -o "${PRIMARY_SVC_NAME}" == "" -o "${TC_SVC_NAME}" == "" ]; then
      error_exit "Bad service mapping [${PRIMARY_SVC_NAME}:${TC_SVC_NAME}] for db [${PDB_NAME}]. Ignoring"
      continue
    fi
      export PRIMARY_DB_APP_SVC=${PRIMARY_SVC_NAME}
      export TRUE_CACHE_DB_APP_SVC=${TC_SVC_NAME}
      export PRIMARY_PDB_NAME=${PDB_NAME}

      print_message "setting connect str for pdb ${PRIMARY_PDB_NAME}"
      setConnectStr
      print_message "validate if the ${PDB_NAME} pdb exists"
      checkPDBExists "${PDB_NAME}"
      if [ "${pdbExists}" == "0" ]; then
            echo "The PDB ${PDB_NAME} does not exist. Ignoring"
            continue
      fi
      print_message "creating ${PRIMARY_DB_APP_SVC} on the primary container database"
      createPrimarySvc
      print_message "creating ${TRUE_CACHE_DB_APP_SVC} on the truecache container database"
      createTCSvc
      startSvc
      checkTCSvc
  done
fi
