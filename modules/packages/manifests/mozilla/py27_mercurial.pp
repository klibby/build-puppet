# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
class packages::mozilla::py27_mercurial {


    anchor {
        'packages::mozilla::py27_mercurial::begin': ;
        'packages::mozilla::py27_mercurial::end': ;
    }

    include packages::mozilla::python27
    include mercurial::system_hgrc
    if ($::operatingsystem != Windows) {
        include mercurial::ext::bundleclone
    }

    case $::operatingsystem {
        CentOS: {
            $mercurial = "/tools/python27-mercurial/bin/hg"
            realize(Packages::Yumrepo['mozilla-mercurial'])
            Anchor['packages::mozilla::py27_mercurial::begin'] ->
            package {
                "mozilla-python27-mercurial":
                    ensure => '3.7.3-1.el6',
                    require => Class['packages::mozilla::python27'];
            } -> Anchor['packages::mozilla::py27_mercurial::end']
        }
        Ubuntu: {
            $mercurial = "/tools/python27-mercurial/bin/hg"
            case $::operatingsystemrelease {
                12.04: {
                    realize(Packages::Aptrepo['mozilla-mercurial'])
                    Anchor['packages::mozilla::py27_mercurial::begin'] ->
                    package {
                        "mozilla-python27-mercurial":
                            ensure => '3.7.3-1mozilla2',
                            require => Class['packages::mozilla::python27'];
                    } -> Anchor['packages::mozilla::py27_mercurial::end']

                    # Some things want to find hg in /usr/bin, so symlink
                    # but only if its not present from another package
                    file {
                        "/usr/bin/hg":
                            ensure => "link",
                            replace => "no",
                            mode => 755, # if the binary is here, the symlink won't care
                            target => $mercurial;
                    }
                }
                default: {
                    fail("Cannot install on Ubuntu version $::operatingsystemrelease")
                }
            }
        }
        Darwin: {
            $mercurial = "/tools/python27-mercurial/bin/hg"
            Anchor['packages::mozilla::py27_mercurial::begin'] ->
            packages::pkgdmg {
                python27-mercurial:
                    version => "3.7.3-2";
            } -> Anchor['packages::mozilla::py27_mercurial::end']
        }
        Windows: {
            include packages::mozilla::mozilla_build
            $mercurial = 'C:\mozilla-build\hg\hg.exe'
            $merc_exe = $hardwaremodel ? {
                i686    => "Mercurial-3.7.3.exe",
                default => "Mercurial-3.7.3-x64.exe",
            }
            $merc_exe_dir = "C:\\installersource\\puppetagain.pub.build.mozilla.org\\EXEs\\"
            $merc_exe_flag = " /SILENT /DIR=C:\\mozilla-build\\hg"
            $merc_cmd = "$merc_exe_dir$merc_exe$merc_exe_flag"

            Anchor['packages::mozilla::py27_mercurial::begin'] ->
            # This is a temporary work around until we have Windows package management in place 
            # Ref Bugs 1178487 & 1170588 for the reasons behind Mercurial-3.2.1 being handled this manner
            file { "C:/installersource/puppetagain.pub.build.mozilla.org/EXEs/$merc_exe" :
                ensure => file,
                source => "puppet:///repos/EXEs/$merc_exe",
            }
            case $::fqdn {
                /.*\.releng\.(use1|usw2)\.mozilla\.com$/: {
                    Anchor['packages::mozilla::py27_mercurial::begin'] ->
                    exec { "$merc_exe":
                        command  => "$merc_cmd",
                        require  => Exec["remove_old_hg"],
                        creates  => "C:\\mozilla-build\\hg\\msvcp90.dll",
                    } -> Anchor['packages::mozilla::py27_mercurial::end']
                }
                default: {
                    Anchor['packages::mozilla::py27_mercurial::begin'] ->
                    exec { "$merc_exe":
                            command => 'C:\Windows\system32\schtasks.exe /ru SYSTEM /create /sc once /st 23:59  /tn merc_exe /tr "C:\installersource\puppetagain.pub.build.mozilla.org\EXEs\Mercurial-3.7.3.exe /SILENT /DIR=C:\mozilla-build\hg"',
                            require  => Exec["remove_old_hg"],
                            creates  => "C:\\mozilla-build\\hg\\msvcp90.dll",
                    } -> exec { "trigger_$merc_exe":
                            command  => "C:\\Windows\\system32\\schtasks.exe /run /tn merc_exe",
                            subscribe => Exec["$merc_exe"],
                            refreshonly => true,
                    } -> Anchor['packages::mozilla::py27_mercurial::end']
                }
            }
        }
        default: {
            fail("cannot install on $::operatingsystem")
        }
    }
}
