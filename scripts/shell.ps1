#!/bin/bash

#
# Shells into a running devlab
#
# Author: arvindd
# Created: 21.Apr.2021
#
# Copyright (c) 2021 Arvind Devarajan
# Licensed to you under the MIT License.
# See the LICENSE file in the project root for more information.
#

# First, check if we are already running the devlab
$cnt = docker ps --filter "name=devlab" | tail -1 | grep -q devlab
if ( $cnt.Lines -eq 2 ) {
    # Ok, then shell into it
    docker exec -it devlab /bin/zsh
} else {
    # devlab is not running.
    Write-Output "devlab is not running. Start devlab before shelling into it."
}