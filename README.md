# kvmbackup-bash
Generates a backup of all active libvirtd domains on the host where it is executed
It was created as a lightweight backup solution for a pure libvirtd virtual machine host. 
You are free to use or modify this script as you wish. If you encounter any bugs or issues, 
or have suggestions for improvements, please let me know. If the debug flag is set to 1, 
the script will produce more detailed output for debugging purposes.
# how to use it
a) Set up your backup destination and update line 37 with the appropriate path.
b) Add a script to cron with a 24-hour interval, you can edit the crontab file by running the command crontab -e. Then, add a new line to the file in the following format: 0 0 * * * /path/to/script. This will run the script every day at midnight. Make sure to replace /path/to/script with the actual path to your script.
