# -*- mode: powershell -*-
#
# Starts the base image for use as a shell.
#
# The latest version of this script is available at:
#
# https://raw.githubusercontent.com/onspot-tools/devlab/master/startscripts/devlab.ps1
#
# If you already have devlab with you, the script is also in there:
#
# docker cp devlab:/opt/scripts/devlab.ps1 .
#
# will get this script out from a running devlab. Note that the
# script got from your devlab might not be the latest one published
# unless you have also pulled the latest devlab from dockerhub:
#
# docker pull onspot/devlab-<lang>:<version>
#
# Author: arvindd
# Created: 21.Apr.2021
#
# Copyright (c) 2021 Arvind Devarajan
# Licensed to you under the MIT License.
# See the LICENSE file in the project root for more information.
#

# First, collect all options
[CmdletBinding()]
Param(
  [Parameter()]
  [String]$l = "base",
  [String]$v = "latest",
  [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
  [String]$progarg = "tmux"
)

function Usage {
Write-Host "Invalid command. Usage:" -foreground red
@"
devlab [-l <lang>] [-v <version>] <command>

Options:
-l <lang> - Language devlab to be started. Default: Python and Julia
-v <version> - Version of the language devlab to be started. Default: latest

<command> can be one of:
tmux - Starts a zsh shell with tmux
lab - Starts the jupyter lab
nb OR notebook - Starts the jupyter notebook
notmux - Starts a zsh shell without tmux
stop - Stops the started jupyter (lab or notebook)

If no arguments are given, devlab starts a zsh shell with tmux.
"@

exit 0
}

# First, check if we are already running the devlab
$cnt = docker ps --filter "name=devlab" | Measure-Object -line
if ( $cnt.Lines -eq 2 ) {
    # devlab is already running; so either stop it or 
    # ask the user to stop it.
    if ( $progarg -eq "stop" ) {
        Write-Output "Stopped"
        docker stop devlab
        exit 0
    } else {
        Write-Output "devlab is already running."
        Write-Output "Stop it with 'devlab stop' before starting again."
        exit 1
    }
} else {
    # devlab is not running. We will not accept '--stop' as an argument
    # because, well, you cannot stop a stopped devlab :-)    
    if ( $progarg -eq "stop" ) {
        Write-Output "devlab is not running. Refusing to stop a stopped devlab."
        exit 1
    }
}  

# Build parameters
$REPONAME = "onspot/devlab"
$LANG = "$l"
$VERSION = "$v"

# Run parameters
$CNAME = "devlab"     # Name of the running devlab container
$JPYPORT = 9000       # Port in which devlab runs (within the container)
$HPORT=${JPYPORT}     # Port in which devlab should run on the host machine

# Adjust the image name based on the language name
if ( $LANG -eq "base" ) {
    $IMGNAME=${REPONAME}  # For base devlab, we'll keep the image name simple
} else {
    $IMGNAME="${REPONAME}-${LANG}" 
}

# If we have a "trustedcerts" directory where we are running the devlab, just mount it
# to /opt/certs. This directory contains additional PEM certificates that may be needed to 
# access the internet when done behind a corporate proxy.
if ( Test-Path trustedcerts/* ) {
    # Docker desktop in windows platform is not recognising --mount type bind.
    # We therefore will use the (old fashioned) -v for mounting trustedcerts only on windows.
    $MOUNT_CERTS = "-v${PWD}/trustedcerts:/opt/certs"
} else {
    $MOUNT_CERTS = ""
}

# Run devlab based on the above configurations. 
# The command to be run comes from the case-statement below.
function RunDevlab($cmd, $mode) {
    $args = "run --rm -p ${HPORT}:${JPYPORT} ${mode} --mount src=devlab-${LANG}-${VERSION},dst=/home/dev ${MOUNT_CERTS} --name ${CNAME} --hostname localhost ${IMGNAME}:${VERSION} ${cmd}"
    & docker $args.split()
}

# This function extracts jupyter information from the logs and prints the same on the console
# to be used by the user. Note that this function also adjusts for the port number based on where
# the devlab is listening.
function PrintJpyInfo($logs) {
    if ( $logs ) {
        $info = $logs | Select-String -notmatch "^\[" | ForEach-Object { $_ -replace "^\ \ \ \ ","" -replace ":${JPYPORT}/",":${HPORT}/" }
        Write-Output ($info -join "`r`n" | out-string)
    } else {
        Write-Output 'Jupyter took unusually longer time to start.'
        Write-Output 'Use "docker logs devlab" to get the URLs to access Jupyter.'

        if ( $JPYPORT -ne $HPORT ) {
            Write-Output "NOTE: *** In the URL, use $HPORT as the port number instead of $JPYPORT ***"
        }
    }
}

switch ($progarg) {
    "notmux" {
        RunDevlab "/bin/zsh" "-it" 
    }
    "lab" {
        Write-Output "Starting devlab..."    
        RunDevlab "jupyter lab --no-browser" "-d"                    
    	Start-Sleep -Seconds 2
        PrintJpyInfo $(docker logs ${CNAME} 2>&1)
    }
    {($_ -eq "nb") -or ($_ -eq "notebook")} {
        Write-Output "Starting notebook..."    
        RunDevlab "jupyter notebook --no-browser" "-d"            
    	Start-Sleep -Seconds 2
        PrintJpyInfo $(docker logs ${CNAME} 2>&1)        
    }        
    "tmux" {
        RunDevlab "starttmux" "-it"
    }
    Default {
        Usage
    }
}
