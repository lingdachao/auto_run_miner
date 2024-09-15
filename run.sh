#!/bin/bash

get_index_string() {
    local num_gpus=$1
    local index_string=""
    for ((i=0; i<num_gpus; i++)); do
        if [ $i -eq 0 ]; then
            index_string="$i"
        else
            index_string="$index_string,$i"
        fi
    done
    echo "$index_string"
}

get_instance_name() {
    local id=$1
    local num_gpus=$2
    local last_four_digits=${id: -4}
    echo "${last_four_digits}x${num_gpus}"
}

# Function: Remove specified line from .bashrc
remove_line_from_bashrc() {
    local line_to_remove="/usr/bin/python3 /root/log.py &"
    if grep -Fxq "$line_to_remove" ~/.bashrc; then
        sed -i "\|$line_to_remove|d" ~/.bashrc
        echo "Line removed from ~/.bashrc: $line_to_remove"
    else
        echo "Line not found in ~/.bashrc"
    fi
}

# 检查是否传递了参数
if [ $# -gt 1 ]; then
  echo "Usage: $0 [update]"
  exit 1
fi

# 获取 update 参数，如果没有传递则默认为 0
update=${1:-0}

num_gpus=$(nvidia-smi --query-gpu=name --format=csv,noheader | wc -l)
instance_name=$(echo $VAST_CONTAINERLABEL)

index=$(get_index_string $num_gpus)
name=$(get_instance_name $instance_name $num_gpus)


# Print received parameters
echo "Received parameters:"
echo "index: $index"
echo "name: $name"
echo "update: $update"

if [ "$update" = "1" ]; then

    echo "Update mode: Deleting old files and reinstalling"
    echo "Deleting old files"
    # remove_line_from_bashrc
    # # Reload .bashrc
    # echo "Reloading .bashrc..."
    # source ~/.bashrc
    
    pkill -9 aleominer
    pkill -9 main
    rm -rf __MACOSX aleo_setup.sh aleominer* main* log.py
    sleep 5
fi

# Check if log.py exists
if [ ! -f log.py ]; then
  echo "log.py not found, creating log.py..."
  cat <<EOL > log.py
# -*- coding: utf-8 -*-
import os
import subprocess
import time

def execute_shell_commands(name,index):  
    subprocess.run(["pkill", "-9", "main"])
    time.sleep(5)
    print("start exec...")
    command = f"nohup ./main -u stratum+tcp://aleo-asia.f2pool.com:4400 -d {index} -w lingbu2017.{name} >> ./main.log 2>&1 &"
    subprocess.Popen(command, shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

def is_log_file_stale(name,index):
    current_time = time.time()
    file_path = "/root/main.log"
    try:
        file_mod_time = os.path.getmtime(file_path)
        time_diff = current_time - file_mod_time
        if time_diff > 2 * 60:
            print(f"{name} no update")
            execute_shell_commands(name,index)
        else:
            print(f"{name} update")
    except FileNotFoundError:
        print(f"{file_path} no exist")

def run_every_5_minutes(name, index):
    while True:
        is_log_file_stale(name,index)  # Use externally passed index and name
        time.sleep(60)

run_every_5_minutes("$name", "$index")
EOL
else
  echo "log.py already exists."
fi

# Check if main file exists
if [ ! -f "main" ]; then

    echo "main file does not exist, starting download and installation process..."

    # Download aleo miner file
    echo "Downloading aleominer.zip..."
    wget https://public-download-ase1.s3.ap-southeast-1.amazonaws.com/aleo-miner/aleominer+3.0.3.zip

    # Install unzip tool
    echo "Installing unzip..."
    sudo apt-get install -y unzip

    # Install vim tool
    echo "Installing vim..."
    sudo apt install vim -y

    # Unzip file
    echo "Unzipping aleominer+3.0.3.zip..."
    unzip aleominer+3.0.3.zip

    # Set execute permission
    echo "Setting execute permission for aleominer..."
    chmod +x aleominer

    # Rename aleominer to main
    echo "Renaming aleominer to main..."
    mv aleominer main

    # Create main.log
    touch main.log

    # Insert log.py
    # Define the line to be added
    new_line="/usr/bin/python3 /root/log.py &"
    # Check if .bashrc file already contains the line, avoid duplicate addition
    if ! grep -Fxq "$new_line" ~/.bashrc; then
    # If the line doesn't exist in .bashrc, insert it at the first line
    sed -i "1i $new_line" ~/.bashrc
    echo "Line added to ~/.bashrc"
    else
    echo "The line is already present in ~/.bashrc"
    fi

    # Reload .bashrc
    echo "Reloading .bashrc..."
    source ~/.bashrc

    echo "Installation complete."
else
    echo "main file already exists, skipping download and installation steps."
fi

# Run aleominer program and output log
echo "Running aleominer with nohup..."
nohup ./main -u stratum+tcp://aleo-asia.f2pool.com:4400 -d $index -w lingbu2017.$name >> ./main.log 2>&1 &

# Monitor log file
echo "Tailing main.log..."
tail -f main.log