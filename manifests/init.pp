# Class: cobald
# =============
#
# Puppet class for setting up the prerequisites to run a COBalD/TARDIS service.
# Specific instances are managed by the resource type 'cobald::instance'.
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
class cobald(
  String                     $cobald_version             = undef,                        # cobald version to be used (undef = latest PyPI release, 'master' = Github master branch or PyPI release number)
  String                     $tardis_version             = undef,                        # tardis version to be used (undef = latest PyPI release, 'master' = Github master branch or PyPI release number)
  Array[Enum['krb5', 'ssh']] $auth_lbs                   = ['krb5'],                     # authentication used to access local batch system
  String                     $filename_cobald_keytab     = undef,                        # cobald service principal keytab file name (if LBS uses Kerberos authentication)
  String                     $ssh_hostname               = undef,                        # hostname of host to access LBS (if ssh authentication is used to access LBS)
  String                     $ssh_username               = undef,                        # user name to be used for ssh access to LBS (if ssh authentication is used to access LBS)
  String                     $ssh_pubhostkey             = undef,                        # public ssh host key (if ssh authentication is used to access LBS)
  String                     $ssh_hostkeytype            = undef,                        # encryption type of ssh host key (if ssh authentication is used to access LBS)
  String                     $ssh_privkey_filename       = undef,                        # file name of ssh private key used to access LBS (if ssh authentication is used to access LBS)
  Enum['dsa', 'ecdsa', 'ed25519', 'rsa'] $ssh_keytype    = undef,                        # type of ssh key used to access LBS (if ssh authentication is used to access LBS)
  Boolean                    $multiplex_ssh              = true,                         # set up SSH multiplexing for cobald user (reduces latency of SSH logins)
  Optional[Enum['gsi']]      $auth_obs                   = 'gsi',                        # authentication used by overlay batch system
  Boolean                    $manage_cas                 = false,                        # manage CAs (including CRLs)
  String                     $ca_repo_url                = $cobald::params::ca_repo_url, # repository URL from which to fetch CAs
  Array[String]              $ca_packages                = $cobald::params::ca_packages, # array containing names of CA packages
  String                     $filename_cobald_robot_key  = undef,                        # cobald robot key file name (if OBS uses GSI authentication)
  String                     $filename_cobald_robot_cert = undef,                        # cobald robot certificate file name (if OBS uses GSI authentication)
  Array[String]              $gsi_daemon_dns             = [],                           # distringuished names to be added to HTCondor variable GSI_DAEMON_NAME
) inherits cobald::params {

  Class { 'cobald::install': }

}
