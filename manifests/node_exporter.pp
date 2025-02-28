# @summary This module manages prometheus node node_exporter
# @param arch
#  Architecture (amd64 or i386)
# @param bin_dir
#  Directory where binaries are located
# @param collectors
#  deprecated, unused kept for migration scenatrios
#  will be removed in next release
# @param collectors_enable
#  Collectors to enable, addtionally to the defaults
#  https://github.com/prometheus/node_exporter#enabled-by-default
# @param collectors_disable
#  disable collectors which are enabled by default
#  https://github.com/prometheus/node_exporter#enabled-by-default
# @param download_extension
#  Extension for the release binary archive
# @param download_url
#  Complete URL corresponding to the where the release binary archive can be downloaded
# @param download_url_base
#  Base URL for the binary archive
# @param extra_groups
#  Extra groups to add the binary user to
# @param extra_options
#  Extra options added to the startup command
# @param group
#  Group under which the binary is running
# @param init_style
#  Service startup scripts style (e.g. rc, upstart or systemd)
# @param install_method
#  Installation method: url or package (only url is supported currently)
# @param manage_group
#  Whether to create a group for or rely on external code for that
# @param manage_service
#  Should puppet manage the service? (default true)
# @param manage_user
#  Whether to create user or rely on external code for that
# @param os
#  Operating system (linux is the only one supported)
# @param package_ensure
#  If package, then use this for package ensure default 'latest'
# @param package_name
#  The binary package name - not available yet
# @param purge_config_dir
#  Purge config files no longer generated by Puppet
# @param restart_on_change
#  Should puppet restart the service on configuration change? (default true)
# @param service_enable
#  Whether to enable the service from puppet (default true)
# @param service_ensure
#  State ensured for the service (default 'running')
# @param service_name
#  Name of the node exporter service (default 'node_exporter')
# @param user
#  User which runs the service
# @param version
#  The binary release version
# @param env_vars
#  hash with custom environment variables thats passed to the exporter via init script / unit file
# @param env_file_path
#  The path to the file with the environmetn variable that is read from the init script/systemd unit
# @param proxy_server
#  Optional proxy server, with port number if needed. ie: https://example.com:8080
# @param proxy_type
#  Optional proxy server type (none|http|https|ftp)
# @param web_config_file
#  Path of file where the web-config will be saved to
# @param web_config_content
#  Unless empty the content of the web-config yaml which will handed over as option to the exporter
# @param scrape_port
#  Scrape port for configuring scrape targets on the prometheus server via exported `prometheus::scrape_job` resources
#  If changed from default 9100 the option `--web.listen-address=':${scrape_port}'` will be added to the command line arguments
class prometheus::node_exporter (
  String $download_extension = 'tar.gz',
  Prometheus::Uri $download_url_base = 'https://github.com/prometheus/node_exporter/releases',
  Array[String] $extra_groups = [],
  String[1] $group = 'node-exporter',
  String[1] $package_ensure = 'latest',
  String[1] $package_name = 'node_exporter',
  String[1] $user = 'node-exporter',
  # renovate: depName=prometheus/node_exporter
  String[1] $version                                         = '1.9.0',
  Boolean $purge_config_dir                                  = true,
  Boolean $restart_on_change                                 = true,
  Boolean $service_enable                                    = true,
  Stdlib::Ensure::Service $service_ensure                    = 'running',
  String[1] $service_name                                    = 'node_exporter',
  Prometheus::Initstyle $init_style                          = $prometheus::init_style,
  Prometheus::Install $install_method                        = $prometheus::install_method,
  Boolean $manage_group                                      = true,
  Boolean $manage_service                                    = true,
  Boolean $manage_user                                       = true,
  String[1] $os                                              = downcase($facts['kernel']),
  Optional[String[1]] $extra_options                         = undef,
  Optional[Prometheus::Uri] $download_url                    = undef,
  String[1] $arch                                            = $prometheus::real_arch,
  Stdlib::Absolutepath $bin_dir                              = $prometheus::bin_dir,
  Optional[Array[String]] $collectors                        = undef,
  Array[String] $collectors_enable                           = [],
  Array[String] $collectors_disable                          = [],
  Optional[Stdlib::Host] $scrape_host                        = undef,
  Boolean $export_scrape_job                                 = false,
  Stdlib::Port $scrape_port                                  = 9100,
  String[1] $scrape_job_name                                 = 'node',
  Optional[Hash] $scrape_job_labels                          = undef,
  Optional[String[1]] $bin_name                              = undef,
  Hash[String[1], Scalar] $env_vars                          = {},
  Stdlib::Absolutepath $env_file_path                        = $prometheus::env_file_path,
  Optional[String[1]] $proxy_server                          = undef,
  Optional[Enum['none', 'http', 'https', 'ftp']] $proxy_type = undef,
  Stdlib::Absolutepath $web_config_file                      = '/etc/node_exporter_web-config.yml',
  Prometheus::Web_config $web_config_content                 = {},
) inherits prometheus {
  # Prometheus added a 'v' on the realease name at 0.13.0
  if versioncmp ($version, '0.13.0') >= 0 {
    $release = "v${version}"
  } else {
    $release = $version
  }

  $real_download_url = pick($download_url, "${download_url_base}/download/${release}/${package_name}-${version}.${os}-${arch}.${download_extension}")

  if $collectors {
    warning('Use of $collectors parameter is deprecated')
  }

  $notify_service = $restart_on_change ? {
    true    => Service[$service_name],
    default => undef,
  }

  $cmd_collectors_enable = $collectors_enable.map |$collector| {
    "--collector.${collector}"
  }

  $cmd_collectors_disable = $collectors_disable.map |$collector| {
    "--no-collector.${collector}"
  }

  $_web_config_ensure = $web_config_content.empty ? {
    true    => absent,
    default => file,
  }

  file { $web_config_file:
    ensure  => $_web_config_ensure,
    owner   => $user,
    group   => $group,
    mode    => '0640',
    content => $web_config_content.stdlib::to_yaml,
    notify  => $notify_service,
  }

  $_web_config = if $web_config_content.empty {
    ''
  } else {
    if versioncmp($version, '1.5.0') >= 0 {
      "--web.config.file=${$web_config_file}"
    } else {
      "--web.config=${$web_config_file}"
    }
  }

  if $scrape_port != 9100 {
    $listen_address = "--web.listen-address=':${scrape_port}'"
  } else {
    $listen_address = ''
  }
  $options = [
    $extra_options,
    $cmd_collectors_enable.join(' '),
    $cmd_collectors_disable.join(' '),
    $_web_config,
    $listen_address,
  ].filter |$x| { !$x.empty }.join(' ')

  prometheus::daemon { $service_name:
    install_method     => $install_method,
    version            => $version,
    download_extension => $download_extension,
    os                 => $os,
    arch               => $arch,
    real_download_url  => $real_download_url,
    bin_dir            => $bin_dir,
    notify_service     => $notify_service,
    package_name       => $package_name,
    package_ensure     => $package_ensure,
    manage_user        => $manage_user,
    user               => $user,
    extra_groups       => $extra_groups,
    group              => $group,
    manage_group       => $manage_group,
    purge              => $purge_config_dir,
    options            => $options,
    init_style         => $init_style,
    service_ensure     => $service_ensure,
    service_enable     => $service_enable,
    manage_service     => $manage_service,
    export_scrape_job  => $export_scrape_job,
    scrape_host        => $scrape_host,
    scrape_port        => $scrape_port,
    scrape_job_name    => $scrape_job_name,
    scrape_job_labels  => $scrape_job_labels,
    bin_name           => $bin_name,
    env_vars           => $env_vars,
    env_file_path      => $env_file_path,
    proxy_server       => $proxy_server,
    proxy_type         => $proxy_type,
  }
}
