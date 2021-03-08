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
# Copyright 2019-2020 University of Bonn
#
class cobald::install {

  $cobald_version             = $cobald::cobald_version
  $tardis_version             = $cobald::tardis_version
  $cobald_repo_type           = $cobald::cobald_repo_type
  $tardis_repo_type           = $cobald::tardis_repo_type
  $cobald_repo_url            = $cobald::cobald_repo_url
  $tardis_repo_url            = $cobald::tardis_repo_url
  $auth_lbs                   = $cobald::auth_lbs
  $filename_cobald_keytab     = $cobald::filename_cobald_keytab
  $ssh_hostname               = $cobald::ssh_hostname
  $ssh_username               = $cobald::ssh_username
  $ssh_pubhostkey             = $cobald::ssh_pubhostkey
  $ssh_hostkeytype            = $cobald::ssh_hostkeytype
  $ssh_privkey_filename       = $cobald::ssh_privkey_filename
  $ssh_keytype                = $cobald::ssh_keytype
  $ssh_perform_output_cleanup = $cobald::ssh_perform_output_cleanup
  $output_cleanup_pattern     = $cobald::output_cleanup_pattern
  $auth_obs                   = $cobald::auth_obs
  $manage_cas                 = $cobald::manage_cas
  $ca_repo_url                = $cobald::ca_repo_url
  $ca_packages                = $cobald::ca_packages
  $filename_cobald_robot_key  = $cobald::filename_cobald_robot_key
  $filename_cobald_robot_cert = $cobald::filename_cobald_robot_cert
  $zabbix_monitor_robotcert   = $cobald::zabbix_monitor_robotcert
  $gsi_daemon_dns             = $cobald::gsi_daemon_dns
  $uid                        = $cobald::uid
  $gid                        = $cobald::gid

  $cobald_url = $cobald_repo_type ? {
    'git' => $cobald_repo_url ? { # use Github
      undef => $cobald::params::cobald_url,
      default => $cobald_version ? {
        undef => "${cobald_repo_url}@master",
        default => "${cobald_repo_url}@${cobald_version}",
      },
    },
    'pypi'  => $cobald_repo_url ? { # use PyPI
      undef => $cobald::params::pypi_url,
      default => $cobald_repo_url
    },
  }
  $tardis_url = $tardis_repo_type ? {
    'git' => $tardis_repo_url ? { # use Github
      undef => $cobald::params::tardis_url,
      default => $tardis_version ? {
        undef => "${tardis_repo_url}@master",
        default => "${tardis_repo_url}@${tardis_version}",
      },
    },
    'pypi'  => $tardis_repo_url ? { # use PyPI
      undef => $cobald::params::pypi_url,
      default => $tardis_repo_url
    },
  }

  if $cobald_repo_type == 'pypi' {
    $pip_cobald = $cobald_version ? {
      undef    => 'cobald',
      default  => "cobald==${cobald_version}",
    }
  } else {
    $pip_cobald = 'cobald'
  }
  if $tardis_repo_type == 'pypi' {
    $pip_tardis = $tardis_version ? {
      undef    => 'cobald-tardis',
      default  => "cobald-tardis==${tardis_version}",
    }
  } else {
    $pip_tardis = 'cobald-tardis'
  }

  $python_pkg_prefix = $::cobald::params::python_pkg_prefix

  if (!defined(Class['python'])) {
    class { 'python':
      version  => $python_pkg_prefix,
      dev      => 'present',
      use_epel => true,
    }
  }

  ensure_packages(
    [
      # Require sqlite tools to allow debugging the drone registry.
      'sqlite',
      # Require EPEL for dependencies.
      'epel-release',
    ]
  )

