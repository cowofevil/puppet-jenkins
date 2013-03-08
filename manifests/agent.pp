define jenkins::agent (
  $server    = undef,

  $hostname  = undef,

  $username  = undef,
  $password  = undef,

  $executors = undef,
  $launcher  = undef,
  $homedir   = undef,
  $ssh_user  = undef,
  $ssh_key   = undef,
  $labels    = undef,
) {
  if ($server) {
    if ($hostname) {
      $agent = $hostname
    }
    else {
      $agent = $::fqdn
    }

    if (hiera("jenkins::auth_username::${server}")) {
      $username = hiera("jenkins::auth_username::${server}")
    }
    if (hiera("jenkins::auth_password::${server}")) {
      $password = hiera("jenkins::auth_password::${server}")
    }

    @@jenkins_agent { $agent:
      server    => $server,

      username  => $username,
      password  => $password,

      executors => $executors,
      launcher  => $launcher,
      homedir   => $homedir,
      ssh_user  => $ssh_user,
      ssh_key   => $ssh_key,
      labels    => $labels,
    }
  }

  include java

  case $::operatingsystem {
    'Debian': { include jenkins::agent::debian }

#   default: {
#     fail( "Unsupported operating system: ${::operatingsystem}" )
#   }
  }
}
