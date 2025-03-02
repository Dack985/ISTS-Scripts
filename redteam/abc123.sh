#!/bin/bash

function generate_random_string {
    random_length=$((RANDOM%11+10))  # Generate a random length between 10 and 20
    random_string=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w $random_length | head -n 1)
}

function validate_input {
    read -s -p "Dual security check, please input this string the authenticate: ($random_string): " user_input
    echo $user_input | grep -q $random_string
}

function execute_command {
    generate_random_string
    command=$1

    if validate_input; then
        # Input is correct, execute the command
        echo -e "\nInput accepted. Executing command..."
        if [[ "$command" == "exit" || "$command" == "bash" || "$command" == "sh" ]]; then
            echo "Nice try!"
        else
            # Your command execution code here
            echo "Authentication passed, executing: $command"
            eval "$command"
        fi
    else
        # Input is incorrect, prevent command execution
        echo -e "\nIncorrect input. Command execution denied."
    fi
}

trap "echo 'Nice try!'" SIGINT SIGTSTP

while true; do
    read -p "$ " command_to_execute
    execute_command "$command_to_execute"
    echo
done
