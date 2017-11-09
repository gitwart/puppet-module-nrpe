# == Define: nrpe::plugin_group
#
# Manage a file to be included from include_dir configuration in nrpe.cfg that
# does a remote check.
#
# command[check_hda1]=@libexecdir@/check_disk -w 20% -c 10% -p /dev/hda1
# command[$name]=$libexecdir/$plugin $args
define nrpe::plugin_group (
  Enum['present', 'absent'] $ensure = 'present',
  Hash[String, Struct[{plugin => String,
                       args => String,
		       Optional[use_sudo] => Boolean}]] $plugins,

  $args           = 'UNSET',
  $libexecdir     = 'USE_DEFAULTS',
  $plugin         = 'USE_DEFAULTS',
  $command_prefix = 'UNSET',
) {
  if $ensure == 'present' {
    $plugin_ensure = 'file'
  } else {
    $plugin_ensure = 'absent'
  }

  include ::nrpe

  file { "nrpe_plugin_${name}":
    ensure  => $plugin_ensure,
    path    => "${nrpe::include_dir}/${name}.cfg",
    content => epp('nrpe/nrpe_local.cfg.epp', {
	'plugins' => $plugins,
	'libexecdir' => $nrpe::libexecdir,
	'sudo_command' => $nrpe::sudo_command,
    }),
    owner   => $nrpe::nrpe_config_owner,
    group   => $nrpe::nrpe_config_group,
    mode    => $nrpe::nrpe_mode,
    require => File['nrpe_config_dot_d'],
    notify  => Service['nrpe_service'],
  }
}
