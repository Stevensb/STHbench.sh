#!/bin/bash
#
#		(C) 2013-2014 ServeTheHome.com and ServeThe.biz
#		
#
# 	STHbench - A System Benchmark and comparison tool created by the STH community.
#
#	Should include a description of what the script does right here... 
#	All the benchmarks it includes... packages it installs... actions during runtime etc.
#
#	For more information go:
#	http://forums.servethehome.com/processors-motherboards/2519-introducing-sthbench-sh-benchmark-script.html
#
# 	Authors: Patrick Kennedy, nitrobass24, mir, Chuckleb, Patriot 
#
#   If you find bugs, verify you are on the latest version and then post in:
#	http://forums.servethehome.com/index.php?threads/introducing-the-sthbench-sh-benchmark-script.2519/
#
################################################################################################################################

#Current Version
rev='12.07'


revhist()
{
cat << EOF
	* 1.0 Intial release.
	* 2.0 Added: sysbench (CPU test, redis), Removed apt-get spam(1k lines), Added CentOS support
	* 3.0 Fixed: OS detection for Ubuntu including development/ daily builds)
	* 4.0 Fixed: redis-benchmark issue under some OSes and adds a 6379.conf file for the benchmark
	* 5.0 Fixed: Debian install and redis.
	* 6.0 Fixed: Installer.  Now redis-server shuts down after benchmarking is complete.
	* 7.0 Added: root check, removal code for benchmarks. Updated: Debian installation.
	* 8.0 Added: STREAM, OpenSSL, unzip,crafty benchmarks and lscpu logging.  
	      Updated: lowered prime problem size for sysbench.
	* 9.0 Nothing according to diff...
	* 10.0 Added: NAMD benchmark.  Updated: STREAM benchmark (non-PTS) (I don't see it changed)
	* 11.0 Deprecated crafty benchmark, too single threaded.
	* 12.0 Modularized neatened. 
	* 12.01 Fixed: SLES OS detection. Added: revhist, version, modules and a proper header.
	* 12.02 Seperated Benchmark Download from Runtime.
	* 12.03 Fixed: broken link to apoa1.tar.gz
	* 12.04 Added: Menu, flags: hVR.  Which call: help, Version, Revision History.
	* 12.05 Updated: OpenSSL to latest revision free of heartbleed.
	* 12.06 Fixed: redis config in wrong directory. 
	* 12.07 Fixed: Detection of lscpu for Ubuntu. 
			Added: Detect Docker environment to skip updates/installs
EOF
#exit 1
#Future ideas/plans/hopes/dreams

#Header needs work... read it and you will see.
#proxy configuration either prompted or just hardcoded per run.
# gui menu, yeah I am dreaming...
# work dir 
# separate downloads from benchmark runs.
# log file as STHBench_hostname_timestamp.log
# Run options 
# proxy variables maybe...
# upload options...
# separate or included results parsing script.
# add error checking on downloads...
# Else options for runtime... currently do nothing
}


version()
{
cat << EOF
##############################################################
#  (c) 2014 ServeTheHome.com and ServeThe.biz
# 
#	STHbench $rev
#	- STH Benchmark Suite 
###############################################################

EOF
}


usage() 
{
cat << EOF

usage: $0 

This is the STH benchmark suite. 

ARGS:
        ARG1 - none required for now
        ARG2 - none required for now
        ARG3 - none required for now

OPTIONAL ARGS:
        ARG -- script_option_1 script_option-2 

OPTIONS:
	-h	help (usage info)
    	-V	Version of STHbench
	-R	Revision history

EOF
}


# Verify if the script is executed with Root Privileges #
rootcheck() 
{
	if [[ $EUID -ne 0 ]]; then
   		echo "This script must be run as root" 
		echo "Ex. "sudo ./STHbench""
		exit 1
	fi
}


#############Set Functions################
setup()
{
#not sure this is working...
benchdir=`pwd`
NEED_PTS=1

date_str="+%Y_%m%d_%H%M%S"
full_date=`date $date_str`
host=$(hostname)
log="STHbench"$rev"_"$host"_"$full_date.log
#outdir=$host"_"$full_date
#mkdir $outdir
}