  ensure_packages(
    [
      # Needed base dependencies from EPEL.
      "${python_pkg_prefix}-libs",
      "${python_pkg_prefix}-setuptools",
      # These can be used from system instead of being installed by PIP.
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

  if ($facts['os']['family'] == 'RedHat' and (versioncmp($facts['os']['release']['major'],'7') <= 0)) {
    # Package not present in EPEL 8 yet.
    ensure_packages(
      [
        "${python_pkg_prefix}-typing",
      ],
      {
        require => Package['epel-release'],
      }
    )
    $redhat_7_deps = [ Package["${python_pkg_prefix}-typing"] ]
  } else {
    $redhat_7_deps = [ ]
  }

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
            Node_Encrypt::File['/etc/condor/cobald.keytab'],
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

      if $zabbix_monitor_robotcert {
        zabbix::userparameters { 'robotcert.expiration_days':
          content => "UserParameter=robotcert.expiration_days,echo \$(((\$(date --date=\"\$(openssl x509 -enddate -noout -in /etc/grid-security/robotcert.pem | cut -d= -f 2)\" +%s) - \$(date +%s))/86400))",
        }
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

      exec { 'create random data for voms-proxy-init':
        command => '/usr/bin/dd if=/dev/urandom of=/var/lib/cobald/.rnd bs=256 count=1',
        user    => 'cobald',
        require => File['/var/lib/cobald'],
        creates => '/var/lib/cobald/.rnd',
      }

      # Hourly check of proxy, created with a lifetime of 3 days, prolonged if lifetime smaller than 24 hours
      # (make sure that starting jobs always have sufficient proxy lifetime).
      # Note HTCondor transfers the proxy into the job on change, for other batchsystems, "cobald_transferproxy" cron can be used.
      # For this, proxy is copied to /var/run/condor as root on success to inherit matching SELinux context.
      $_proxy_renewal_config = {
        command => '/usr/bin/voms-proxy-info -file /var/cache/cobald/proxy -exist -valid 24:0 2> /dev/null || ( /usr/bin/voms-proxy-init -quiet -cert /etc/grid-security/robotcert.pem -key /etc/grid-security/robotkey.pem -hours 72 -out /var/cache/cobald/proxy_new && cp /var/cache/cobald/proxy_new /var/cache/cobald/proxy )',
        user    => 'cobald',
        require => [
                     Package['voms-clients-cpp'],
                     Class['fetchcrl'],
                     File['/var/cache/cobald'],
                     Exec['create random data for voms-proxy-init'],
                     Node_Encrypt::File['/etc/grid-security/robotcert.pem'],
                     Node_Encrypt::File['/etc/grid-security/robotkey.pem'],
                     User['cobald'],
                ],
      }
      cron::hourly { 'cobald_refreshproxy':
        *       => $_proxy_renewal_config,
        minute  => 0,
      }
      cron::job { 'cobald_refreshproxy_on_reboot':
        *       => $_proxy_renewal_config,
        special => 'reboot',
      }
      # Ensure cron has run once.
      exec { 'cobald_refreshproxy_once':
        *       => $_proxy_renewal_config,
        creates => '/var/cache/cobald/proxy',
      }
      # Copy the proxy for condor.
      # Note: Needs to be readable by COBalD user on submission, needs to have mode 600 to be accepted by HTCondor,
      #       and have correct inherited condor_var_run_t context for SELinux on prolongation.
      $_condorproxy_copy_command = 'cp -u --preserve=timestamps /var/cache/cobald/proxy /var/run/condor/proxy && chown cobald.root /var/run/condor/proxy'
      cron::hourly { 'cobald_copycondorproxy':
        command => $_condorproxy_copy_command,
        minute  => 10,
        require => Exec['cobald_refreshproxy_once'],
      }
      cron::job { 'cobald_copycondorproxy_on_reboot':
        command => "sleep 60 && ${_condorproxy_copy_command}",
        special => 'reboot',
      }
      exec { 'cobald_copycondorproxy_once':
        command => $_condorproxy_copy_command,
        creates => '/var/run/condor/proxy',
        require => Exec['cobald_refreshproxy_once'],
      }
      if member($auth_lbs, 'ssh') {
	ensure_packages(
          [
            'openssh-clients',
          ]
        )
        cron::hourly { 'cobald_transferproxy':
          command => "scp -q /var/cache/cobald/proxy ${ssh_username}@${ssh_hostname}:.",
          user    => 'cobald',
          minute  => 1,
          require => [
            Cron::Hourly['cobald_refreshproxy'],
            Package['openssh-clients'],
          ]
        }
        exec { 'cobald_transferproxy_once':
          command     => Cron::Hourly['cobald_transferproxy']['command'],
          user        => Cron::Hourly['cobald_transferproxy']['user'],
          refreshonly => true,
          subscribe   => Exec['cobald_refreshproxy_once'],
        }
      }
    }
  }

  if $cobald_repo_type == 'git' or $tardis_repo_type == 'git' {
    # pulling from git requires git
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
      Package['python-dev'],
      Package['pip'],
      Package["${python_pkg_prefix}-libs"],
      Package["${python_pkg_prefix}-setuptools"],
      # For COBalD
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
    ] + $redhat_7_deps,
  }
  ->python::pip { 'cobald':
    ensure       => present,
    pkgname      => $pip_cobald,
    virtualenv   => $::cobald::params::virtualenv,
    owner        => 'root',
    timeout      => 1800,
    require      => $piprequire,
    *            => $cobald_repo_type ? {
      'git' => { "url" => $cobald_url },
      'pypi' => { "index" => $cobald_url },
    },
  }
  ->python::pip { 'cobald-tardis':
    ensure       => present,
    pkgname      => $pip_tardis,
    virtualenv   => $::cobald::params::virtualenv,
    owner        => 'root',
    timeout      => 1800,
    require      => $piprequire,
    *            => $tardis_repo_type ? {
      'git' => { "url" => $tardis_url },
      'pypi' => { "index" => $tardis_url },
    },
  }

  # Handle cobald user/group
  class { 'cobald::user': 
    uid => $uid,
    gid => $gid,
  }

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
