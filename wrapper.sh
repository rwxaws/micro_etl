#!/bin/bash

# imports
source "$(dirname $0)/pathvars"
source "$(dirname $0)/etl_library/run"
source "$(dirname $0)/etl_library/archive"
source "$(dirname $0)/etl_library/log"
source "$(dirname $0)/etl_library/pid"
source "$(dirname $0)/etl_library/process"
source "$(dirname $0)/etl_library/cosmetics"
source "$(dirname $0)/etl_library/load"
source "$(dirname $0)/etl_library/cleanup"
source "$(dirname $0)/etl_library/checkers"

# get script name (used in emails and logs)
scriptname="$(basename $0)$(date +%Y%m%d_%H:%M:%S)"

main() {
  # get the current seconds
  # used to measure how long the script takes for execution
  secs=$SECONDS

  log::log "time" "$scriptname started"

  # PID stages
  run::runCMD "checkPID_$scriptname" "pid::checkPID"    || return 1
  run::runCMD "createPID_$scriptname" "pid::createPID"  || return 1

  # landing area stages
  run::runCMD "checkdirs" "checkers::checkDirs"         || return 1
  run::runCMD "exclude" "process::excludeFiles"         || return 1 
  run::runCMD "copyla" "process::copyLandingArea"       || return 1

  # table loading stages
  run::runCMD "hdfspush" "load::HDFSPush"               || return 1
  run::runCMD "tmpload" "load::loadTBL "${HQL[tmp]}""   || return 1
  run::runCMD "fnlload" "load::loadTBL "${HQL[final]}"" || return 1
  run::runCMD "id1" "load::loadTBL "${HQL[ID1]}""       || return 1
  run::runCMD "id2" "load::loadTBL "${HQL[ID2]}""       || return 1
  run::runCMD "id3" "load::loadTBL "${HQL[ID3]}""       || return 1

  # finialization stages
  run::runCMD "logLoadedFiles" "log::logLoadedFiles"    || return 1
  run::runCMD "archive" "archive::archiveFiles"         || return 1
  run::runCMD "cleandirs" "cleanup::cleanOperationDirs" || return 1
}

# run main function
main

# check if the main function succeeded or failed
if [[ "$?" -ne 0 ]]; then
  log::log "failure" "$scriptname failed"
else
  cleanup::cleanOperationFiles
fi

cleanup::cleanPID

# measure how long it took to execute
total_time=$(( SECONDS - secs ))
log::log "time" "$scriptname took $(cosmetics::_timeFormatter $total_time)"
