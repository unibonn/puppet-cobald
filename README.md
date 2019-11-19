# puppet-cobald

#### Table of Contents

1. [Description](#description)
1. [Usage - Configuration options and additional functionality](#usage)
1. [Limitations](#limitations)

## Description

The module allows to install and configure a [COBalD](https://cobald.readthedocs.io) and [TARDIS](https://cobald-tardis.readthedocs.io) service to manage opportunistic resources.

## Usage

Here is an example how to use this module:

```
class { 'cobald':
  cobald_version             => 'master',
  tardis_version             => 'master',
  auth_lbs                   => 'krb5',
  filename_cobald_keytab     => "${module_name}/cobald/cobald-cobald.mytier3.edu.keytab",
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
  cobald_conf                 => $mytier3_cobald_conf,
  tardis_conf                 => $mytier3_tardis_conf,
  supported_vos               => ['atlas', 'belle'],
  additional_pilot_attributes => {
    '+ContainerOS'  => 'CentOS7_pilot',
  },
}
```

## Limitations

This module has only been tested on CentOS 7 so far.
