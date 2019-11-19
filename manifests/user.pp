# Class: cobald::user
# ===================
#
# Puppet class to create cobald user and cobald group used by COBalD/TARDIS service.
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
class cobald::user(
  Integer $uid = 509,
  Integer $gid = 509,
) {

  $nologin_shell = $facts['os']['family'] ? {
    'RedHat' => '/sbin/nologin',
    'Debian' => '/usr/sbin/nologin',
    default  => '/sbin/nologin',
  }

  group { 'cobald':
    ensure => present,
    gid    => $gid,
  }
  ->user { 'cobald':
    ensure  => present,
    comment => 'cobald user',
    gid     => 'cobald',
    home    => '/var/lib/cobald',
    shell   => $nologin_shell,
    uid     => $uid,
  }

}
