# Class: cobald::install
# ======================
#
# Puppet class to install all requirements to run a COBalD/TARDIS service.
#
# Authors
# -------
#
# Peter Wienemann <peter.wienemann@uni-bonn.de>
#
# Copyright
# ---------
#
# Copyright 2019 University of Bonn
#
class cobald::install {

  $cobald_version             = $cobald::cobald_version
  $tardis_version             = $cobald::tardis_version
  $auth_lbs                   = $cobald::auth_lbs
  $filename_cobald_keytab     = $cobald::filename_cobald_keytab
  $ssh_hostname               = $cobald::ssh_hostname
  $ssh_username               = $cobald::ssh_username
  $ssh_pubhostkey             = $cobald::ssh_pubhostkey
  $ssh_hostkeytype            = $cobald::ssh_hostkeytype
  $ssh_privkey_filename       = $cobald::ssh_privkey_filename
  $ssh_keytype                = $cobald::ssh_keytype
  $multiplex_ssh              = $cobald::multiplex_ssh
  $ssh_perform_output_cleanup = $cobald::ssh_perform_output_cleanup
  $output_cleanup_pattern     = $cobald::output_cleanup_pattern
  $auth_obs                   = $cobald::auth_obs
  $manage_cas                 = $cobald::manage_cas
  $ca_repo_url                = $cobald::ca_repo_url
  $ca_packages                = $cobald::ca_packages
  $filename_cobald_robot_key  = $cobald::filename_cobald_robot_key
  $filename_cobald_robot_cert = $cobald::filename_cobald_robot_cert
  $gsi_daemon_dns             = $cobald::gsi_daemon_dns

  $cobald_url = $cobald_version ? {
    'master' => $::cobald::params::cobald_url, # use Github master branch
    default  => false,                         # use PyPI
  }
  $tardis_url = $tardis_version ? {
    'master' => $::cobald::params::tardis_url, # use Gibhub master branch
    default  => false,                         # use PyPI
  }

  $pip_cobald = $cobald_version ? {
    undef    => 'cobald',
    'master' => 'cobald',
    default  => "cobald==${cobald_version}",
  }
  $pip_tardis = $tardis_version ? {
    undef    => 'cobald-tardis',
    'master' => 'cobald-tardis',
    default  => "cobald-tardis==${tardis_version}",
  }

  $python_pkg_prefix = $::cobald::params::python_pkg_prefix

  if (!defined(Class['python'])) {
    class { 'python':
      use_epel => false,
    }
  }

  ensure_packages(
    [
      'epel-release',
    ]
  )

  ensure_packages(
    [
      # Needed base dependencies from EPEL.
      $python_pkg_prefix,
      "${python_pkg_prefix}-devel",
      "${python_pkg_prefix}-pip",
      "${python_pkg_prefix}-libs",
      "${python_pkg_prefix}-setuptools",
      # These can be used from system instead of being installed by PIP.
      "${python_pkg_prefix}-typing",
      "${python_pkg_prefix}-PyYAML",
      "${python_pkg_prefix}-attrs",
      "${python_pkg_prefix}-idna",
      "${python_pkg_prefix}-certifi",
      "${python_pkg_prefix}-asn1crypto",
      "${python_pkg_prefix}-cffi",
      "${python_pkg_prefix}-chardet",
      "${python_pkg_prefix}-pycparser",
      "${python_pkg_prefix}-dateutil",
      "${python_pkg_prefix}-requests",
      "${python_pkg_prefix}-urllib3",
      "${python_pkg_prefix}-six",
    ],
    {
      require => Package['epel-release'],
    }
  )

  $u_auth_lbs = unique($auth_lbs)

