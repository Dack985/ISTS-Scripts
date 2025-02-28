echo"showing all users with shell access"
awk -F: '{print $1, $7}' /etc/passwd | grep -v nologin


echo "list all users with root uid"

grep 'x:0:' /etc/passwd
# or you can use cat /etc/passwd | cut -f1,3,4 -d":" | grep"0:0" | cut -f1 -d":" | awk '{print $1}'
echo "listing all users within the root group"

grep -E '^(root|wheel|adm|admin):' /etc/group

echo "showing the contents of /etc/sudoers to see if any users have sudo privs"
sudo grep -E '\sALL[=(]' /etc/sudoers


echo"list all programs that have a SUID bit that allows the program to be executed as root."
sudo find / -perm -04000

echo"Adding in the new Auditd rules file, look up how to use this or ask tyler :)."
sudo rm /etc/audit/auditd/rules.d
sudo mv auditd /etc/audit/auditd/rules.d
sudo systemctl restart auditd
sudo auditctl -R /etc/audit/auditd/rules.d

Echo "Listing to see if the new rules took effect"
sudo auditctl -l


echo "this ones gross ngl, but will show every vulnerable file that any user can write to"
find / -type f \( -perm -4000 -o -perm -2000 \) 2>/dev/null | xargs ls -l



echo "searching for any obvious gimmies"
dpkg -l | grep -iE 'malicious|backdoor|suspicious|virus|evil|ev1l|bad'
