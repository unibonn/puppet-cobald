# Resource type: cobald::instance
# ===============================
#
# Puppet resource type to run an instance of a COBalD/TARDIS service.
#
# Authors
# -------
#
# Peter Wienemann <peter.wienemann@uni-bonn.de>
#
# Copyright
# ---------
#
# Copyright 2019-2020 University of Bonn
#
define cobald::instance(
  Enum['present', 'absent']   $ensure                      = 'present',
  Boolean                     $activate_service            = true,
  Hash                        $cobald_conf                 = undef,
  Hash                        $tardis_conf                 = undef,
  Array[String]               $supported_vos               = [],         # only needed for HTCondor LBS with local submission
  Hash[String, String]        $additional_pilot_attributes = {},         # only makes sense for HTCondor LBS with local submission
  String                      $pilot_logs_keep_time        = '14d',
) {

  $dir_ensure = $ensure ? {
    'present' => 'directory',
    default   => $ensure,
  }

  # Ensure log directory for this instance exists
  file { "/var/log/cobald/${name}":
    ensure   => $dir_ensure,
    mode     => '0755',
    owner    => 'cobald',
    group    => 'cobald',
    seluser  => 'system_u',
    selrole  => 'object_r',
    seltype  => 'var_log_t',
    selrange => 's0',
  }

  # Create a place to store pilot logs
  file { "/var/log/cobald/${name}/pilots":
    ensure   => $dir_ensure,
    mode     => '0755',
    owner    => 'cobald',
    group    => 'cobald',
    seluser  => 'system_u',
    selrole  => 'object_r',
    seltype  => 'var_log_t',
    selrange => 's0',
  }

  # Cleanup old pilot logs.
  systemd::tmpfile { "cobald-${name}-pilot-logs.conf":
    content => "d /var/log/cobald/${name}/pilots 0755 cobald cobald ${pilot_logs_keep_time}",
    require => File["/var/log/cobald/${name}/pilots"],
  }

  # Ensure directory for drone registry exists.
  file { "/var/lib/cobald/${name}":
    ensure   => 'directory',
    mode     => '0755',
    owner    => 'cobald',
    group    => 'cobald',
    seluser  => 'system_u',
    selrole  => 'object_r',
    seltype  => 'var_lib_t',
    selrange => 's0',
  }

  # Create a place to store instance configuration
  file { "/etc/cobald/${name}":
    ensure   => $dir_ensure,
    mode     => '0755',
    owner    => 'cobald',
    group    => 'cobald',
    seluser  => 'system_u',
    selrole  => 'object_r',
    seltype  => 'etc_t',
    selrange => 's0',
  }

  file { "/etc/cobald/${name}/cobald.yml":
    ensure   => $ensure,
    content  => inline_template('<%= require "yaml"; @cobald_conf.to_yaml %>'),
    mode     => '0644',
    owner    => 'root',
    group    => 'root',
    seluser  => 'system_u',
    selrole  => 'object_r',
    seltype  => 'etc_t',
    selrange => 's0',
    notify   => Service["cobald@${name}"],
  }

  file { "/etc/cobald/${name}/tardis.yml":
    content  => inline_template('<%= require "yaml"; @tardis_conf.to_yaml %>'),
    mode     => '0644',
    owner    => 'root',
    group    => 'root',
    seluser  => 'system_u',
    selrole  => 'object_r',
    seltype  => 'etc_t',
    selrange => 's0',
    notify   => Service["cobald@${name}"],
  }

  $supported_vos.each |String $vo| {
    file { "/etc/cobald/${name}/${vo}-pilot.jdl":
      content  => epp("${module_name}/pilot.jdl.epp",
          {
            'instance_name'         => $name,
            'vo'                    => $vo,
            'additional_attributes' => $additional_pilot_attributes,
          }
        ),
      mode     => '0644',
      owner    => 'root',
      group    => 'root',
      seluser  => 'system_u',
      selrole  => 'object_r',
      seltype  => 'etc_t',
      selrange => 's0',
    }
  }

  service { "cobald@${name}":
    ensure  => bool2str($activate_service, 'running', 'stopped'),
    enable  => $activate_service,
    # Makes use of the VirtualEnv, runs as user cobald
    require => [
      User['cobald'],
      Systemd::Unit_file['cobald@.service'],
      Python::Pip['cobald'],
      Python::Pip['cobald-tardis'],
      File['/var/lib/cobald'],
      File["/var/log/cobald/${name}"],
      File["/etc/cobald/${name}/cobald.yml"],
      File["/etc/cobald/${name}/tardis.yml"],
    ],
  }

}