  # authentication used to access local batch system
  $u_auth_lbs.each |Enum['krb5', 'ssh'] $lauth| {
    case $lauth {
      'krb5': {
        ensure_packages(
          [
            # kinit daemon to refresh ticket
            'kstart',
          ],
          {
            require => Package['epel-release'],
          }
        )
        # ensure run directory exists (used to store k5start pid)
        file { '/var/run/cobald':
          ensure   => 'directory',
          mode     => '0700',
          owner    => 'cobald',
          group    => 'cobald',
          seluser  => 'system_u',
          selrole  => 'object_r',
          seltype  => 'var_run_t',
          selrange => 's0',
        }
        # Unit file (changes are handled by systemd module, i. e. it automatically triggers a "systemctl daemon-reload")
        systemd::unit_file { 'k5start.service':
            source => "puppet:///modules/${module_name}/k5start.service",
        }
        service { 'k5start':
          ensure  => 'running',
          # runs as user cobald
          require => [
            User['cobald'],
            Systemd::Unit_file['k5start.service'],
            Package['kstart'],
            File['/var/run/cobald'],
          ],
        }
        if $filename_cobald_keytab != undef {
          # keytab for cobald principal (used by k5start to obtain tickets)
          node_encrypt::file { '/etc/condor/cobald.keytab':
            ensure   => 'file',
            content  => file($filename_cobald_keytab),
            mode     => '0640',
            owner    => 'root',
            group    => 'cobald',
            seluser  => 'system_u',
            selrole  => 'object_r',
            seltype  => 'condor_conf_t',
            selrange => 's0',
            require  => Package['condor'],
          }
        }
        else {
          fail("${module_name}: authentication method ${auth_lbs} for local batch system used but no keytab file specified.")
        }
      }
      'ssh' : {
        file { '/var/lib/cobald/.ssh':
          ensure   => 'directory',
          mode     => '0700',
          owner    => 'cobald',
          group    => 'cobald',
          seluser  => 'system_u',
          selrole  => 'object_r',
          seltype  => 'ssh_home_t',
          selrange => 's0',
          require  => File['/var/lib/cobald'],
        }
        file { '/var/lib/cobald/.ssh/known_hosts':
          ensure   => 'file',
          mode     => '0644',
          owner    => 'cobald',
          group    => 'cobald',
          seluser  => 'system_u',
          selrole  => 'object_r',
          seltype  => 'ssh_home_t',
          selrange => 's0',
          require  => File['/var/lib/cobald/.ssh'],
        }
        sshkey { $ssh_hostname:
          key      => $ssh_pubhostkey,
          target   => '/var/lib/cobald/.ssh/known_hosts',
          type     => $ssh_hostkeytype,
          require  => File['/var/lib/cobald/.ssh'],
        }
        node_encrypt::file { "/var/lib/cobald/.ssh/id_${ssh_keytype}":
          mode     => '0600',
          owner    => 'cobald',
          group    => 'cobald',
          seluser  => 'unconfined_u',
          selrole  => 'object_r',
          seltype  => 'ssh_home_t',
          selrange => 's0',
          content  => file($ssh_privkey_filename),
          require  => File['/var/lib/cobald/.ssh'],
        }
        if $multiplex_ssh {
          ssh::client::config::user { 'cobald':
            ensure  => present,
            target  => '/var/lib/cobald/.ssh/config',
            require => File['/var/lib/cobald/.ssh/known_hosts'],
            options => {
              "Host ${ssh_hostname}" => {
                'ControlPath'         => '~/.ssh/master-%r@%h:%p',
                'ControlMaster'       => 'auto',
                'ControlPersist'      => '60',
                'ServerAliveInterval' => '30',
              }
            }
          }
        }
        cron::daily { 'cobald_cleanup_job_output_via_ssh':
          ensure  => bool2str($ssh_perform_output_cleanup, 'present', 'absent'),
          hour    => '3',
          minute  => fqdn_rand(60, 'cobald_job_cleanup'),
          user    => 'cobald',
          command => "ssh ${ssh_username}@${ssh_hostname} \"find ~ -maxdepth 1 -type f -name '${output_cleanup_pattern}' -mtime +10 -delete\"",
        }
      }
      default: {
        fail("${module_name}: authentication method ${auth_lbs} for local batch system not supported.")
      }
    }
  }

  # authentication used for overlay batch system
  case $auth_obs {
    'gsi': {
      ensure_packages(
        [
          # voms client tools to obtain proxy
          'voms-clients-cpp',
        ],
        {
          require => Package['epel-release'],
        }
      )

      # Robotkey for cobald
      if $filename_cobald_robot_key != undef {
        node_encrypt::file { '/etc/grid-security/robotkey.pem':
          ensure  => 'present',
          mode    => '0400',
          owner   => 'cobald',
          group   => 'cobald',
          content => file($filename_cobald_robot_key),
          require => Class['fetchcrl'],
        }
      }
      else {
        fail("${module_name}: authentication method ${auth_obs} for overlay batch system used but no robot key file specified.")
      }

      # Robotcert for cobald
      if $filename_cobald_robot_cert != undef {
        node_encrypt::file { '/etc/grid-security/robotcert.pem':
          ensure  => 'present',
          mode    => '0644',
          owner   => 'cobald',
          group   => 'cobald',
          content => file($filename_cobald_robot_cert),
          require => Class['fetchcrl'],
        }
      }
      else {
        fail("${module_name}: authentication method ${auth_obs} for overlay batch system used but no robot certificate file specified.")
      }

      file { '/etc/condor/config.d/86_cobald.config':
        ensure   => 'file',
        content  => epp("${module_name}/condor_cobald.config.epp", { 'gsi_daemon_dns' => $gsi_daemon_dns }),
        mode     => '0644',
        owner    => 'root',
        group    => 'root',
        seluser  => 'system_u',
        selrole  => 'object_r',
        seltype  => 'condor_conf_t',
        selrange => 's0',
        require  => Package['condor'],
        notify   => Exec['/usr/sbin/condor_reconfig'],
      }

      if $manage_cas {
        class { 'fetchcrl':
          runboot        => false,
          runcron        => true,
          capkgs         => $ca_packages,
          capkgs_version => 'latest',
          carepo         => $ca_repo_url,
          manage_carepo  => true,
        }
      }

      # Hourly refresh of proxy with a lifetime of 3 days
      # (make sure that starting jobs always have sufficient proxy lifetime)
      cron::hourly { 'cobald_refreshproxy':
        command => '/usr/bin/voms-proxy-init -cert /etc/grid-security/robotcert.pem -key /etc/grid-security/robotkey.pem -hours 72 -out /var/cache/cobald/proxy',
        user    => 'cobald',
        minute  => 0,
        require => [
          Package['voms-clients-cpp'],
          Class['fetchcrl'],
          File['/var/cache/cobald'],
          Node_Encrypt::File['/etc/grid-security/robotcert.pem'],
          Node_Encrypt::File['/etc/grid-security/robotkey.pem'],
          User['cobald'],
        ],
      }
      if member($auth_lbs, 'ssh') {
	ensure_packages(
          [
            'openssh-clients',
          ]
        )
        cron::hourly { 'cobald_transferproxy':
          command => "scp /var/cache/cobald/proxy ${ssh_username}@${ssh_hostname}:.",
          user    => 'cobald',
          minute  => 1,
          require => [
            Cron::Hourly['cobald_refreshproxy'],
            Package['openssh-clients'],
          ]
        }
      }
    }
    default: {
      fail("${module_name}: authentication method ${auth_obs} for overlay batch system not supported.")
    }
  }