# Update and install required packages (Debian)
Update_Install_Debian()
{
	apt-get -y update && apt-get -y upgrade && apt-get install -f
	apt-get -y install build-essential libx11-dev libglu-dev hardinfo sysbench unzip expect php5-curl php5-common php5-cli php5-gd libfpdi-php gfortran
	apt-get install -f
	dpkg -s phoronix-test-suite 2>&1 > /dev/null 2>&1
	NEED_PTS=$(echo $?)
	mkdir -p /usr/tmp/
	
	if [ $NEED_PTS > 0 ]; then
		wget -N http://phoronix-test-suite.com/releases/repo/pts.debian/files/phoronix-test-suite_4.8.6_all.deb && dpkg -i phoronix-test-suite_4.8.6_all.deb
	fi
}

# Update and install required packages (CentOS/RHEL)
Update_Install_RHEL()
{
	rpm -Uhv http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
	rpm -Uhv http://packages.sw.be/rpmforge-release/rpmforge-release-0.5.2-2.el6.rf.x86_64.rpm
	yum -y update && yum -y upgrade
	yum -y groupinstall "Development Tools" && yum -y install wget sysbench unzip libX11 perl-Time-HiRes mesa-libGLU hardinfo phoronix-test-suite expect php-common glibc.i686 gfortran
}

# Detects which OS and if it is Linux then it will detect which Linux Distribution.
whichdistro() 
{
	OS=`uname -s`
	REV=`uname -r`
	MACH=`uname -m`

	if [ "${OS}" = "SunOS" ] ; then
		OS=Solaris
		DIST=Solaris
		ARCH=`uname -p`	
		OSSTR="${OS} ${REV}(${ARCH} `uname -v`)"
	elif [ "${OS}" = "AIX" ] ; then
		DIST=AIX
		OSSTR="${OS} `oslevel` (`oslevel -r`)"
		
	elif [ "${OS}" = "Linux" ] ; then
		KERNEL=`uname -r`
	
		if [ -f /etc/redhat-release ] ; then
			DIST='RedHat'
			PSUEDONAME=`cat /etc/redhat-release | sed s/.*\(// | sed s/\)//`
			REV=`cat /etc/redhat-release | sed s/.*release\ // | sed s/\ .*//`
			
		elif [ -f /etc/centos-release ] ; then
			DIST='CentOS'
			PSUEDONAME=`cat /etc/centos-release | sed s/.*\(// | sed s/\)//`
			REV=`cat /etc/centos-release | sed s/.*release\ // | sed s/\ .*//`
			
		elif [ -f /etc/SuSE-release ] ; then
			DIST=`cat /etc/SuSE-release | tr "\n" ' '| sed s/VERSION.*//`
			REV=`cat /etc/SuSE-release | tr "\n" ' ' | sed s/.*=\ //`
			
		elif [ -f /etc/mandrake-release ] ; then
			DIST='Mandrake'
			PSUEDONAME=`cat /etc/mandrake-release | sed s/.*\(// | sed s/\)//`
			REV=`cat /etc/mandrake-release | sed s/.*release\ // | sed s/\ .*//`
			
		elif [ -f /etc/debian_version ] ; then
			DIST="Debian"
			PSUEDONAME=`cat /etc/debian_version`
				REV=""

		elif [ -f /etc/UnitedLinux-release ] ; then
			DIST="${DIST}[`cat /etc/UnitedLinux-release | tr "\n" ' ' | sed s/VERSION.*//`]"
			
		else 
			DIST='Not detected'	
		fi
		
		OSSTR="${OS} ${DIST} ${REV}(${PSUEDONAME} ${KERNEL} ${MACH})"
	fi
}


##########	Update and install required packages	###########
dlDependancies()
{
	if [ "${DOCKER}" = "TRUE" ] ; then
	echo "In a Docker container, no updates run."
	elif [ "${DIST}" = "CentOS" ] ; then
	Update_Install_RHEL
	elif [ "${DIST}" = "RedHat" ] ; then
	Update_Install_RHEL
	elif [ "${DIST}" = "Debian" ] ; then
	Update_Install_Debian
	fi
	#Else?   What do we do if its not one of those three?
}


