# == Class: nrpe
#
# Module to manage nrpe
#
class nrpe (
  String $nrpe_package,
  String $nrpe_package_ensure,
  $nrpe_package_adminfile = undef,
  $nrpe_package_source = undef,
  String $nagios_plugins_package,
  String $nagios_plugins_package_ensure,
  $nagios_plugins_package_adminfile = undef,
  $nagios_plugins_package_source = undef,
  String $nrpe_config,
  String $nrpe_config_owner,
  String $nrpe_config_group,
  String $nrpe_config_mode,
  String $libexecdir,
  String $libexecdir_owner,
  String $log_facility,
  String $pid_file,
  Integer $server_port,
  $server_address_enable,
  $server_address,
  $nrpe_user,
  $nrpe_group,
  $allowed_hosts,
  $dont_blame_nrpe,
  $allow_bash_command_substitution,
  $command_prefix_enable,
  String $command_prefix,
  $debug,
  $command_timeout,
  $connection_timeout,
  $allow_weak_random_seed,
  String $include_dir,
  $service_ensure,
  String $service_name,
  $service_enable,
  Hash[String, Hash[String, Struct[{plugin => String,
                       Optional[args] => String,
		       Optional[use_sudo] => Boolean}]]] $plugins,
  Hash[String, Hash[String, Struct[{Optional[plugin] => String,
                       Optional[args] => String,
		       Optional[use_sudo] => Boolean}]]] $plugin_overrides,
  $purge_plugins,
  $hiera_merge_plugins,
  $nrpe_package_provider = undef,
  String $sudo_command,
  Boolean $allow_sudo,
) {

  # Convert types
  if is_string($server_address_enable) {
    $server_address_enable_bool = str2bool($server_address_enable)
  } else {
    $server_address_enable_bool = $server_address_enable
  }

  if is_string($command_prefix_enable) {
    $command_prefix_enable_bool = str2bool($command_prefix_enable)
  } else {
    $command_prefix_enable_bool = $command_prefix_enable
  }

  if is_string($service_enable) {
    $service_enable_bool = str2bool($service_enable)
  } else {
    $service_enable_bool = $service_enable
  }

  if is_string($purge_plugins) {
    $purge_plugins_bool = str2bool($purge_plugins)
  } else {
    $purge_plugins_bool = $purge_plugins
  }

  if is_string($hiera_merge_plugins) {
    $hiera_merge_plugins_bool = str2bool($hiera_merge_plugins)
  } else {
    $hiera_merge_plugins_bool = $hiera_merge_plugins
  }

  # Validate params
  validate_re($nrpe_config_mode, '^\d{4}$',
    "nrpe::nrpe_config_mode must be a four digit octal mode. Detected value is <${nrpe_config_mode}>.")
  validate_absolute_path($nrpe_config)
  validate_absolute_path($libexecdir)
  if $pid_file != 'absent' {
    validate_absolute_path($pid_file)
  }

  if $server_port < 0 or $server_port > 65535 {
    fail("nrpe::server_port must be a valid port number between 0 and 65535, inclusive. Detected value is <${server_port}>.")
  }
  validate_array($allowed_hosts)
  validate_re($dont_blame_nrpe, '^[01]{1}$',
    "nrpe::dont_blame_nrpe must be 0 or 1. Detected value is <${dont_blame_nrpe}>.")
  validate_re($allow_bash_command_substitution, '^[01]{1}$',
    "nrpe::allow_bash_command_substitution must be 0 or 1. Detected value is <${allow_bash_command_substitution}>.")
  validate_absolute_path($command_prefix)
  validate_re($debug, '^[01]{1}$',
    "nrpe::debug must be 0 or 1. Detected value is <${debug}>.")
  validate_re($command_timeout, '^\d+$',
    "nrpe::command_timeout must be a postive integer. Detected value is <${command_timeout}>.")
  validate_re($connection_timeout, '^\d+$',
    "nrpe::connection_timeout must be a postive integer. Detected value is <${connection_timeout}>.")
  validate_re($allow_weak_random_seed, '^[01]{1}$',
    "nrpe::allow_weak_random_seed must be 0 or 1. Detected value is <${allow_weak_random_seed}>.")
  validate_absolute_path($include_dir)
  validate_re($service_ensure, '^(running|stopped)$',
    "nrpe::service_ensure must be \'running\' or \'stopped\'. Detected value is <${service_ensure}>.")

  if $nrpe_package_provider {
    validate_string($nrpe_package_provider)
    Package {
      provider => $nrpe_package_provider,
    }
  }

  package { $nrpe_package:
    ensure    => $nrpe_package_ensure,
    adminfile => $nrpe_package_adminfile,
    source    => $nrpe_package_source,
  }

  package { $nagios_plugins_package:
    ensure    => $nagios_plugins_package_ensure,
    adminfile => $nagios_plugins_package_adminfile,
    source    => $nagios_plugins_package_source,
    before    => Service['nrpe_service'],
  }

  file {$libexecdir:
    ensure => 'directory',
    owner => $libexecdir_owner,
    group => $libexecdir_owner,
    mode => '0775',
  }

  file { 'nrpe_config':
    ensure  => file,
    content => template('nrpe/nrpe.cfg.erb'),
    path    => $nrpe_config,
    owner   => $nrpe_config_owner,
    group   => $nrpe_config_group,
    mode    => $nrpe_config_mode,
    require => Package[$nrpe_package],
  }

  file { 'nrpe_config_dot_d':
    ensure  => directory,
    path    => $include_dir,
    owner   => $nrpe_config_owner,
    group   => $nrpe_config_group,
    mode    => $nrpe_config_mode,
    purge   => $purge_plugins_bool,
    recurse => true,
    require => Package[$nrpe_package],
    notify  => Service['nrpe_service'],
  }

  service { 'nrpe_service':
    ensure    => $service_ensure,
    name      => $service_name,
    enable    => $service_enable_bool,
    subscribe => File['nrpe_config'],
  }

  if $allow_sudo {
      file { '/etc/sudoers.d/nagios':
	ensure  => 'file',
	owner   => 'root',
	group   => 'root',
	mode    => '0440',
	content => epp('nrpe/sudoers.epp', {
	    'user' => $nrpe_user,
	    'libexecdir' => $libexecdir,
	}),
      }

      if $facts['selinux'] {
	  selboolean {'nagios_run_sudo':
	    persistent => true,
	    value => on,
	  }
      }
  } else {
      if $facts['selinux'] {
	  selboolean {'nagios_run_sudo':
	    persistent => true,
	    value => off,
	  }
      }
  }

  $nrpe::plugins.each |String $group, Hash $plugin_hash| {
    file {"${include_dir}/${group}.cfg":
	ensure => file,
	owner => $nrpe_config_owner,
	group => $nrpe_config_group,
	mode => $nrpe_config_mode,
	content => epp('nrpe/nrpe_local.cfg.epp', {
	  'plugins' => deep_merge($plugin_hash, $plugin_overrides[$group]),
	  'libexecdir' => $libexecdir,
	  'sudo_command' => $sudo_command,
	}),
    }
  }
}
