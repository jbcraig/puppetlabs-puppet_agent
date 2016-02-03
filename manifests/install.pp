# == Class puppet_agent::install
#
# This class is called from puppet_agent for install.
#
# === Parameters
#
# [package_file_name]
#   The puppet-agent package file name.
#   (see puppet_agent::prepare::package_file_name)
#
class puppet_agent::install(
  $package_file_name = undef,
) {
  assert_private()

  if ($::operatingsystem == 'SLES' and $::operatingsystemmajrelease == '10') or ($::operatingsystem == 'AIX' and  $::architecture =~ 'PowerPC_POWER[5,6,7]') {
    contain puppet_agent::install::remove_packages

    exec { 'replace puppet.conf removed by package removal':
      path      => '/bin:/usr/bin:/sbin:/usr/sbin',
      command   => "cp ${puppet_agent::params::confdir}/puppet.conf.rpmsave ${puppet_agent::params::config}",
      creates   => $puppet_agent::params::config,
      require   => Class['puppet_agent::install::remove_packages'],
      before    => Package[$puppet_agent::package_name],
      logoutput => 'on_failure',
    }

    $_package_options = {
      provider        => 'rpm',
      source          => "/opt/puppetlabs/packages/${package_file_name}",
    }
  } elsif $::operatingsystem == 'Solaris' and $::operatingsystemmajrelease == '10' {
    contain puppet_agent::install::remove_packages

    $_unzipped_package_name = regsubst($package_file_name, '\.gz$', '')
    $_package_options = {
      adminfile => '/opt/puppetlabs/packages/solaris-noask',
      source    => "/opt/puppetlabs/packages/${_unzipped_package_name}",
      require   => Class['puppet_agent::install::remove_packages'],
    }
  } elsif $::operatingsystem == 'Solaris' and $::operatingsystemmajrelease == '11' {
    contain puppet_agent::install::remove_packages

      # = Testing to see if this works ======

      # Backup user configuration because solaris 11 will blow away
      # /etc/puppetlabs/ when uninstalling the pe-* modules.
      file { '/tmp/puppet_agent/':
        ensure => directory,
      }

      exec { 'puppet_agent backup /etc/puppetlabs/':
        command => 'cp -r /etc/puppetlabs/ /tmp/puppet_agent/',
        require => File['/tmp/puppet_agent/'],
        path    => '/bin:/usr/bin:/sbin:/usr/sbin',
        before  => Class['puppet_agent::install::remove_packages'],
      }

      $pkgrepo_dir = '/etc/puppetlabs/installer/solaris.repo'

      exec { 'puppet_agent remove existing repo':
        command   => "pkgrepo remove -s '${pkgrepo_dir}' '*'",
        path      => '/bin:/usr/bin:/sbin:/usr/sbin',
        onlyif    => "test -f ${pkgrepo_dir}/pkg5.repository",
        logoutput => 'on_failure',
        require   => Class['puppet_agent::install::remove_packages'],
        notify    => Exec['puppet_agent create repo'],
      }

      exec { 'puppet_agent create repo':
        command     => "pkgrepo create ${pkgrepo_dir}",
        path        => '/bin:/usr/bin:/sbin:/usr/sbin',
        unless      => "test -f ${pkgrepo_dir}/pkg5.repository",
        logoutput   => 'on_failure',
        notify      => Exec['puppet_agent set publisher'],
        refreshonly => true,
      }

      exec { 'puppet_agent set publisher':
        command     => "pkgrepo set -s ${pkgrepo_dir} publisher/prefix=puppetlabs.com",
        path        => '/bin:/usr/bin:/sbin:/usr/sbin',
        logoutput   => 'on_failure',
        refreshonly => true,
      }

      exec { 'puppet_agent copy packages':
        command   => "pkgrecv -s file:///opt/puppetlabs/packages/${package_file_name} -d ${pkgrepo_dir} '*'",
        path      => '/bin:/usr/bin:/sbin:/usr/sbin',
        require   => Exec['puppet_agent set publisher'],
        logoutput => 'on_failure',
      }

      # =====================================

    #exec { 'puppet_agent restore /etc/puppetlabs':
    #  command => 'cp -r /tmp/puppet_agent/puppetlabs /etc',
    #  path    => '/bin:/usr/bin:/sbin:/usr/sbin',
    #  require => Class['puppet_agent::install::remove_packages'],
    #  before  => Exec['puppet_agent copy packages'],
    #}

    #exec { 'puppet_agent post-install restore /etc/puppetlabs':
    #  command     => 'cp -r /tmp/puppet_agent/puppetlabs /etc',
    #  path        => '/bin:/usr/bin:/sbin:/usr/sbin',
    #  refreshonly => true,
    #}

    $_package_options = {
      #require => Exec['puppet_agent restore /etc/puppetlabs'],
      #notify  => Exec['puppet_agent post-install restore /etc/puppetlabs'],
    }
  } elsif $::operatingsystem == 'Darwin' and $::macosx_productversion_major =~ '10\.[9,10,11]' {
    contain puppet_agent::install::remove_packages

    $_package_options = {
      source    => "/opt/puppetlabs/packages/${package_file_name}",
      require   => Class['puppet_agent::install::remove_packages'],
    }
  } else {
    $_package_options = {}
  }

  package { $::puppet_agent::package_name:
    ensure => present,
    *      => $_package_options,
  }
}