# Display script output and append to log
benchlog()
{
exec > >(tee --append $log)
exec 2>&1
echo ${OSSTR}
}


#System information and log capture.
sysinfo()
{
	#I expect more information to be gathered here.
	
	#Cpu info

eval "strings `which lscpu`" | grep -q version ;
if [ $? = 0 ] ; then 
	lscpu -V
	lscpu -e
	else 
	lscpu;
fi
}


#########	Download Benchmarks ###########

dlBenches()
{
	#enter normal benchdir
	cd $benchdir
### will add option for proxy use of wget.

#Hardinfo
#Downloaded in OS update section... may consider separating it.

#Nix Bench
wget -N https://byte-unixbench.googlecode.com/files/UnixBench5.1.3.tgz 
wget -N http://forums.servethehome.com/pjk/fix-limitation.patch 

#C-ray
wget -N http://www.futuretech.blinkenlights.nl/depot/c-ray-1.1.tar.gz

# STREAM by Dr. John D. McCalpin
wget -N http://www.cs.virginia.edu/stream/FTP/Code/stream.c

# OpenSSL
wget -N http://www.openssl.org/source/openssl-1.0.1g.tar.gz

# redis Benchmark based on feedback. Next step is to add memchached as seen here: http://oldblog.antirez.com/post/redis-memcached-benchmark.html
wget http://download.redis.io/redis-stable.tar.gz
wget http://forums.servethehome.com/pjk/6379.conf

# NPB Benchmarks (need to add remove script)
wget http://forums.servethehome.com/pjk/NPB3.3.1.tar.gz

#NAMD
wget http://forums.servethehome.com/pjk/NAMD_2.9_Linux-x86_64-multicore.tar.gz
wget http://forums.servethehome.com/pjk/apoa1.tar.gz
}


