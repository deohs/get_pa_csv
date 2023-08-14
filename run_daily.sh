#!/usr/bin/bash

export LOGFILE='get_data_log.txt'
cd /path/to/project
/usr/bin/date +"%Y-%m-%d %H:%M:%S %Z" >> "$LOGFILE"
/usr/bin/Rscript --vanilla 'get_data.R' 2>&1 >> "$LOGFILE"
