#!/bin/bash
# Last update: 14.01.2015
# Status: work in progress, it will install prerequisities, fetch repos, compile sources.
#https://github.com/polcad/e330-service
#
# https://wush.net/trac/rangepublic/wiki/BuildInstallRun
OPENBTS_ROOT=$HOME/bin/openbts/public

function my_echo {
	if [ $LOGDEV = /dev/stdout ]
	then
		echo $*
	else
		echo $*
		echo $* >>$LOGDEV 2>&1
	fi
}
	
function help {
	cat <<!EOF!
	
Usage: build-openbts.sh [--help|-h] [-v|--verbose] [-jN] [-ja] 
                      [-l|--logfile logfile ] [-m] funcs

-m             - Use HEAD of master branch. Use compatible extras as well

-v|--verbose   - turn on verbose logging to stdout

-jN            - have make use N concurrent jobs

-ja            - have make use N concurrent jobs with auto setting of N
                 (based on number of cpu cores on build system)
                          
-l|--logfile lf - log messages to 'lf'
-ot	<tag>   - set tag for OpenBTS checkout to <tag>
-p		- specify custom install location path
-y		- assume YES to all questions
available funcs are:

all             - do all functions
prereqs         - install prerequisites
gitfetch        - use GIT to fetch Gnu Radio and UHD
openbts_build       - build OpenBTS
mod_groups      - modify the /etc/groups and add user to group 'usrp'
mod_udev        - add UDEV rule for USRP1
mod_sysctl      - modify SYSCTL for larger net buffers
!EOF!

}

if [ $USER = root -o $UID -eq 0 ]
then
	echo Please run this script as an ordinary user
	echo   it will acquire root privileges as it needs them via \"sudo\".
	exit
fi


do_not_ask=No
ans=No
VERBOSE=No
JFLAG=""
LOGDEV=/dev/null
USERSLIST=None
JOSHMODE=False
OTAG=None
export LC_LANG=C
EXTRAS=""
MASTER_MODE=0
PULLED_LIST="openbts"
which python3 >/dev/null 2>&1
if [ $? -eq 0 ]
then
			CMAKE_FLAG1=-DPythonLibs_FIND_VERSION:STRING="2.7"
			CMAKE_FLAG2=-DPythonInterp_FIND_VERSION:STRING="2.7"
