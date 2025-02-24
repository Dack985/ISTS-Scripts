echo"showing all users with shell access"
awk -F: '{print $1, $7}' /etc/passwd | grep -v nologin

echo "listing all users with elevated priveldegs"

echo "showing the contents of /etc/sudoers to see if any users have sudo privs"
