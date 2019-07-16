#!/bin/bash
clear

echo " "
echo " ██╗    ██╗██╗███████╗██╗    ██╗     ██╗   ██╗██████╗ ██╗  ██╗███████╗██████╗ "
echo " ██║    ██║██║██╔════╝██║    ██║     ██║   ██║██╔══██╗██║ ██╔╝██╔════╝██╔══██╗"
echo " ██║ █╗ ██║██║█████╗  ██║    ██║     ██║   ██║██████╔╝█████╔╝ █████╗  ██████╔╝"
echo " ██║███╗██║██║██╔══╝  ██║    ██║     ██║   ██║██╔══██╗██╔═██╗ ██╔══╝  ██╔══██╗"
echo " ╚███╔███╔╝██║██║     ██║    ███████╗╚██████╔╝██║  ██║██║  ██╗███████╗██║  ██║"
echo "  ╚══╝╚══╝ ╚═╝╚═╝     ╚═╝    ╚══════╝ ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝"
echo " "

# Set filename, make sure file doesn't already exist
filecheck="0"

while [ $filecheck -lt 1 ]
do
	read -p " Project name (no extension): " filename
	if [ -f "wl-mac_$filename.txt" ]; then
		echo " $filename exists. Please choose another"
	else
		filecheck="1"
		echo -e " [+] Project name set as $filename\n"
	fi
done

# Time to run scan
read -p " Scan time (seconds): " scantime
echo -e " [+] Starting $scantime second scan"
sleep 2

# Run Airodump and output file
xterm -T "WiFi Lurker: Scanning Networks" -e timeout $scantime airodump-ng --ignore-negative-one --band abg -w $filename --output-format csv wlan0 & sleep $scantime;
kill $!

# Pull BSSIDs, Channels and ESSID from Airodump output
cut -d ',' -f 1,4,14 ${filename}-01.csv >> wl_${filename}.txt

# Remove empty lines with spaces from new file
sed -i '/^[[:space:]]*$/d' wl_${filename}.txt

# Remove BSSID Line
sed -i '/BSSID/d' wl_${filename}.txt

# Remove Stations 
sed -i -n '/Station MAC/q;p' wl_${filename}.txt

# Sort by Channel
sort -n -k 2 -o wl_${filename}.txt wl_${filename}.txt

echo -e "\n Scan Complete"
sleep 1

# Count WiFI access points
bssidcount=$(wc -l wl_${filename}.txt | awk -F ' ' '{print $1}')

if [ $bssidcount -gt 0 ]; then
	echo -e " [+] ${bssidcount} networks found"
	sleep 1
	echo -e " [+] Correlating MAC addresses and outputting data"
	sleep 1

	input="wl_${filename}.txt"

	echo -e " [+] Output will be saved to wl-${filename}-ap.txt \n"
	sleep 3

	while IFS= read -r line
	do
		echo " $line" | tee -a wl-${filename}-ap.txt

		MAC="$(echo $line | sed 's/ //g' | sed 's/-//g' | sed 's/://g' | cut -c1-6)";
		result="$(grep -i -A 4 ^$MAC ./oui.txt)";

		if [ "$result" ]; then
    			echo -e " $result" | tee -a wl-${filename}-ap.txt
		else
    			echo -e " $MAC is not in the database.\n" | tee -a wl-${filename}-ap.txt
		fi
	done < "$input"
	echo -e "\n [+] Output successfully saved to wl-${filename}-ap.txt \n"

# Allow user to choose individual network scan time
	read -p " [+] Enter invidual network scantime (seconds): " scantime2
	echo -e " [+] Starting individual scan\n" 
	sleep 1

	file=wl_${filename}.txt

	while read line ; do
		bssid=$( echo "$line" | cut -d ',' -f1 )
		channel=$( echo "$line" | cut -d ',' -f2 )
		channel_strip="$(echo -e "${channel}" | tr -d '[:space:]')"
		essid=$( echo "$line" | cut -d ',' -f3 )

		echo -e "BSSID: $bssid | Channel: $channel_strip | ESSID: $essid"

xterm -T "$bssid | $essid" -e timeout $scantime2 airodump-ng --bssid $bssid -c $channel_strip -w $filename --output-format csv wlan0 & sleep $scantime2; 
kill $!
		grep -A 10 'Station MAC' $filename-01.csv | grep -v 'Station MAC' >> wl-clients-${filename}.txt
		sed -i '/^[[:space:]]*$/d' wl-clients-${filename}.txt
		test -f "$filename-01.csv" && rm $filename-01.csv
	done < ${file}

	sleep 1
	echo -e "\n [+] Outputting client data\n"
	sleep 1


# Correlate client MAC addresses
	input="wl-clients-${filename}.txt"

	while IFS= read -r line ; do
		echo " $line" | tee -a wl-$filename-clients.txt

		MAC="$(echo $line | sed 's/ //g' | sed 's/-//g' | sed 's/://g' | cut -c1-6)";
		result="$(grep -i -A 4 ^$MAC ./oui.txt)";

		if [ "$result" ]; then
    			echo -e " $result" | tee -a wl-$filename-clients.txt
		else
    			echo -e " $MAC is not in the database.\n" | tee -a wl-$filename-clients.txt
		fi
	done < "$input"

	echo -e " [+] Data saved to wl-$filename-clients.txt"

else
	echo -e " [+] ${bssidcount} network BSSIDs captured"
	echo -e " [+] Increase scan time or try again\n"
fi

# Cleanup, remove uncessary files
# rm wl_${filename}.txt
#rm ${filename}-01.csv
exit 1
