# get_pa_csv

Example of using R to get PurpleAir data as CSV files for multiple stations.

## Overview

This example shows how data can be retrieved from PurpleAir using R and a scheduled task.

- *get_data.R* is the R script which gets the data
- *read_data.R* is the R script which reads all of the data files and makes a simple plot.
- *run_daily.sh* is a Bash script to run get_data_v2.R and is executed by the cron utility
- *crontab.txt* is the crontab entry to run the Bash script
 
## Usage

The steps below assume you are using this on a Linux, Unix, or macOS system that has the "cron" utility installed and the Bash shell.
 
1. Put all of these files in a single folder, preferably an RStudio Project folder.
2. Edit the folder path in *run_daily.sh* and *crontab.txt* to match the folder path that stores these files.
3. Edit the first line of *run_daily.sh* to correct the path to the Bash interpreter, if necessary.
4. Edit *crontab.txt* for the schedule you want (or leave as-is for midnight every day).
5. Run the following Bash commands at the Bash (Terminal) prompt:
```
chmod +x run_daily.sh
crontab -l > old_crontab.txt
cat old_crontab.txt crontab.txt > new_crontab.txt
crontab new_crontab.txt
```
6. Confirm your crontab entry has been stored with:
```
crontab -l
```
