#!/bin/sh
# Author: bougyman <tj@rubyists.com>
# License: MIT
# This utility adds helper commands for administering runit services

set -e
commands="sv-list svls sv-find sv-enable sv-disable sv-start sv-stop sv-restart"

# Locate the service in the user's $SVDIR or /etc/sv
find_service() {
  service=$1
  svdir=$(svdir 2>/dev/null)
  if [ "x$service" != "x" ];then
    if [ -L $svdir/$service ];then
      location=$(readlink -f $svdir/$service)
    fi
  fi
  if [ "x$location" != "x" ];then
    echo $location
  else
    if  [ -d /etc/sv/$service ];then
      echo /etc/sv/$service
    elif [ -d "$svdir/../sv/$service" ];then
      echo "$svdir/../sv/$service"
    elif [ -d "$svdir/../Service/$service" ];then
      echo "$svdir/../Service/$service"
    elif [ -d "$svdir/../Services/$service" ];then
      echo "$svdir/../Services/$service"
    fi
  fi
}

# Set to user's $SVDIR or /service
svdir() {
  if [ -z $SVDIR ];then
    #echo "using /service" >&2
    if [ -d /var/service ];then
      svdir=/var/service
    elif [ -d /service ];then
      svdir=/service
    elif [ -d /etc/service ];then
      svdir=/etc/service
    else
      echo "No service directory found" 1>&2
      exit 127
    fi
  else
    #echo "using $SVDIR" >&2
    if [ -d "$SVDIR" ];then
      svdir=$SVDIR
    else
      echo "No service directory found" 1>&2
      exit 127
    fi
  fi
  echo $svdir
}

# Add sudo if we don't own the directory in question
check_owner() {
  lndir=$1
  if [ ! -w $lndir ];then
    echo "sudo "
  fi
}

# Symlink a service (from find_service's path to `svdir`/$service)
enable() {
  echo "Enabling $1" >&2
  service=$1
  svdir=$(find_service $service)
  if [ -z "$svdir" -o ! -d "$svdir" ];then
    echo "No such service '$service'" >&2
    exit 1
  fi
  ln_dir=$(svdir)
  if [ -L "$ln_dir/$service" ];then
    echo "Service already enabled!" >&2
    echo "  $(sv s $ln_dir/$service)" >&2
    exit 1
  fi
  $(check_owner $ln_dir) ln -s $svdir $ln_dir
}

# Remove a symlink of a service (from find_service's path to `svdir`/$service)
disable() {
  echo "Disabling $1" >&2
  service=$1
  ln_dir=$(svdir)
  if [ ! -L "$ln_dir/$service" ];then
    echo "Service not enabled!" >&2
    exit 1
  fi
  $(check_owner $ln_dir) rm $ln_dir/$service
}

# Generic list, of one service or all
list() {
  svdir=$(svdir)
  if [ ! -z "$1" ];then
    $(check_owner $svdir) sv s "$svdir/"$1
  else
    echo "Listing All Services"
    $(check_owner $svdir) sv s "$svdir/"*
  fi
}

make_links() {
  me="$0"
  echo $me
  here="$( cd "$(dirname "$me" )" && pwd )"
  for link in $commands;do
    [ -L "$here/$link" ] || ln -s "$me" "$here/$link"
  done
}

# Usage
usage() {
  cmd=$1
  case "$cmd" in
    sv-enable) echo "sv-enable <service> - Enable a service and start it (will restart on boots)";;
    sv-disable) echo "sv-disable <service> - Disable a service from starting (also stop the service)";;
    sv-stop) echo "sv-stop <service> - Stop a service (will come back on reboot)";;
    sv-start) echo "sv-start <service> - Start a stopped service";;
    sv-restart) echo "sv-restart <service> - Restart a running service";;
    svls) echo "svls [<service>] - Show list of services (Default: all services, pass a service name to see just one)";;
    sv-find) echo "sv-find <service> - Find a service, if it exists";;
    sv-list) echo "sv-list - List available services";;
    make-links) echo "Make symlinks for the individual commands";;
    commands) echo "Valid Commands: ${commands} make-links"
              echo "use command -h for help";;
    *) echo "Invalid command (${commands})";;
  esac
}

# Start main program

cmd=$(basename $0) # Get the command
if [ "$cmd" = "sv-helper" ] || [ "$cmd" = "sv-helper.sh" ];then
  cmd=$1
  if [ "x${cmd}" = "x" ];then
    cmd="commands"
  else
    shift
  fi
fi
# help
while getopts h options
do
  case $options in
    h) echo $(usage $cmd)
       exit;;
  esac
done

svc=$(find_service $@)
case "$cmd" in
  enable|sv-enable) enable $@;;
  disable|sv-disable) disable $@;;
  start|sv-start) $(check_owner $svc) sv u $svc;;
  restart|sv-restart) $(check_owner $svc) sv t $svc;;
  stop|sv-stop) $(check_owner $svc) sv d $svc;;
  ls|svls) list $@;;
  make-links) make_links;;
  find|sv-find) find_service $@;;
  list|sv-list) find $(find_service) -maxdepth 1 -mindepth 1 -type d -exec basename {} \;|sort|tr " " "\n";echo;;
  *) usage commands;;
esac
