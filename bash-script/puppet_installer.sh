#!/bin/bash

debug=0   # options 0 | 1 

# set variables 
declare -r TRUE=0
declare -r FALSE=1
declare -r RED='\033[0;41;30m'
declare -r STD='\033[0;0;39m'
declare -r CYAN='\e[1;37;44m'
declare -r TMPDIR='/tmp/'


## library of commands
##################################################################
# Purpose: Return true if script is executed by the root user
# Arguments: none
# Return: True or False
##################################################################
function is_root() 
{
   [ $(id -u) -eq 0 ] && return $TRUE || return $FALSE
}

##################################################################
# Purpose: Display an error message and die
# Arguments:
#   $1 -> Message
#   $2 -> Exit status (optional)
##################################################################
function die() 
{
    local m="$1"	# message
    local e=${2-1}	# default exit status 1
    echo "$m" 
    exit $e
}
##################################################################
# Purpose: Display message and move on 
# Arguments:
#   $1 -> Message
#   $2 -> Exit status (optional)
##################################################################
function tell() 
{
    local m="$1"	# message
    local e=${2-0}	# default exit status 0
[ $debug -eq 1 ] &&   echo "$m" 
    return $e
}

##################################################################
# Purpose: Converts a string to lower case
# Arguments:
#   $1 -> String to convert to lower case
##################################################################
lowercase(){
	echo "$1" | sed "y/ABCDEFGHIJKLMNOPQRSTUVWXYZ/abcdefghijklmnopqrstuvwxyz/"
}

##################################################################
# Purpose: Recover important information 
# Arguments: If $1 == "debug" then output for each var will be printed
# Return: TRUE is first time execution. FALSE if already executed
# Read Only variables set:
#	OS
#	DIST
#	DistroBasedOn
#	PSUEDONAME
#	REV
#	KERNEL
#	MACH
##################################################################
shootProfile(){
	 # This funcion creates readonly variables, if one of them has been set before it will crash
	 # check that all variables are unset.
	 
[ -n "${OS+x}" ] && [ -n "${DIST+x}" ] && [ -n "${DistroBasedOn+x}" ] && [ -n "${PSEUDONAME+x}" ] && [ -n "${REV+x}" ] && [ -n "${KERNEL+x}" ] && [ -n "${MACH+x}" ] && echo " !!! shootProfile was called before. The variables are already available" &&  return $FALSE

	 OS=`lowercase \`uname\``
	 KERNEL=`uname -r`
	 MACH=`uname -m`

	 if [ "{$OS}" == "windowsnt" ]; then
		  OS=windows
	 elif [ "{$OS}" == "darwin" ]; then
		  OS=mac
	 else
		  OS=`uname`
		  if [ "${OS}" = "SunOS" ] ; then
				OS=Solaris
				ARCH=`uname -p`
				OSSTR="${OS} ${REV}(${ARCH} `uname -v`)"
			elif [ "${OS}" = "AIX" ] ; then
				OSSTR="${OS} `oslevel` (`oslevel -r`)"
			elif [ "${OS}" = "Linux" ] ; then
				if [ -f /etc/redhat-release ] ; then
					 DistroBasedOn='RedHat'
					 DIST=`cat /etc/redhat-release |sed s/\ release.*//`
					 PSEUDONAME=`cat /etc/redhat-release | sed s/.*\(// | sed s/\)//`
					 REV=`cat /etc/redhat-release | sed s/.*release\ // | sed s/\ .*//`
				elif [ -f /etc/SuSE-release ] ; then
					 DistroBasedOn='SuSe'
					 PSEUDONAME=`cat /etc/SuSE-release | tr "\n" ' '| sed s/VERSION.*//`
					 REV=`cat /etc/SuSE-release | tr "\n" ' ' | sed s/.*=\ //`
				elif [ -f /etc/mandrake-release ] ; then
					 DistroBasedOn='Mandrake'
					 PSEUDONAME=`cat /etc/mandrake-release | sed s/.*\(// | sed s/\)//`
					 REV=`cat /etc/mandrake-release | sed s/.*release\ // | sed s/\ .*//`
				 elif [ -f /etc/debian_version ] ; then
					 DistroBasedOn='Debian'
					 DIST=`cat /etc/debian_version | grep '^DISTRIB_ID' | awk -F= '{ print $2 }'`
					 PSEUDONAME=`cat /etc/debian_version | grep '^DISTRIB_CODENAME' | awk -F= '{ print $2 }'`
					 REV=`cat /etc/debian_version | grep '^DISTRIB_RELEASE' | awk -F= '{ print $2 }'`
				 fi
				 if [ -f /etc/UnitedLinux-release ] ; then
					 DIST="${DIST}[`cat /etc/UnitedLinux-release | tr "\n" ' ' | sed s/VERSION.*//`]"
				  fi
				OS=`lowercase $OS`
				DistroBasedOn=`lowercase $DistroBasedOn`
				REVISION=`echo $REV |cut -d'.' -f1`
				readonly OS
				readonly DIST
				readonly DistroBasedOn
				readonly PSEUDONAME
				readonly REV
				readonly REVISION
				readonly KERNEL
				readonly MACH
		  fi

	 fi
	local debug=${1:-nodebug}
	 if [[ $debug = "debug" ]]; then
				echo OS $OS
				echo DIST $DIST
				echo DistroBasedOn $DistroBasedOn
				echo PSEUDONAME $PSEUDDONAME
				echo REV $REV
				echo REVISION $REVISION
				echo KERNEL $KERNEL
				echo MACH $MACH
	 fi
	 return $TRUE
}