  if $cobald_version == 'master' or $tardis_version == 'master' {
    # getting the master branch from git requires git
    ensure_packages(
      [
        'git',
      ]
    )
    $piprequire = Package['git']
  }
  else {
    $piprequire = []
  }
  python::pyvenv { '/opt/cobald' :
    ensure     => present,
    version    => '3.6',
    owner      => 'root',
    group      => 'root',
    systempkgs => true,
    require    => [
      Package["${python_pkg_prefix}-devel"],
      Package["${python_pkg_prefix}-pip"],
      Package["${python_pkg_prefix}-libs"],
      Package["${python_pkg_prefix}-setuptools"],
      # For COBalD
      Package["${python_pkg_prefix}-typing"],
      Package["${python_pkg_prefix}-PyYAML"],
      # For Trio, which is a dependency of COBalD
      Package["${python_pkg_prefix}-attrs"],
      Package["${python_pkg_prefix}-idna"],
      # Indirect dependencies of COBalD-Tardis
      Package["${python_pkg_prefix}-certifi"],
      Package["${python_pkg_prefix}-asn1crypto"],
      Package["${python_pkg_prefix}-cffi"],
      Package["${python_pkg_prefix}-chardet"],
      Package["${python_pkg_prefix}-pycparser"],
      Package["${python_pkg_prefix}-dateutil"],
      Package["${python_pkg_prefix}-requests"],
      Package["${python_pkg_prefix}-urllib3"],
      Package["${python_pkg_prefix}-six"],
    ],
  }
  ->python::pip { 'cobald':
    ensure       => present,
    pkgname      => $pip_cobald,
    pip_provider => 'pip3',
    virtualenv   => $::cobald::params::virtualenv,
    url          => $cobald_url,
    owner        => 'root',
    timeout      => 1800,
    require      => $piprequire,
  }
  ->python::pip { 'cobald-tardis':
    ensure       => present,
    pkgname      => $pip_tardis,
    pip_provider => 'pip3',
    virtualenv   => $::cobald::params::virtualenv,
    url          => $tardis_url,
    owner        => 'root',
    timeout      => 1800,
    require      => $piprequire,
  }

  # Handle cobald user/group
  class { 'cobald::user': }

  # Ensure directory for drone registry exists.
  # This is also used as cobald home directory.
  file { '/var/lib/cobald':
    ensure   => 'directory',
    mode     => '0755',
    owner    => 'cobald',
    group    => 'cobald',
    seluser  => 'system_u',
    selrole  => 'object_r',
    seltype  => 'var_lib_t',
    selrange => 's0',
  }

  # Ensure log directory exists
  file { '/var/log/cobald':
    ensure   => 'directory',
    mode     => '0755',
    owner    => 'cobald',
    group    => 'cobald',
    seluser  => 'system_u',
    selrole  => 'object_r',
    seltype  => 'var_log_t',
    selrange => 's0',
  }

  # Ensure cache directory exists (used to store proxy)
  file { '/var/cache/cobald':
    ensure   => 'directory',
    mode     => '0700',
    owner    => 'cobald',
    group    => 'cobald',
    seluser  => 'system_u',
    selrole  => 'object_r',
    seltype  => 'var_t',
    selrange => 's0',
  }

  # Configuration directory
  file { '/etc/cobald':
    ensure   => 'directory',
    mode     => '0755',
    owner    => 'root',
    group    => 'root',
    seluser  => 'system_u',
    selrole  => 'object_r',
    seltype  => 'etc_t',
    selrange => 's0',
  }

  # Unit file (changes are handled by systemd module, i. e. it automatically triggers a "systemctl daemon-reload")
  systemd::unit_file { 'cobald@.service':
    source => "puppet:///modules/${module_name}/cobald@.service",
  }

}
