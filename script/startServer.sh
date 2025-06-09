#!/bin/bash
bash $USER_HOME/steamcmd/steamcmd.sh +force_install_dir "$USER_HOME/dstserver" +login anonymous +app_update 343050 validate +quit
tail -f /dev/null