#########	Run Benchmarks	###############
runBenches()
{

#You can turn off individual benches at the bottom of this module.

	# HardInfo
	hardi()
	{
	
	cd $benchdir
	echo "hardinfo starts here"
	hardinfo --generate-report --report-format text 
	}

	# UnixBench 5.1.3
	ubench()
	{

	cd $benchdir
	echo "started ubench"
	tar -zxf UnixBench5.1.3.tgz
	
	cd UnixBench 
	mv ../fix-limitation.patch .	
	time make 
	patch Run fix-limitation.patch
	./Run dhry2reg whetstone-double syscall pipe context1 spawn execl shell1 shell8 shell16
	}

	# C-Ray 1.1
	cray()
	{
	cd $benchdir
	tar -zxf c-ray-1.1.tar.gz && cd c-ray-1.1 && make && cat scene | ./c-ray-mt -t 32 -s 7500x3500 > foo.ppm | tee c-ray1.txt && cat sphfract | ./c-ray-mt -t 32 -s 1920x1200 -r 8 > foo.ppm && cd ..
	}


	# Phoronix Test Suite
	PTS()
	{
	
expect <<EOD
	set timeout -1
	spawn -noecho phoronix-test-suite batch-setup
	expect {
	"Do you agree to these terms and wish to proceed (Y/n):" { send "y\n"; exp_continue }
	"Enable anonymous usage / statistics reporting (Y/n):" { send "n\n"; exp_continue }
	"Enable anonymous statistical reporting of installed software / hardware (Y/n):" { send "n\n"; exp_continue }	

	"Run all test options (Y/n):" { send "y\n"; exp_continue }
	"Save test results when in batch mode (Y/n):" { send "n\n"; exp_continue }
	}
EOD

	phoronix-test-suite batch-benchmark pts/stream pts/compress-7zip pts/openssl pts/pybench
	
	}


	# STREAM by Dr. John D. McCalpin
	stream()
	{
	        cd $benchdir
		gcc stream.c -O3 -march=native -fopenmp -o stream-me

		# Determine number of physical cores (not hyperthread) and set OMP to cores value
		procs=$(grep "physical id" /proc/cpuinfo | sort -u | wc -l)
		pcores=$(grep "cpu cores" /proc/cpuinfo |sort -u |cut -d":" -f2)
		cores=$((procs*pcores))

		export OMP_NUM_THREADS=$cores
		export GOMP_CPU_AFFINITY=0-$((cores-1))
		echo $GOMP_CPU_AFFINITY

		./stream-me
	}


	# OpenSSL
	OSSL()
	{
	        cd $benchdir
		tar -zxvf openssl-1.0.1g.tar.gz 2>&1 >> /dev/null
		cd openssl-1.0.1g/
		./config no-zlib 2>&1 >> /dev/null
		make 2>&1 >> /dev/null
		./apps/openssl speed rsa4096
	}


 	crafty()
 	{
	        cd $benchdir
 		wget -N http://www.craftychess.com/crafty-23.4.zip
 		unzip -o crafty-23.4.zip
 		cd crafty-23.4/
 		export target=LINUX
 		export CFLAGS="-Wall -pipe -O3 -fomit-frame-pointer $CFLAGS"
 		export CXFLAGS="-Wall -pipe -O3 -fomit-frame-pointer"
 		export LDFLAGS="$LDFLAGS -lstdc++"
 		make crafty-make
 		
 		chmod +x crafty
 		./crafty bench end
 	}



	# sysbench CPU test prime
	sysb()
	{
	        cd $benchdir
		echo "Running sysbench CPU Single Thread"
		sysbench --test=cpu --cpu-max-prime=300000 run
		echo "Running sysbench CPU Multi-Threaded"
		nproc=`nproc`
		sysbench --num-threads=${nproc} --test=cpu --cpu-max-prime=500000 run
	}


	# redis Benchmark based on feedback. Next step is to add memchached as seen here: http://oldblog.antirez.com/post/redis-memcached-benchmark.html
	red()
	{
	        cd $benchdir
		#wget http://download.redis.io/redis-stable.tar.gz
		tar xzf redis-stable.tar.gz && cd redis-stable && make install
		#wget http://forums.servethehome.com/pjk/6379.conf
		[[ -d /etc/redis ]] || ( mkdir /etc/redis && cp $benchdir/6379.conf /etc/redis/6379.conf )

		cp utils/redis_init_script /etc/init.d/redis_6379
		[[ -d /var/redis ]] || ( mkdir /var/redis && mkdir /var/redis/6379 )

		service redis_6379 start

		# Original redis benchmark set/ get test

		redis-benchmark -n 1000000 -t set,get -P 32 -q -c 200

		BIN=redis-benchmark

		payload=32
		iterations=100000
		keyspace=100000

		for clients in 1 5 10 20 30 40 50 60 70 80 90 100
		do
			SPEED=0
			for dummy in 0 1 2
			do
				S=$($BIN -n $iterations -r $keyspace -d $payload -c $clients | grep 'per second' | tail -1 | awk '{print $1}')
			VALUE=$(echo $S | awk '{printf "%.0f",$1}')
				if [ $(($VALUE > $SPEED)) != 0 ]
				then
					SPEED=$VALUE
				fi
			done
			echo "$clients $SPEED"
		done

		redis-cli shutdown
	}


	# NPB Benchmarks (need to add remove script)
	NPB()
	{
	        cd $benchdir
		#wget http://forums.servethehome.com/pjk/NPB3.3.1.tar.gz

		tar -zxvf NPB3.3.1.tar.gz
		cd NPB3.3.1/NPB3.3-OMP/


		# Use the provided makefile definitions
		cp config/NAS.samples/make.def.gcc_x86 config/make.def


		# Define which tests to build
		echo "ft A" >> config/suite.def
		#echo "mg A" >> config/suite.def
		#echo "sp A" >> config/suite.def
		#echo "lu A" >> config/suite.def
		echo "bt A" >> config/suite.def
		#echo "is A" >> config/suite.def
		#echo "ep A" >> config/suite.def
		#echo "cg A" >> config/suite.def
		#echo "ua A" >> config/suite.def
		#echo "dc A" >> config/suite.def

		make suite

		# Determine number of physical cores (not hyperthread) and set OMP to cores value
		procs=$(grep "physical id" /proc/cpuinfo | sort -u | wc -l)
		pcores=$(grep "cpu cores" /proc/cpuinfo |sort -u |cut -d":" -f2)
		cores=$((procs*pcores))

		export OMP_NUM_THREADS=$cores

		bin/bt.A.x
		bin/ft.A.x
	}


	# NAMD Benchmark http://www.ks.uiuc.edu/Research/namd/performance.html
	NAMD()
	{
	        cd $benchdir
		cores=$(grep "processor" /proc/cpuinfo | wc -l)

		tar xvfz NAMD_2.9_Linux-x86_64-multicore.tar.gz 
		tar xvfz apoa1.tar.gz

		echo "Using" $cores "threads"
		echo "Running benchmark... (will take a while)"

		cd NAMD_2.9_Linux-x86_64-multicore
		timeperstep=$(./namd2 +p$cores +setcpuaffinity ../apoa1/apoa1.namd | grep "Benchmark time" | tail -1 | cut -d" " -f6)

		echo "Time per step" $timeperstep
	}

	#Individual modules run below...comment them out to prevent them from running.
	
	echo "hardinfo"  
	hardi
	echo "ubench"
	ubench
	echo "cray"
	cray
	echo "PTS"
	PTS
	echo "stream"
	stream
	echo "OSSL"
	OSSL  
	echo "crafty"
	#crafty
	echo "sysbench"
	sysb 
	echo "redis"
	red
	echo "NPB"
	NPB
	echo "NAMD"
	NAMD
}


