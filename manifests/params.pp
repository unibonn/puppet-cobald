# Class: cobald::params
# =====================
#
# Puppet class for setting parameters used by COBalD/TARDIS module.
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
class cobald::params(
) {

  if (($facts['os']['name'] == 'CentOS' or $facts['os']['name'] == 'Scientific') and $facts['os']['release']['major'] == '7') {
    $python_pkg_prefix = 'python36'
  }
  elsif ($facts['os']['name'] == 'CentOS' and $facts['os']['release']['major'] == '8') {
    $python_pkg_prefix = 'python3'
  }
  else {
    fail("${module_name}: OS ${facts['os']['name']} not supported.")
  }

  $cobald_url  = 'git+https://github.com/MatterMiners/cobald'
  $tardis_url  = 'git+https://github.com/MatterMiners/tardis'
  $pypi_url    = 'https://pypi.org/simple'

  $virtualenv  = '/opt/cobald'

  $ca_repo_url = 'https://repository.egi.eu/sw/production/cas/1/current'
  $ca_packages = ['ca-policy-egi-core']

}
