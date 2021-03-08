# puppet-cobald

#### Table of Contents

1. [Description](#description)
1. [Usage - Configuration options and additional functionality](#usage)
1. [Limitations](#limitations)

## Description

The module allows to install and configure a [COBalD](https://cobald.readthedocs.io) and [TARDIS](https://cobald-tardis.readthedocs.io) service to manage opportunistic resources.

## Parameters

##### `cobald_version` [`String`]
COBalD version to be used. Possible values are `undef` = latest PyPI release, `'master'` = Github master branch or the PyPI release number.

##### `tardis_version` [`String`]
TARDIS version to be used. Possible values are `undef` = latest PyPI release, `'master'` = Github master branch or the PyPI release number.

##### `auth_lbs` [`Optional[Enum['krb5', 'ssh']]`]
Authentication method used by local batch system (LBS).

##### `filename_cobald_keytab` [`String`]
COBalD service principal keytab file name (if LBS uses Kerberos authentication).

##### `ssh_hostname` [`String`]
hostname of host to access LBS (if ssh authentication is used to access LBS)

##### `ssh_username` [`String`]
user name to be used for ssh access to LBS (if ssh authentication is used to access LBS)

##### `ssh_pubhostkey` [`String`]
public ssh host key (if ssh authentication is used to access LBS)

##### `ssh_hostkeytype` [`String`]
encryption type of ssh host key (if ssh authentication is used to access LBS)

##### `ssh_privkey_filename` [`String`]
file name of ssh private key used to access LBS (if ssh authentication is used to access LBS)

##### `ssh_keytype` [`Enum['dsa', 'ecdsa', 'ed25519', 'rsa']`]
type of ssh key used to access LBS (if ssh authentication is used to access LBS)

##### `ssh_perform_output_cleanup` [`Boolean`]
Whether to perform cleanup of job output files via SSH to ssh_hostname once per day.

##### `output_cleanup_pattern` [`String`]
Pattern of files to delete when `ssh_perform_output_cleanup` is enabled.

##### `auth_obs` [`Optional[Enum['gsi']]`]
Authentication method used by overlay batch system (OBS).

##### `manage_cas` [`Boolean`]
Should this module manage Certificate Authorities (CAs) (including CRLs).

##### `ca_repo_url` [`String`]
Repository URL from which to fetch CAs.

##### `ca_packages` [`Array[String]`]
Array containing names of CA packages.

##### `filename_cobald_robot_key` [`String`]
COBalD robot key file name (if OBS uses GSI authentication).

##### `filename_cobald_robot_cert` [`String`]
COBalD robot certificate file name (if OBS uses GSI authentication).

##### `zabbix_monitor_robotcert` [`Boolean`]
Add a Zabbix parameter (`robotcert.expiration_days`) to monitor the validity of the COBalD robot certificate (if OBS uses GSI authentication). Defaults to `false` to keep Zabbix an optional dependency.

##### `gsi_daemon_dns` [`Array[String]`]
Array of distringuished names (DNs) to be added to HTCondor variable `GSI_DAEMON_NAME`.


### COBalD instance parameters

##### `additional_pilot_attributes` [`Hash[String,String]`]
Hash of additional ClassAd attributes to add to the pilot JDL. Only useful for the HTCondor LBS.
Note that the value of the has is passed as-is, i.e. for string values, they need to be enquoted.
This allows to also pass ClassAd expressions if wanted.


## Usage

Here is an example how to use this module:

```
class { 'cobald':
  cobald_version             => 'master',
  tardis_version             => 'master',
#  auth_lbs                   => ['krb5', 'ssh'],
  auth_lbs                   => ['krb5'],
  filename_cobald_keytab     => "${module_name}/cobald/cobald-cobald.mytier3.edu.keytab",
#  ssh_hostname               => 'myremotetier3.edu',
#  ssh_username               => 'cobald',
#  ssh_pubhostkey             => 'SomeLongStringOfGibberish',
#  ssh_hostkeytype            => 'ecdsa-sha2-nistp256',
#  ssh_privkey_filename       => "${module_name}/cobald/sshkeys/cobald@myremotetier3.edu",
#  ssh_keytype                => 'ed25519',
  auth_obs                   => 'gsi',
  manage_cas                 => true,
  filename_cobald_robot_key  => "${module_name}/cobald/robotcert/cobald-robot-key.pem",
  filename_cobald_robot_cert => "${module_name}/cobald/robotcert/cobald-robot-cert.pem",
  gsi_daemon_dns             => [
                                  '/C=DE/O=GermanGrid/OU=mytier1/CN=htcondor.mytier1.edu',
                                  '/C=DE/O=GermanGrid/OU=mytier1/CN=arc.mytier1.edu',
                                  '/C=DE/O=GermanGrid/OU=mytier3/CN=Robot - My COBalD TARDIS Drone Service',
                             ],
  }

$mytier3_cobald_conf = {
  'pipeline' => [
    {
      '__type__'        => 'cobald.controller.linear.LinearController',
      # if min(cpu_ratio, memory_ratio) drops below given value, nodes are drained
      'low_utilisation' => 0.75,
      # if max(cpu_ratio, memory_ratio) exceeds given value, nodes are spawned
      'high_allocation' => 0.8,
      # rate (cores/second) to increase or reduce cores
      'rate'            => 1,
    },
    {
      '__type__' => 'cobald.decorator.limiter.Limiter',
      # leave at least one core
      'minimum'  => 1,
    },
    {
      '__type__' => 'cobald.decorator.logger.Logger',
      'name'     => 'changes',
    },
    {
      '__type__'      => 'tardis.resources.poolfactory.create_composite_pool',
      'configuration' => '/etc/cobald/mytier3/tardis.yml',
    },
  ],
  'logging' => {
    'version'    => 1,
    'root'       => {
      'level'    => 'DEBUG',
      'handlers' => ['console', 'file'],
    },
    'formatters' => {
      'precise'   => {
        'format'   => '%(name)s: %(asctime)s %(message)s',
        'datefmt'  => '%Y-%m-%d %H:%M:%S',
      }
    },
    'handlers'    => {
      'console'    => {
        'class'     => 'logging.StreamHandler',
        'formatter' => 'precise',
        'stream'    => 'ext://sys.stdout',
      },
      'file'       => {
        'class'       => 'logging.handlers.RotatingFileHandler',
        'formatter'   => 'precise',
        'filename'    => '/var/log/cobald/mytier3/tardis.log',
        'maxBytes'    => 10485760,
        'backupCount' => 3,
      }
    }
  },
}

$mytier3_tardis_conf = {
  'Plugins'     => {
    'SqliteRegistry'        => {
      'db_file'       => '/var/lib/cobald/mytier3/drone_registry.db',
    }
  },
  'BatchSystem' => {
    'adapter'    => 'HTCondor',
    # cache condor_status output for 1 minute
    'max_age'    => 1,
    # used to calculate utilisation and allocation
    'ratios'     => {
      # relative used CPU number
      'cpu_ratio'    => 'Real(TotalSlotCpus-Cpus)/TotalSlotCpus',
      # relative used memory
      'memory_ratio' => 'Real(TotalSlotMemory-Memory)/TotalSlotMemory',
      # average CPU usage, note the comment below!
      'cpu_usage'    => 'IfThenElse(AverageCPUsUsage=?=undefined, 0, Real(AverageCPUsUsage))',
    },
    'options' => {
      'pool' => 'htcondor.mytier1.edu',
    },
  },
  'Sites' => [
    {
      'name'    => 'SITE-NAME',
      'adapter' => 'HTCondor',
      # max. number of offered CPUs
      'quota'   => 5,
    },
  ],
  'SITE-NAME' => {
    # cache condor_q output for 1 minute
    'max_age'                  => 1,
    'MachineTypes'             => [
      'atlas_singlecore',
      'atlas_eightcore',
    ],
    'MachineTypeConfiguration' => {
      'atlas_singlecore' => {
        'jdl' => '/etc/cobald/mytier3/atlas-pilot.jdl',
      },
      'atlas_eightcore'      => {
        'jdl' => '/etc/cobald/mytier3/atlas-pilot.jdl',
      },
      'belle_singlecore'      => {
        'jdl' => '/etc/cobald/mytier3/belle-pilot.jdl',
      },
      'belle_eightcore'      => {
        'jdl' => '/etc/cobald/mytier3/belle-pilot.jdl',
      },
      'MachineMetaData'      => {
        'atlas_singlecore     => {
          'Cores'  => 1,
          'Memory' => 2.5,
          'Disk'   => 20,
        },
        'atlas_eightcore'     => {
          'Cores'   => 8,
          'Memory'  => 14,
          'Disk'    => 160,
        },
        'belle_singlecore'    => {
          'Cores'   => 1,
          'Memory'  => 2.5,
          'Disk'    => 20,
        },
        'belle_eightcore'     => {
          'Cores'   => 8,
          'Memory'  => 20,
          'Disk'    => 160,
        },
      },
    },
  },
}

cobald::instance { 'mytier3':
  ensure                      => 'present',
  activate_service            => true,
  cobald_conf                 => $mytier3_cobald_conf,
  tardis_conf                 => $mytier3_tardis_conf,
  supported_vos               => ['atlas', 'belle'],
  additional_pilot_attributes => {
    '+ContainerOS'  => '"CentOS7_pilot"',
    '+CephFS_IO'    => '"none"',
  },
  pilot_logs_keep_time        => '14d',
}
```

### Special notes on the example
Please note the the `cpu_usage` ratio specified for the HTCondor example provided above relies on this HTCondor configuration:
```
STARTD_PARTITIONABLE_SLOT_ATTRS = $(STARTD_PARTITIONABLE_SLOT_ATTRS), CPUsUsage
AverageCPUsUsage = Sum(My.ChildCPUsUsage)/Sum(My.ChildCPUs)
STARTD_ATTRS = $(STARTD_ATTRS), AverageCPUsUsage
```
This collects the CPU usage of the partitioned child slots into the `STARTD` so it can be queried directly.


## Limitations

This module has only been tested on CentOS 7 and CentOS 8 so far.
