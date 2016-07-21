# $Id$:

class centralauth::params {

        case $::osfamily {
                'RedHat': {

					$ldap_user = "nslcd"
					$ldap_group = "ldap"

					case $::operatingsystem {
						'CentOs': {

							case $::operatingsystemmajrelease {
								'6': {
            		                    $basic_packages = [ "nss-pam-ldapd", "openssh-ldap", "python", "python-ldap" ]
										$cauth_services = [ "nslcd" ]
										$ssl_settings = 'start_tls'
										$tls_reqcert_setting = 'demand'
										$ldapcacertdir = '/etc/openldap/cacerts'
								}
								'7': {
										$basic_packages = [ "nss-pam-ldapd" , "openssh-ldap", "python", "python-ldap" ]
										$cauth_services = [ "nslcd" ]
										$ssl_settings = 'start_tls'
										$tls_reqcert_setting= 'demand'
										$ldapcacertdir = '/etc/openldap/cacerts'
								}

								default: {
									fail("centralauth module: THIS OS VERSION is not yet supported by this module")
								}
							}
						}
						
						'RedHat','OracleLinux': {
							case $::operatingsystemmajrelease {
                                '6','7': {
                                        $basic_packages = [ "nss-pam-ldapd", "python", "python-ldap"  ]
                                        $cauth_services = [ "nslcd" ]
                                        $ssl_settings = 'start_tls'
                                        $tls_reqcert_setting = 'demand'
                                        $ldapcacertdir = '/etc/openldap/cacerts'
                                }

                                default: {
                                    fail("centralauth module: THIS OS VERSION is not yet supported by this module")
                                }
							}
						}
					}
				}
                
                'Debian': {

					$ldap_user = "nslcd"
					$ldap_group = "nslcd"

					case $::operatingsystemmajrelease {
						'8': {
                                $basic_packages = [ "libpam-ldapd", "libnss-ldapd", "nslcd" , "python", "python-ldap" ]
								$cauth_services = [ "nslcd" ]
								$ssl_settings = 'start_tls'
								$tls_reqcert_setting = 'demand'
								$ldapcacertdir = '/etc/ssl/certs'
						}
						'7': {
                                $basic_packages = [ "libpam-ldapd", "libnss-ldapd", "nslcd" , "python", "python-ldap" ]
								$cauth_services = [ "nslcd" ]
								$ssl_settings = 'start_tls'
								$tls_reqcert_setting = 'demand'
								$ldapcacertdir = '/etc/ssl/certs'
						}
						'6': {
                                $basic_packages = [ "libpam-ldapd", "libnss-ldapd", "nslcd" , "python", "python-ldap" ]
								$cauth_services = [ "nslcd" ]
								$ssl_settings = 'start_tls'
								$tls_reqcert_setting = 'demand'
								$ldapcacertdir = '/etc/ssl/certs'
						}
						default: {
							fail("centralauth module: THIS OS VERSION is not yet supported by this module")
						}
					}
                }
				default: {
					fail("centralauth module: THIS OS VERSION is not yet supported by this module")
				}
        }


}
