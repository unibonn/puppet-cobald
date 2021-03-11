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
# Copyright 2019-2021 University of Bonn
#
class cobald(
  Optional[String]           $cobald_version             = undef,                        # cobald version to be used (indicates the PyPI version or the git branch, depending on the choice of cobald_repo_type. If undef, it will either be the latest PyPI release or 'master')
  Optional[String]           $tardis_version             = undef,                        # tardis version to be used (indicates the PyPI version or the git branch, depending on the choice of tardis_repo_type. If undef, it will either be the latest PyPI release or 'master')
  Enum['pypi', 'git']        $cobald_repo_type           = 'pypi',                       # cobald repository type (PyPI or git)
  Enum['pypi', 'git']        $tardis_repo_type           = 'pypi',                       # tardis repository type (PyPI or git)
  Array[Enum['krb5', 'ssh']] $auth_lbs                   = ['krb5'],                     # authentication used to access local batch system
  Optional[String]           $cobald_repo_url            = undef,                        # cobald git/pypi URL
  Optional[String]           $tardis_repo_url            = undef,                        # tardis git/pypi URL
  Optional[String]           $filename_cobald_keytab     = undef,                        # cobald service principal keytab file name (if LBS uses Kerberos authentication)
  Optional[String]           $ssh_hostname               = undef,                        # hostname of host to access LBS (if ssh authentication is used to access LBS)
  Optional[String]           $ssh_username               = undef,                        # user name to be used for ssh access to LBS (if ssh authentication is used to access LBS)
  Optional[String]           $ssh_pubhostkey             = undef,                        # public ssh host key (if ssh authentication is used to access LBS)
  Optional[String]           $ssh_hostkeytype            = undef,                        # encryption type of ssh host key (if ssh authentication is used to access LBS)
  Optional[String]           $ssh_privkey_filename       = undef,                        # file name of ssh private key used to access LBS (if ssh authentication is used to access LBS)
  Optional[Enum['dsa', 'ecdsa', 'ed25519', 'rsa']] $ssh_keytype    = undef,              # type of ssh key used to access LBS (if ssh authentication is used to access LBS)
  Boolean                    $ssh_perform_output_cleanup = false,                        # perform cleanup of job output files via SSH to ssh_hostname once per day
  String                     $output_cleanup_pattern     = 'slurm-*.out',                # pattern of files to delete when ssh_perform_output_cleanup is enabled
  Optional[Enum['gsi']]      $auth_obs                   = undef,                        # authentication used by overlay batch system
  Boolean                    $manage_cas                 = false,                        # manage CAs (including CRLs)
  String                     $ca_repo_url                = $cobald::params::ca_repo_url, # repository URL from which to fetch CAs
  Array[String]              $ca_packages                = $cobald::params::ca_packages, # array containing names of CA packages
  String                     $filename_cobald_robot_key  = undef,                        # cobald robot key file name (if OBS uses GSI authentication)
  String                     $filename_cobald_robot_cert = undef,                        # cobald robot certificate file name (if OBS uses GSI authentication)
  Boolean                    $zabbix_monitor_robotcert   = false,                        # monitor validity of robot certificate via Zabbix
  Array[String]              $gsi_daemon_dns             = [],                           # distringuished names to be added to HTCondor variable GSI_DAEMON_NAME
  Integer                    $uid                        = 509,                          # user id of cobald user
  Integer                    $gid                        = 509,                          # group id of cobald user
) inherits cobald::params {

  Class { 'cobald::install': }

}
