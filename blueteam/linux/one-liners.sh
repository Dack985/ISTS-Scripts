#detect all files changed within the last 5 mins, can change to whatever you want, 5 was just a baseline
sudo find / -type f -mmin -5

#show every users crontab
sudo awk -F: '{print $1}' /etc/passwd | while read user; do echo "### $user's Crontab ###"; crontab -l -u "$user" 2>/dev/null || echo "No crontab found"; echo ""; done


#show every users ssh private key file
sudo awk -F: '{print $1, $6}' /etc/passwd | while read user home; do [ -f "$home/.ssh/authorized_keys" ] && echo "### $user's SSH Keys ###" && cat "$home/.ssh/authorized_keys"; done


#update pam
sudo pam-auth-update --force


#check all failed ssh attempts
journalctl _SYSTEMD_UNIT=ssh.service | egrep "Failed|Failure"


#show every system startup service
sudo systemctl --all list-unit-files --type=service
#basic rootkit search


#show masked services
systemctl list-units --all --type=service | grep '.service' | while read service; do if [ -L /etc/systemd/system/$service ] && [ "$(readlink /etc/systemd/system/$service)" == "/dev/null" ]; then echo "Masked: $service"; fi; done


#force reinstall update manager if tampering is suspected
sudo apt-get install --reinstall update-manager



#show applications running on non standard ports 
sudo netstat -tuln | grep -v ':22\|:80\|:443'


#kick out any unknowkn users
who -u
sudo pkill -KILL -u <user> 
#also kill user based on session
sudo pkill -Kill -u <user> --tty=<pts/>


#shows all services listening for conenctions
sudo netstat -tuln | grep LISTEN


#show modified system binaries within the last 5 mins 
sudo find /bin /sbin /usr/bin /usr/sbin -type f -mmin -5
