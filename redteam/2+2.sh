#!/bin/bash

# Generate a random math problem
generate_problem() {
    num1=$((RANDOM % 100000 + 1))
    num2=$((RANDOM % 100000 + 1))
    operators=("+" "-" "*")
    operator=${operators[$((RANDOM % 3))]}

    echo "$num1 $operator $num2"
}

function exit() {
    echo "Gee golly, you did so much with that command."
}

function bash() {
    echo "You're not getting out of here with that shell, try another.."
}

function sh() {
    echo "not quite, why don't you try another shell.."
}

# Validate user's answer with a timer
validate_answer() {
    problem=$1
    read -t 30 -p "$problem = " user_answer

    if [ -z "$user_answer" ]; then
        echo "OOP, you took too long.. go faster next time!"
    elif [ "$user_answer" = "$(expr "$problem" | bc)" ]; then
        echo "calculating."
        sleep 3
        echo "calculating.."
        sleep 3
        echo "calculating..."
        sleep 3
        echo "calculating...."
        sleep 3
        echo "Good Job, you got the answer correct, isn't life better when you know math."
        eval "$command"
    else
        echo "calculating."
        sleep 3
        echo "calculating.."
        sleep 3
        echo "calculating..."
        sleep 3
        echo "calculating...."
        sleep 3
        echo "You got the incorrect answer.. L"
    fi
}

trap '' SIGINT

# Prompt the user to solve a math problem upon user input
while true; do
    read -p "$ " command
    problem=$(generate_problem)
    echo "QUICKLY, YOU'RE ON A 30 SECOND TIMER!!!!!"
    validate_answer "$problem"
done
