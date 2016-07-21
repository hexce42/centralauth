#: $Id$

class centralauth (
		$ldappriserver = '',
		$ldapsecserver = '',
		$baseou = '',
		$baseou_group = 'access',
		$ldapversion = '3',
		$binddn = '',
		$bindpw = '',
		$sudoers_base = '',
		$groups_local=[]
) inherits centralauth::params {

	
	package { $centralauth::params::basic_packages:
		ensure => present,
	}  

	service { $centralauth::params::cauth_services:
		ensure => running,
		enable => true,
		require => Package[$centralauth::params::basic_packages],
	}
	
	file {"/usr/local/sbin/ldap_mig.py":
		ensure => present,
		owner => "root",
		group => "root",
		mode => "760",
		source => "puppet:///modules/${module_name}/ldap_mig.py",
		require => Package[$centralauth::params::basic_packages],
	}

	file {"/etc/profile.d/ldap_mig.sh":
        ensure => present,
        owner => "root",
        group => "root",
        mode => "644",
        source => "puppet:///modules/${module_name}/ldap_mig.sh",
        require => Package[$centralauth::params::basic_packages],
    }


	cron { 'ldap-mig':
    ensure  => $ensure,
    command => '/usr/local/sbin/ldap_mig.py mail peter.szijarto@elephanttalk.com',
    user    => 'root',
    hour    => '4',
    minute  => '0',
    require => File['/usr/local/sbin/ldap_mig.py'],
	  }

	exec { 'set_uid_max_to_2000':
		path => "/bin/:/sbin/:/usr/sbin/:/usr/bin",
		command => "sed -i 's/^\(UID_MAX[ \t]*\)\(.*\)$/\12000/' /etc/login.defs",
		unless => "grep '^UID_MAX' /etc/login.defs | sed 's/^UID_MAX[_\t]*//' | grep 2000 > /dev/null 2>&1",
	}

	exec { 'set_gid_max_to_2000':
        path => "/bin/:/sbin/:/usr/sbin/:/usr/bin",
        command => "sed -i 's/^\(GID_MAX[ \t]*\)\(.*\)/\12000/' /etc/login.defs",
        unless => "grep '^GID_MAX' /etc/login.defs | sed 's/^GID_MAX[ \t]*//' | grep 2000 > /dev/null 2>&1",
    }

	case $::osfamily {
		'RedHat': {

			package { "remove_ipa_client":
				name => 'ipa-client',
				ensure => 'absent',
			}

			package { "remove_sssd":
				name => 'sssd',
				ensure => 'absent',
				require => Package['remove_ipa_client'],
			}

			exec { "set_authentication_redhat":
				path => "/bin/:/sbin/:/usr/sbin/",
				command => "authconfig --update --useshadow --enableldap --enableldapauth --disablesssd --disablesssdauth --ldapserver=${ldappriserver},${ldapsecserver} --ldapbasedn=dc=elephant,dc=linux --enableldaptls --enablemkhomedir",
				unless => "grep ${ldappriserver} /etc/openldap/ldap.conf > /dev/null 2>&1 && grep \"files ldap\" /etc/nsswitch.conf > /dev/null 2>&1",
				require=> Package['remove_sssd']
			}

			file {"/etc/nslcd.conf":
				ensure => present,
				owner => "root",
				group => "root",
				mode => "0600",
				content => template("${module_name}/nslcd.conf.erb"),
				require => Package[$centralauth::params::basic_packages],
				notify => Service[$centralauth::params::cauth_services],
			}

			exec { "rehash_certdir_redhat":
				path => "/sbin/:/usr/sbin/:/bin/:/usr/bin/",
				command => "cacertdir_rehash ${ldapcacertdir}",
				unless => "test $(find /etc/openldap/cacerts/ -type l | wc -l) = 1",
				require => File["${ldapcacertdir}/etit_ca.pem"]
			}

           file {"${ldapcacertdir}/etit_ca.pem":
                ensure => present,
                owner => "root",
                group => "root",
                mode => "0644",
                source => "puppet:///modules/${module_name}/etit_ca.pem",
                require => Exec['set_authentication_redhat'],
                }


			file {"/etc/sudo-ldap.conf":
				ensure => present,
				owner => "root",
				group => "root",
				mode => "0640",
				content => template("${module_name}/sudo-ldap.conf.erb"),
			}

			exec {"add_sudoers_to_nsswitch":
				path => "/bin/",
				unless => "grep sudoers /etc/nsswitch.conf > /dev/null 2>&1",
				command => "echo 'sudoers:	files ldap\n' >> /etc/nsswitch.conf",
				require => Exec['set_authentication_redhat'],
			}

#Not working on redhat 6, no openssl-ldap package
			case $::operatingsystem {
				'CentOS': {
					file {"/etc/ssh/ldap.conf":
					ensure => present,
	       	        owner => "root",
	           	    group => "root",
	               	 mode => "0644",
	                content => template("${module_name}/ssh-ldap.conf.erb"),
					require => Package[$centralauth::params::basic_packages],
	       	     	}
				}
			}

			case $::operatingsystemmajrelease {
				'6': {
					file {"/etc/pam_ldap.conf":
                        ensure => link,
                        target => "/etc/nslcd.conf",
                        require => File["/etc/nslcd.conf"],
                        }

				    file {"/usr/sbin/nologin":
						ensure => link,
						target => "/sbin/nologin"
						}

					exec {"add_usr_sbin_nologin_to_shells":
						path => "/bin/",
		                unless => "grep \"/usr/sbin/nologin\" /etc/shells > /dev/null 2>&1",
        		        command => "echo \"/usr/sbin/nologin\" >> /etc/shells",
						require => File['/usr/sbin/nologin'],
						}

				}
			}
		}


		'Debian': {
			file {"/etc/nslcd.conf":
				ensure => present,
				owner => "root",
				group => $centralauth::params::ldap_group,
				mode => "0640",
				content => template("${module_name}/nslcd.conf.erb"),
				notify => Service[$centralauth::params::cauth_services],
				require => Package[$centralauth::params::basic_packages]
				}

			case $::operatingsystemmajrelease {
				'7','8': {
					file {"/usr/local/share/ca-certificates/etit_ca.pem":
        	        	ensure => present,
	        	        owner => "root",
	            	    group => "root",
    	            	mode => "0644",
	        	        source => "puppet:///modules/${module_name}/etit_ca.pem",
						}

					file {"/etc/ssl/certs/etit_ca.pem":
						ensure => link,
						target => "/usr/local/share/ca-certificates/etit_ca.pem",
						require => File["/usr/local/share/ca-certificates/etit_ca.pem"],
						notify => Exec["rehash_certdir_debian"]
						}
					
					service {"centralauth_nscd":
						name => "nscd",
						ensure => false,
					}
				}

				'6': {
					file {"/etc/ssl/certs/etit_ca.pem":
                        ensure => present,
                        owner => "root",
                        group => "root",
                        mode => "0644",
                        source => "puppet:///modules/${module_name}/etit_ca.pem",
                        }
					}

			}				

			exec {"rehash_certdir_debian":
				command => "/usr/bin/c_rehash /etc/ssl/certs",
				refreshonly => true,
				}

			file {"/etc/pam.d/common-auth":
				ensure => present,
				owner => "root",
				group => "root",
				mode => "0644",
				require => Package[$centralauth::params::basic_packages],
				source => "puppet:///modules/${module_name}/pamDebian/common-auth.erb"
				}

            file {"/etc/pam.d/common-account":
                ensure => present,
                owner => "root",
                group => "root",
                mode => "0644",
                require => Package[$centralauth::params::basic_packages],
                source => "puppet:///modules/${module_name}/pamDebian/common-account.erb"
                }

            file {"/etc/pam.d/common-session":
                ensure => present,
                owner => "root",
                group => "root",
                mode => "0644",
                require => Package[$centralauth::params::basic_packages],
                source => "puppet:///modules/${module_name}/pamDebian/common-session.erb"
                }

            file {"/etc/pam.d/common-password":
                ensure => present,
                owner => "root",
                group => "root",
                mode => "0644",
                require => Package[$centralauth::params::basic_packages],
                source => "puppet:///modules/${module_name}/pamDebian/common-password.erb"
                }

            file {"/etc/nsswitch.conf":
                ensure => present,
                owner => "root",
                group => "root",
                mode => "0644",
                require => Package[$centralauth::params::basic_packages],
                source => "puppet:///modules/${module_name}/nsswitch.conf.erb"
                }

            file {"/etc/ldap/ldap.conf":
                ensure => present,
                owner => "root",
                group => "root",
                mode => "0644",
                content => template("${module_name}/sudo-ldap.conf.erb"),
	            }
			
            file {"/etc/sudo-ldap.conf":
                ensure => link,
                target => "/etc/ldap/ldap.conf",
                require => File["/etc/ldap/ldap.conf"],
                }

            exec {"add_sudoers_to_nsswitch":
                path => "/bin/",
                unless => "grep sudoers /etc/nsswitch.conf > /dev/null 2>&1",
                command => "echo 'sudoers:  files ldap\n' >> /etc/nsswitch.conf"
            }




		}
	}
}
