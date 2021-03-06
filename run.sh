#!/bin/bash 
# On deterministic-kernel

pwd_normal=$PWD # save starting top-dir

# set -x 
mkdir -p kernel-sources/kernel

. kernel-build/linux-mempo/env.sh

kernel_version="$kernel_general_version" # from env.sh
kernel_file="linux-${kernel_version}.tar"
kernel_file_download="${kernel_file}.xz" # the compressed for download version of file
user_download_folder="${HOME}/Downloads/" # where user stores downloads, use this as download cache (read it, write ther)

. support.sh

export LC_ALL="C"

function warn_env() {
	echo "Currently, if you want to get the same checksums as other users,"
	echo "then you must run this script as unix user 'kernelbuild' (create new user), "
	echo "and in directory /home/kernelbuild/deterministic-kernel/ (git clone in home, or copy files there)"
}

echo "-------------------------------------------------------------------------"

echo "Checking environment"

df_need_mb=$((11*1024))
df_need=$((df_need_mb*1024*1024))
df_now=$(($(stat -f --format="%a*%S" .)))

if [[ $df_now -lt $df_need ]] ; then
	echo ; echo "WARNING: LOW DISK SPACE ($df_now < $df_need bytes)"
	echo "the build process might use around $df_need_mb MB of disk space"
	echo "you seem to have less free space here (in $PWD)"
	ask_quit "nosum";
fi

id=$(id -u )
echo " * USER=$USER (id=$id)"

if [[ $id -eq 0 ]] ; then 
	echo ; echo "ERROR: Do not run this script as root (uid 0) (this is not needed at all)." ; warn_env ;	exit_error
fi

if [[ $USER == "root" ]] ; then 
	echo ; echo "ERROR: Do not run this script as user root (this is not needed at all)." ; warn_env ;	exit_error
fi

USER="kernelbuild"
if [[ $USER != 'kernelbuild' ]] ; then
	echo ; echo "WARNING: wrong user ($USER)." ; warn_env ;	ask_quit;
fi

echo " * PWD=$PWD"
good_dir='/home/kernelbuild/deterministic-kernel'
if [[ $PWD != "$good_dir" ]] ; then
	echo ; echo "WARNING: wrong directory '$PWD' should be '$good_dir'." ; warn_env ;	ask_quit;
fi

echo "" ; echo "Tools: checking prerequisites..."
DPKG_VER=$(dpkg-query -W --showformat='${Version}\n' dpkg)
DPKG_VER_NEEDED="1.17.5" # more exact checks in prepare-toolchain.sh

function show_dpkg_why {
	echo "We need dpkg version that packs files in same way, see http://tinyurl.com/pcrrvag and https://wiki.debian.org/ReproducibleBuildsKernel"
}

function show_mempo_contact {
	echo "~~ Problems, questions, suggestions or will to help us? ~~ Contact Mempo at IRC" 
	echo "IRC channel #mempo on irc.oftc.net (tor allowed), irc2p (i2p2.de then localhost 6668) or irc.freenode.org."
	echo "We will gladly help fellow Hackers and security researchers."
}

echo "-------------------------------------------------------------------------"
. prepare-toolchain.sh # check toolchain and libs
echo ""

echo "-------------------------------------------------------------------------"
echo "Will get kernel sources (will verify checksum later - before actually using them)"

function download_wget() {
	echo "Downloading: " $@
	wget $@
}

echo "Kernel: $kernel_version"


echo "======================================================="
echo "Please, make sure that: "
echo "you run an updated system (or if you build old version, then tools like gcc need to match the old situation"
echo "======================================================="

if [ ! -r "kernel-sources/kernel/${kernel_file}" ]
then
(
	echo "Kernel sources are not ready (${kernel_file})"

	if [ ! -r "kernel-sources/kernel/${kernel_file_download}" ]
	then
		echo "Kernel sources are not downloaded to kernel-sources yet (${kernel_file_download})"
		if [ ! -r "${user_download_folder}/${kernel_file_download}" ]
		then
			echo "Kernel sources are not cached in ${user_download_folder}"

			echo "Need .xz to download from the Internet."
			download_wget "https://www.kernel.org/pub/linux/kernel/v3.x/${kernel_file_download}" -O "kernel-sources/kernel/${kernel_file_download}"

			echo "We downloaded the file from internet, and we will now save it into ${user_download_folder}"
			mkdir -p "${user_download_folder}/"
			cp "kernel-sources/kernel/${kernel_file_download}" "${user_download_folder}/" # cache it

		else
			echo "Kernel sources ARE cached in ${user_download_folder}. If this file would be bad then delete it and try again to really download."
			cp "${user_download_folder}/${kernel_file_download}" "kernel-sources/kernel/${kernel_file_download}" # load from cache
		fi
	
	else
		echo "Kernel sources were downloaded to kernel-sources already."
	fi

	(
		echo "Unpacking the downloaded file"
		cd "kernel-sources/kernel/" 
		file linux-${kernel_version}.tar.xz
		unxz linux-${kernel_version}.tar.xz
		chmod 755 linux-${kernel_version}.tar*
	)
)
#cd ..
fi


echo "-------------------------------------------------------------------------"
echo "Removing any previous .deb files"
cd $pwd_normal
#mkdir kernel-build/linux-mempo/_previous-build/
#mv kernel-build/linux-mempo/*.deb  kernel-build/linux-mempo/_previous-build/ # 
rm -f kernel-build/linux-mempo/*.deb


cd $pwd_normal
# TODO nicer way of entering the correct one / warning if more then one
cd kernel-build/linux-mempo || { echo "Can not enter build directory." ; exit_error; }
echo 
echo "Executing the build script"
echo 
echo "Will now execute ./all.sh to build the kernel."
bash ./all.sh $@ || { echo ; echo "WARNING: Build of kernel seem to had some problems? (exit-code)" ; }
set +x
echo "-------------------------------------------------------------------------"


cd $pwd_normal

echo "===== PUBLISH THIS ====== 8< ---cut here--- 8< --------------------------"
echo "Please check sha256sum checksums of the generated .deb files that you can find here below:"
sha256sum kernel-build/linux-mempo/*.deb || { echo ; echo "WARNING: can not find the produced .deb files! it seems the build failed! Please report this problem to us!"; exit_error; }
echo "github version is: "
git tag -v `git describe --tags`
echo "----- 8< ------ 8< ------ 8< ---cut here--- 8< --------------------------"
echo 
echo -n "PRIVATE information FYI: This build was (completed) at date: " ; date
echo -n "PRIVATE information FYI: This build was done on hostname=" ; hostname 

echo
echo "If you see checksums line above, then please compare/publish them with other users."
echo ""
echo "---INSTALL---"
echo "If the debs were created, you can now INSTALL the .deb files :) first read https://wiki.debian.org/SameKernel#FAQ or here doc-mirror/"
echo "Run any extra scripts first, like described on page, e.g. setfattr, otherwise grsecurity might block some applications."
echo "The setfattr script is also here in sources tree, see apps/"
echo ""
echo "Thanks for using this script! Join us and idle on irc #mempo irc.oftc.net or irc2p or freenode"
echo "-- Mempo team < https://wiki.debian.org/Mempo >"


