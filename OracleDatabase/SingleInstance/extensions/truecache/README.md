# True Cache Database Extension

This extension extends [the base Oracle Single Instance Database image](../../README.md) in such a way that the resultant image would automate the steps needed to setup the True Cache database for the primary database; this includes creating the database blob file on the primary database and then copying from primary database container to True Cache container. So, when a container is started using this extended image, no manual steps needed to be done for setting up True Cache.

**NOTE:** This extension supports Oracle Single Instance Database container image from version 23ai onwards.

## Advantages

This extended image includes:

- the automation for creation and copying of blob file from the primary database container to True Cache container
- the automation for setting up of working True Cache Deployment which can be used with an Application

## Prerequisites for Running Oracle Truecache on Podman

### Section 1 : Prerequisites for Running Oracle Truecache on Podman

 You must install and configure [Podman release 4.2.0](https://docs.oracle.com/en/operating-systems/oracle-linux/Podman/) or later on Oracle Linux 8.7 or later to run Oracle Truecache on Podman.

### Section 2: Build SIDB Container Image

To build Oracle TrueCache on container, you need to download and build [Oracle 23ai Database image](../../README.md), please refer README.MD of Oracle Single Database available on Oracle OraHub repository.

**Note:** You just need to create the image as per the instructions given in README.MD but you will create the container as per the steps given in this document under [Deploy Containers for True Cache Setup](#deploy-containers-for-true-cache-setup) section.

#### Create Extended Oracle Database Image with TrueCache  Feature

After creating the base image using buildContainerImage.sh in the previous step, use buildExtensions.sh present under the extensions folder `<GIT_CLONED_DIR>/docker-images/OracleDatabase/SingleInstance/extensions` to build an extended image that will include the truecache Feature. Please execute following step:

- Build truecache extension image as shown below:
For example:

```bash
./buildExtensions.sh -x truecache -b oracle/database:23.26.0-ee -t oracle/database-ext-truecache:23.26.0-ee 

Where:
"-x truecache"                                 is to specify to have truecache feature in the extended image
"-b oracle/database:23.26.0-ee"                is to specify the Base image created in previous step
"oracle/database-ext-truecache:23.26.0-ee"     is to specify the name:tag for the extended image with truecache Feature
```

## Running Oracle True Cache Container Database

### Create Network Bridge

Before creating a container, create the podman network by creating podman network bridge based on your enviornment. If you are using the bridge name with the network subnet mentioned in this README.md then you can use the same IPs mentioned in Create Containers section.

If primary database is not running on same host as truecache db, you must use `macvlan` or `ipvlan` bridge to conect to the primary database.

#### Macvlan Bridge

```bash
# podman network create -d macvlan --subnet=172.20.1.0/24 --gateway=172.20.1.1 -o parent=eth0 truecache_pub1_n
```

#### Ipvlan Bridge

```bash
# podman network create -d ipvlan --subnet=172.20.1.0/24 --gateway=172.20.1.1 -o parent=eth0 truecache_pub1_n
```

If you are planning to create a test env within a single machine, you can use a podman bridge but these IPs will not be reachable on the user network.

#### Bridge

```bash
# podman network create --driver=bridge --subnet=172.20.1.0/24 truecache_pub1_n
```

**Note:** You can change subnet and choose one of the above mentioned podman network bridge based on your enviornment.

#### Setup Hostfile

**Note:** You can skip this step of creating a Hostfile when you are using a DNS for the IP resolution.
**Note:** You can also `skip` this step of creating a Hostfile when you are using `--add-host` option while creating the Podman Containers.

All containers will share a host file for name resolution.  The shared hostfile must be available to all containers. Create the empty shared host file (if it doesn't exist) at `/opt/containers/truecache_host_file`:

For example:

```bash
mkdir -p /opt/containers
rm -rf /opt/containers/truecache_host_file && touch /opt/containers/truecache_host_file'
```

Add the following host entries in `/opt/containers/truecache_host_file` as Oracle Database Containers do not have root access to modify the /etc/hosts file. This file must be pre-populated. You can change these entries based on your environment and network setup.

```text
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
172.20.1.2      prod.example.com prod
172.20.1.98     truedb.example.com truedb
172.20.1.125    appclient.example.com appclient
```

**NOTE:** In this example, entry "prod.example.com" is for the host for Primary Database Container, "truedb.example.com" is for the host for True Cache DB Container and "appclient.example.com" is for a host for an Application Container (in case you want to configure an application container).

### Password Management

When using this extension the database password must be specified as a secret to both the Primary and True Cache containers and not in the environment.

- Specify the secret volume for resetting database users password during catalog and shard setup. It can be a shared volume among all the containers

```bash
mkdir /opt/.secrets/
cd /opt/.secrets
openssl genrsa -out key.pem
openssl rsa -in key.pem -out key.pub -pubout
```

- Edit the `/opt/.secrets/pwdfile.txt` and seed the password. It will be a common password for all the database users. Execute following command:

```bash
vi /opt/.secrets/pwdfile.txt
```

**Note**: Enter your secure password in the above file and save the file.

- After seeding password and saving the `/opt/.secrets/pwdfile.txt` file, execute following command:

```bash
openssl pkeyutl -in /opt/.secrets/pwdfile.txt -out /opt/.secrets/pwdfile.enc -pubin -inkey /opt/.secrets/key.pub -encrypt
rm -rf /opt/.secrets/pwdfile.txt

```

We recommend using Podman secrets to be used inside the containers. Execute the following command to create podman secrets:

```bash
podman secret create oracle_pwd /opt/.secrets/pwdfile.enc
podman secret create oracle_pwd_privkey /opt/.secrets/key.pem

podman secret ls
ID                         NAME        DRIVER      CREATED        UPDATED
547eed65c01d525bc2b4cebd9  keysecret   file        8 seconds ago  8 seconds ago
8ad6e8e519c26e9234dbcf60a  pwdsecret   file        8 seconds ago  8 seconds ago
```

## SELinux Configuration on Podman Host

To run Podman containers in an environment with SELinux enabled, you must configure an SELinux policy for the containers. To check if your SELinux is enabled or not, run the `getenforce` command.
With Security-Enhanced Linux (SELinux), you must set a policy to implement permissions for your containers. If you do not configure a policy module for your containers, then they can end up restarting indefinitely or other permission errors. You must add all Podman host nodes for your cluster to the policy module `shard-podman`, by installing the necessary packages and creating a type enforcement file (designated by the .te suffix) to build the policy, and load it into the system.

In the following example, the Podman host `podman-host` is configured in the SELinux policy module `tc-podman`:

Copy [tc-podman.te](./tc-podman.te) to `/var/opt` folder in your host and then execute below-

```bash
cd /var/opt
make -f /usr/share/selinux/devel/Makefile tc-podman.pp
semodule -i tc-podman.pp
semodule -l | grep tc-podman
```

### Create Directory

You need to create mountpoint on the podman host to save datafiles for Primary Database and the Oracle True Cache Database. These directories will be exposed as a volume to the containers. This volume can be local on a podman host or exposed from your central storage. It contains a file system such as EXT4. During the setup of this sample True Cache Database Deployment, we used below directories and exposed as volume to the correcponding container.

```bash
mkdir -p /oradata/trueCache/prod
chown -R 54321:54321 /oradata/trueCache/prod

mkdir -p /oradata/trueCache/truedb
chown -R 54321:54321 /oradata/trueCache/truedb
```

- If SELinux is enabled on podman host, then execute following:

```bash
semanage fcontext -a -t container_file_t /oradata/trueCache/prod
restorecon -v /oradata/trueCache/prod

semanage fcontext -a -t container_file_t /oradata/trueCache/truedb
restorecon -v /oradata/trueCache/truedb
```

- If you are creating a Hostfile named `/opt/containers/truecache_host_file`, then complete the below step as well:

```bash
semanage fcontext -a -t container_file_t /opt/containers/truecache_host_file
restorecon -v /opt/containers/truecache_host_file
```

## Deploy Containers for True Cache Setup

### Deploying the Primary Container Database

Use the following command to deploy the Primary Database Container (named "prod" in this case):

```bash
podman run -d --name prod --hostname prod  --ip 172.20.1.2 \
--net=truecache_pub1_n \
--secret=oracle_pwd \
--secret=oracle_pwd_privkey \
--add-host="truedb:172.20.1.98" \
--add-host="appclient:172.20.1.125" \
--dns-search=example.com \    
-e DOMAIN=example.com \
-e ENABLE_ARCHIVELOG=true \
-e ENABLE_FORCE_LOGGING=true \
-v /oradata/trueCache/prod:/opt/oracle/oradata \
oracle/database-ext-truecache:23.26.0-ee
```

**NOTE:** In case you want to use the Hostfile named `/opt/containers/truecache_host_file` to mount as `/etc/hosts` inside the containers for name resolution, then you can remove the lines with option `--add-host` from the above command and use the option `-v /opt/containers/truecache_host_file:/etc/hosts \`.

Once deployed, monitor the logs for the Primary Database Container (i.e. "prod" in this case) using the below command:

```bash
podman logs -f prod
```

The following lines will highlight when the Primary Database is ready for use:

```bash
#########################
DATABASE IS READY TO USE!
#########################
```

### Depolying the TrueCache Container Database

Use the following command to deploy the True Cache Database Container (named "truedb" in this case):

```bash
podman run -d --name truedb \
--ip 172.20.1.98 \
--net truecache_pub1_n \
--secret=oracle_pwd \
--secret=oracle_pwd_privkey \
--hostname truedb \    
--add-host="prod:172.20.1.2" \
--add-host="appclient:172.20.1.125" \
--dns-search=example.com \    
-e DOMAIN=example.com \    
-e ORACLE_SID=truedb \
-e PRIMARY_DB_CONN_STR=prod:1521/ORCLCDB \
-e AUTO_TRUE_CACHE_SETUP="true" \
-e TRUE_CACHE=true \
-e TRUEDB_UNIQUE_NAME=truedb \
-e PDB_TC_SVCS="ORCLPDB1:sales1:sales1_tc;ORCLPDB1:sales2:sales2_tc;ORCLPDB1:sales3:sales3_tc;ORCLPDB1:sales4:sales4_tc" \
-v /oradata/trueCache/truedb:/opt/oracle/oradata \
oracle/database-ext-truecache:23.26.0-ee
```

**NOTE:** In above command, the list of Primary and True Cache services are mentioned using the string "ORCLPDB1:sales1:sales1_tc;ORCLPDB1:sales2:sales2_tc;ORCLPDB1:sales3:sales3_tc;ORCLPDB1:sales4:sales4_tc"

The string consists of multiple entries in the format "<PDB_NAME>:<PRIMARY_SERVICE_NAME>:<TRUECACHE_SERVICE_NAME>" and these entries are separated by ";".

**NOTE:** In case you want to use the Hostfile named `/opt/containers/truecache_host_file` to mount as `/etc/hosts` inside the containers for name resolution, then you can remove the lines with option `--add-host` from the above command and use the option `-v /opt/containers/truecache_host_file:/etc/hosts \`.

The following lines will highlight when the True Cache Database is ready for use:

```bash
#########################
DATABASE IS READY TO USE!
#########################
```

**Note:** In the logs of "truedb" container, the above message will be followed by message confirming the True Cache Services.

### Check Setup

Login to TrueCache container:

```bash
podman exec -i -t truedb /bin/bash
```

Check the Truecache setup at the database level using below:

```bash
sqlplus "/as sysdba" << EOF
    select database_name,open_mode,database_role from v$database ;
EOF
```

Sample Output for a working Truecache setup for above SQL query:

```bash
SQL> select database_name,open_mode,database_role from v$database ;
 
DATABASE_NAME             OPEN_MODE            DATABASE_ROLE
------------------------- -------------------- ----------------
ORCLCDB                   READ ONLY WITH APPLY TRUE CACHE
```

## Environment Variables Explained

**For Truecache Container:**

| Parameter                  | Description                                                                                                                     | Mandatory/Optional |
|----------------------------|---------------------------------------------------------------------------------------------------------------------------------|--------------------|
| DOMAIN                     | Use this parameter to specify the Domain Name                                                                                   | Mandatory          |
| ORACLE_SID                 | DB_NAME for the True Cache Database                                                                                             | Mandatory          |
| TRUEDB_UNIQUE_NAME         | DB_UNIQUE_NAME for the True Cache Database                                                                                      | Mandatory          |
| PRIMARY_DB_CONN_STR        | Primary DB Connection string in format "hostname:Port/Primary CDB Name"                                                         | Mandatory          |
| AUTO_TRUE_CACHE_SETUP      | Paramter to specify for automatic setup of True Cache.                                                                          | Mandatory          |
| TRUE_CACHE                 | Parameter to specify that its an Truecache Host                                                                                 | Mandatory          |
| PDB_TC_SVCS                | Parameter to specify multiple semi colon seperated strings in format "Primary PDB:Primary Service Name:Truecache Service Name"  | Mandatory          |

## Support

Oracle True Cache is supported from version 23ai and later releases.

## License

To download and run Oracle True Cache, regardless whether inside or outside a Container, ensure to download the binaries from the Oracle website and accept the license indicated at that page.

All scripts and files hosted in this project docker-images/OracleDatabase repository required to build the Docker and Podman images are, unless otherwise noted, released under UPL 1.0 license.

## Copyright

Copyright (c) 2022 - 2024 Oracle and/or its affiliates.
Released under the Universal Permissive License v1.0 as shown at [https://oss.oracle.com/licenses/upl/](https://oss.oracle.com/licenses/upl/)