#Cleanup
Cleanup()
{
	# Remove Redis
	rmRedis()
	{
		rm -rf /etc/redis
		rm -f /etc/init.d/redis_6379
		rm -rf /var/redis
		rm -f /usr/local/bin/redis-benchmark
		rm -f /usr/local/bin/redis-check-aof
		rm -f /usr/local/bin/redis-check-dump
		rm -f /usr/local/bin/redis-cli
		rm -f /usr/local/bin/redis-server
		rm -f redis-stable.tar.gz
		rm -rf redis-stable
	}

	# Remove crafty
	rmCrafty()
	{
		rm -rf crafty-23.4
		rm -r crafty-23.4.zip
	}

	# Remove c-ray
	rmCray()
	{
		rm -f c-ray-1.1.tar.gz
		rm -rf c-ray-1.1
	}

	# Remove OpenSSL
	rmOSSL()
	{
		rm -rf openssl-1.0.1g
	}

	# Remove UnixBench5.1.3.tgz
	rmUbench()
	{
		rm -f UnixBench5.1.3.tgz
		rm -rf UnixBench
	}

	# Remove Phoronix test suite
	rmPTS()
	{
		[ "$NEED_PTS" > "0" -a "$DIST" = "Debian" ] && apt-get -y --purge remove phoronix-test-suite && rm -f phoronix-test-suite_4.8.6_all.deb
	}

	rmRedis
	#rmCrafty (deprecated)
	rmCray
	rmOSSL
	rmUbench
	rmPTS
	
	#return to User Dir
	cd ~/
}


#Runtime  This is where everything is actually run from and called...
#
# 	This is where a menu would go for runtime options...
#

rootcheck



while getopts "hVR" arg; do
  case $arg in
	h)
	usage
	exit 1
	;;
	V)
	version
	exit 1
	;;
	R)
	revhist
	exit 1
	;;
	\?)
     	usage
	exit 1
     	;;
  esac
done

#revhist
echo "version"
version
echo "setup"
setup
echo "whichdistro"
whichdistro
echo "dlDep"
dlDependancies
echo "benchlog"
benchlog
echo "derpinfo"
sysinfo  exiting on sysinfo...
sysinfo
echo "dlBenches"
dlBenches
echo "run benches"
runBenches
echo "Uninstall benches"
echo "cleanup"
Cleanup
echo "done"

#The end, thanks for playing.
