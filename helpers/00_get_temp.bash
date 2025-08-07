#!/usr/bin/env bash
# get tempurature_log.xlsx from gyrus2
# gyrus2 defined in ~/.ssh/config
export SSHPASS=$(pass gyrus2)
[ -z "$SSHPASS" ] && echo "cannot find gyrus2 password!" && exit 1
sshpass -e scp gyrus2:"/raidgyrus2/TWIX/temp\ log.xlsx" tempurature_log.xlsx
chmod a-x tempurature_log.xlsx