fi
while : 
do
	case $1 in
		-ja)
			cnt=`grep 'processor.*:' /proc/cpuinfo|wc -l`
			cnt=`expr $cnt - 1`
			if [ $cnt -lt 1 ]
			then
				cnt=1
			fi
			JFLAG=-j$cnt
			shift
			;;
			
		-j[123456789])
			JFLAG=$1
			shift
			;;

		-v|--verbose)
			LOGDEV=/dev/stdout
			shift
			;;
			
		-l|--logfile)
			case $2 in
				/*)
					LOGDEV=$2
				;;
				*)
					LOGDEV=`pwd`/$2
				;;
			esac
			shift
			shift
			rm -f $LOGDEV
			echo $LOGDEV Starts at: `date` >>$LOGDEV 2>&1
			;;
			
		-u|--users)
			USERSLIST=$2
			shift
			shift
			;;
		
		-m|--master)
			MASTER_MODE=1
			shift
			;;

		-o|--old)
		    OLD_MODE=1
		    shift
		    ;;
            
		-h|--help)
			help
			exit
			;;
			
		-ot)
			OTAG=$2
			shift
			shift
			;;
			
		-p)
			CMF1="-DCMAKE_INSTALL_PREFIX=$2"
			shift 2
			;;
			
		-y)
			do_not_ask=YES
			shift
			;;
			
		-*)
			echo Unrecognized option: $1
			echo
			help
			exit
			break
			;;
		*)
			break
			;;
	esac
done

CWD=`pwd`
SUDOASKED=n
SYSTYPE=unknown
good_to_go=no
for file in /etc/fedora-release /etc/linuxmint/info /etc/lsb-release /etc/debian_version /etc/redhat-release
do
	if [ -f $file ]
	then
		good_to_go=yes
	fi
done
if [ $good_to_go = no ]
then
	echo Supported systems: Fedora, Ubuntu, Redhat, Debian, Mint, OpenSuse
	echo You appear to be running none of the above, exiting
	exit
fi

echo This script will install OpenBTS from current GIT sources
echo You will require Internet access from the computer on which this
echo script runs.  You will also require SUDO access. 
echo " "
echo The whole process may take up to one hour to complete, depending on the
echo capabilities of your system.
echo
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo NOTE: if you run into problems while running this script, you can re-run it with
echo the --verbose option to produce lots of diagnostic output to help debug problems.
echo This script has been written to anticipate some of the more common problems one might
echo encounter building ANY large, complex software package.  But it is not pefect, and
echo there are certainly some situations it could encounter that it cannot deal with
echo gracefully.  Altering the system configuration from something reasonably standard,
echo removing parts of the filesystem, moving system libraries around arbitrarily, etc,
echo it likely cannot cope with.  It is just a script.  It isn\'t intuitive or artificially
echo intelligent.  It tries to make life a little easier for you, but at the end of the day
echo if it runs into trouble, a certain amount of knowledge on your part about
echo system configuration and idiosyncrasies will inevitably be necessary.
echo
echo You need SUDO privileges to run this script !!!
echo
echo -n Proceed?

if [ $do_not_ask != 'YES' ]
then
	read ans
else
	ans=YES
fi

case $ans in
	y|Y|YES|yes|Yes)
		PROCEED=y
	;;
	*)
		exit
esac

SPACE=`df $HOME| grep -v blocks|grep '%'`
SPACE=`echo $SPACE | awk '/./ {n=NF-2; printf ("%d\n", $n/1.0e3)}'`


if [ $SPACE -lt 500 ]
then
	echo "You don't appear to have enough free disk space on $HOME"
	echo to complete this build/install
	echo exiting
	doexit DISKSPACE
fi

total=0
for file in $PULLED_LIST
do
	found=0
	for instance in ${file}.20*
	do
		if [ -d $instance ]
		then
			found=1
			sz=`du -s $instance|awk '{print $1}'`
			total=`expr $total + $sz`
		fi
	done
done
total=`expr $total '*' 1024`
total=`expr $total / 1000000`
if [ $total -gt 100 ]
then
	my_echo Your old 'uhd.*' and 'gnuradio.*' etc directories are using roughly $total MB
	my_echo of disk space:
	for file in $PULLED_LIST
	do
		for instance in ${file}.20*
		do
			if [ -d $instance ]
			then
				ls -ld $instance
			fi
		done
	done
	my_echo " "
	my_echo -n Remove them'?'
	read ans
	my_echo $ans
	
	case $ans in
		y|Y|YES|yes|Yes)
			for file in $PULLED_LIST
			do
				for instance in ${file}.20*
				do
					if [ -d $instance ]
					then
						my_echo removing ${instance}
						rm -rf ${instance}
					fi
				done
			done
			my_echo Done
			;;
	esac
fi
rm -rf *.20*.bgmoved


function checkcmd {
	found=0
	which $1 >/dev/null 2>&1
	x=$?
	if [ $x -eq 0 ]
	then
		found=1
	fi
	for place in /bin /usr/bin /usr/local/bin /sbin /usr/sbin /usr/local/sbin /opt/bin /opt/local/bin
	do
		if [ -e $place/$1 ]
		then
			found=1
		fi
	done
	if [ $found -eq 0 ]
	then
		which $1 >/dev/null 2>&1
		if [ $? -eq 0 ]
		then
			found=1
		fi
	fi
	if [ $found -eq 0 ]
	then
		my_echo Failed to find just-installed command \'$1\' after pre-requisite installation.
		my_echo This very likely indicates that the pre-requisite installation failed
		my_echo to install one or more critical pre-requisites for Gnu Radio/UHD
		doexit PREREQFAIL-CMD-$1
	fi
}

function checklib {
	found=0
	my_echo -n Checking for library $1 ...
	for dir in /lib /usr/lib /usr/lib64 /lib64 /usr/lib/x86_64-linux-gnu /usr/lib/i386-linux-gnu \
	    /usr/lib/arm-linux-gnueabihf /usr/lib/arm-linux-gnueabi
	do
		for file in $dir/${1}*.so*
		do
			if [ -e "$file" ]
			then
				found=1
			fi
		done
	done
	if [ $found -le 0 ]
	then
		my_echo Failed to find libraries with prefix \'$1\' after pre-requisite installation.
		my_echo This very likely indicates that the pre-requisite installation failed
		my_echo to install one or more critical pre-requisites for Gnu Radio/UHD
		my_echo exiting build
		doexit PREREQFAIL-LIB-$1
	else
		my_echo Found library $1
	fi
}

function checkpkg {
	my_echo Checking for package $1
	if [ `apt-cache search $1 | wc -l` -eq 0 ]
	then
		my_echo Failed to find package \'$1\' in known package repositories
		my_echo Perhaps you need to add the Ubuntu universe or multiverse PPA?
		my_echo see https://help.ubuntu.com/community/Repositories/Ubuntu
		my_echo exiting build
		doexit PREREQFAIL-PKG-$1
	fi
}
		
function prereqs {
	sudocheck
	my_echo Installing prerequisites.
	my_echo "====>" THIS MAY TAKE QUITE SOME TIME "<====="
	SYSTYPE=Ubuntu
	PKGLIST="autoconf libtool libosip2-dev libortp-dev libusb-1.0-0-dev g++ sqlite3 libsqlite3-dev erlang libreadline6-dev libncurses5-dev"
	CMAKE_FLAG1=-DPythonLibs_FIND_VERSION:STRING="2.7"
	CMAKE_FLAG2=-DPythonInterp_FIND_VERSION:STRING="2.7"
	for pkg in $PKGLIST; do checkpkg $pkg; done
	my_echo Done checking packages
	sudo apt-get -y --ignore-missing install $PKGLIST >>$LOGDEV 2>&1
	PATH=$PATH
	export PATH

	checkcmd git
	checkcmd cmake
	my_echo Done
}

function gitfetch {
	date=`date +%Y%m%d%H%M%S`
	V=3.7/maint

	#sudo apt-get install autoconf libtool libosip2-dev libortp-dev libusb-1.0-0-dev g++ sqlite3 libsqlite3-dev erlang libreadline6-dev libncurses5-dev
	mkdir $HOME/bin/openbts
	cd $HOME/bin/openbts
	svn co http://wush.net/svn/range/software/public
}

function openbts_build {
	cd a53/trunk
	make clean
	make
	sudo make install

	# To enable support for UHD devices regardless of type
	# build OpenBTS
	cd $OPENBTS_ROOT
	cd openbts/trunk
	autoreconf -i
	./configure --with-uhd
	make
	cd apps
	ln -s ../Transceiver52M/transceiver .

	# Configuring OpenBTS
	cd $OPENBTS_ROOT/openbts/trunk
	sudo mkdir /etc/OpenBTS
	sudo sqlite3 -init ./apps/OpenBTS.example.sql /etc/OpenBTS/OpenBTS.db ".quit"
	sqlite3 /etc/OpenBTS/OpenBTS.db .dump >/dev/null 2>&1
	if [ $? -ne 0  ]
	then
		echo Error - Populating OpenBTS.db database failed.
	fi

	# Subscriber Registry, Sipauthserve
	sudo mkdir -p /var/lib/asterisk/sqlite3dir
	cd $OPENBTS_ROOT/subscriberRegistry/trunk
	make
	sudo sqlite3 -init subscriberRegistry.example.sql /etc/OpenBTS/sipauthserve.db ".quit"

	# Smqueue is the store-and-forward message service packaged with OpenBTS.
	cd $OPENBTS_ROOT/smqueue/trunk
	autoreconf -i
	./configure
	make
	sudo sqlite3 -init smqueue/smqueue.example.sql /etc/OpenBTS/smqueue.db ".quit"
}

cd $HOME/bin
echo That\'s all folks...

#Debugging OpenBTS
#
#By default OpenBTS logs to syslogd. As such, you can see all openbts traffic with the following command:
#tail -f /var/log/syslog | grep OpenBTS