##################################################################
# Purpose: Make sure package on $1 is installed 
# Arguments:
#   $@ -> Packages wich should be installed
##################################################################
installPkg()
{
	 [ -n "${DistroBasedOn+x}" ] && tell "shootProfile has been run correctly on installPkg" || die "shootprofile needed"
	for i in $@
	do
		echo -n "Installing $i on $DistroBasedOn."
		case $DistroBasedOn in
			Debian | debian )
				 apt-get -y install $i
				 ;;
			SuSe | suse )
				 zypper install $i
				 ;;
			RedHat | redhat )
				 yum -y install $i
				 ;;
			*)
				 echo "\$DistroBasedOn variable has not a valid value. Value : ||$DistroBasedOn||"
				 ;;
		esac
	done
return 0
}

##################################################################
# Purpose: Prepare system for package installation 
# Arguments:
#
##################################################################
setUpInstallPkg()
{
         
	[ -n "${DistroBasedOn+x}" ] && tell  "shootProfile has  been run correctly. We are on setUPInstallPkg" || die "neeed shootprofile"
              
	  echo -n "Installing $i on    $DistroBasedOn      ."
                case $DistroBasedOn in
                        Debian | debian )
				# Older versions of Debian don't have lsb_release by default, so 
				# install that if we have to.
				which lsb_release || apt-get install -y lsb-release
				
				# Load up the release information
				DISTRIB_CODENAME=$(lsb_release -c -s)
				
				REPO_DEB_URL="http://apt.puppetlabs.com/puppetlabs-release-${DISTRIB_CODENAME}.deb"
				
				apt-get install -y wget > /dev/null
				apt-get update > /dev/null

				# Install the PuppetLabs repo
				echo "Configuring PuppetLabs repo..."
				repo_deb_path=$(mktemp)
				wget --output-document="${repo_deb_path}" "${REPO_DEB_URL}" 2>/dev/null
				dpkg -i "${repo_deb_path}" >/dev/null
				apt-get update >/dev/null

				# Install Puppet
				echo "Installing Puppet..."
				DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" install puppet >/dev/null

				echo "Puppet installed!"

                                ;;
                        SuSe | suse )
 #                                zypper install $i
                                 ;;
                        RedHat | redhat )
				rpm -ivh http://yum.puppetlabs.com/puppetlabs-release-el-${REVISION}.noarch.rpm 
                                 ;;
                        *)
                                 echo "\$DistroBasedOn variable has not a valid value. Value : ||$DistroBasedOn||"
                                 ;;
                esac
        
return 0
}
##################################################################
# Purpose: Finish the installation and startup of the package
# Arguments:
#
##################################################################
finishInstallPkg()
{
####################THIS BLOCK IS FOR ALL SYSTEMS 

CONF_DIR=/etc/puppet
CONF_FILE=$CONF_DIR/puppet.conf
SERVER_IP="10.1.100.249"
SERVER_FQDN="orchestrator01.santfeliu.local"
SERVER_NAME="orchestrator01"
HOSTS_FILE=/etc/hosts

  	# Configure /etc/hosts file
[ `egrep $SERVER_IP $HOSTS_FILE |wc -l` -gt 0 ] || echo "$SERVER_IP $SERVER_FQDN $SERVER_NAME" >> $HOSTS_FILE

    	# Add agent section to $CONF_FILE (sets run interval to 120 seconds)
    	[ -d $CONF_DIR ] || die "Something went wrong, $CONF_DIR does not exist" 
    	[ -e $CONF_FILE ] && cp $CONF_FILE{,.orig} 
        echo " [main] " > $CONF_FILE
	echo " logdir=/var/log/puppet " >> $CONF_FILE
        echo " vardir=/var/lib/puppet " >> $CONF_FILE
        echo " ssldir=/var/lib/puppet/ssl " >> $CONF_FILE
        echo " rundir=/var/run/puppet " >> $CONF_FILE
        echo " factpath=$vardir/lib/facter " >> $CONF_FILE
	echo " show_diff = true " >> $CONF_FILE
        echo " [agent] " >> $CONF_FILE 
    	echo " server = $SERVER_FQDN " >>  $CONF_FILE 
    	echo " runinterval = 120" >> $CONF_FILE
       

	puppet resource service puppet ensure=running enable=true
    	puppet agent --enable


return 0
}



#Action starts here
#Gather info

[ $(is_root) ] && die "Must be root." || tell "Root => ok." 
[ `ps axu|grep puppet |grep -v grep|grep -v $0 | wc -l` -gt 0 ] && die "puppet already running"
#is puppet already installed
if which puppet > /dev/null 2>&1; then
	echo "Puppet is already installed."
	exit 0
fi

[ $debug -eq 1 ] && shootProfile debug || shootProfile 
setUpInstallPkg
installPkg puppet
#is puppet already installed now ?
if which puppet > /dev/null 2>&1; then
	echo "Puppet has been installed."
else
	echo "Puppet has bnot been installed. Quiting."
	exit 0
fi


finishInstallPkg

#puppet agent --test &
echo "Done. :)"

exit 0





