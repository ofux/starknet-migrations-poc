#!/bin/bash

### CONSTANTS
SCRIPT_DIR=`readlink -f $0 | xargs dirname`
ROOT=`readlink -f $SCRIPT_DIR/..`
CACHE_FILE=$ROOT/build/deployed_contracts.txt
STARKNET_ACCOUNTS_FILE=$HOME/.starknet_accounts/starknet_open_zeppelin_accounts.json
PROTOSTAR_TOML_FILE=$ROOT/protostar.toml
WALLET=$STARKNET_WALLET

### FUNCTIONS
. $SCRIPT_DIR/logging.sh # Logging utilities
. $SCRIPT_DIR/tools.sh   # script utilities

# print the script usage
usage() {
    print "$0 [-a ACCOUNT_ADDRESS] [-p PROFILE] [-x ADMIN_ADDRESS] [-w WALLET]"
}

# build the protostar project
build() {
    log_info "Building project to generate latest version of the ABI"
    execute protostar build
    if [ $? -ne 0 ]; then exit_error "Problem during build"; fi
}

# get the account address from the account alias in protostar accounts file
# $1 - account alias (optional). __default__ if not provided
get_account_address() {
    [ $# -eq 0 ] && account=__default__ || account=$1
    grep $account $STARKNET_ACCOUNTS_FILE -A3 -m1 | sed -n 's@^.*"address": "\(.*\)".*$@\1@p'
}

# get the network option from the profile in protostar config file
# $1 - profile
get_network_opt() {
    profile=$1
    grep profile.$profile $PROTOSTAR_TOML_FILE -A3 -m1 | sed -n 's@^.*network_opt="\(.*\)".*$@\1@p'
}

# check starknet binary presence
check_starknet() {
    which starknet &> /dev/null
    [ $? -ne 0 ] && exit_error "Unable to locate starknet binary. Did you activate your virtual env ?"
}

# make sure wallet variable is set
check_wallet() {
    [ -z $WALLET ] && exit_error "Please provide the wallet to use (option -w or environment variable STARKNET_WALLET)"
}

# wait for a transaction to be received
# $1 - transaction hash to check
wait_for_acceptance() {
    tx_hash=$1
    print -n $(magenta "Waiting for transaction to be accepted")
    while true 
    do
        tx_status=`starknet tx_status --hash $tx_hash $NETWORK_OPT | sed -n 's@^.*"tx_status": "\(.*\)".*$@\1@p'`
        case "$tx_status"
            in
                NOT_RECEIVED|RECEIVED|PENDING) print -n  $(magenta .);;
                REJECTED) return 1;;
                ACCEPTED_ON_L1|ACCEPTED_ON_L2) return 0; break;;
                *) exit_error "\nUnknown transaction status '$tx_status'";;
            esac
            sleep 2
    done
}

# send a transaction
# $* - command line to execute
# return The contract address
send_transaction() {
    transaction=$*

    while true
    do
        execute $transaction || exit_error "Error when sending transaction"
        
        contract_address=`sed -n 's@Contract address: \(.*\)@\1@p' logs.json`
        tx_hash=`sed -n 's@Transaction hash: \(.*\)@\1@p' logs.json`

        wait_for_acceptance $tx_hash

        case $? in
            0) log_success "\nTransaction accepted!"; break;;
            1) log_warning "\nTransaction rejected!"; ask "Do you want to retry";;
        esac
    done || exit_error

    echo $contract_address
}

# send a transaction that declares a contract class
# $* - command line to execute
# return The contract address
send_declare_contract_transaction() {
    transaction=$*

    while true
    do
        execute $transaction || exit_error "Error when sending transaction"
        
        contract_class_hash=`sed -n 's@Contract class hash: \(.*\)@\1@p' logs.json`
        tx_hash=`sed -n 's@Transaction hash: \(.*\)@\1@p' logs.json`

        wait_for_acceptance $tx_hash

        case $? in
            0) log_success "\nTransaction accepted!"; break;;
            1) log_warning "\nTransaction rejected!"; ask "Do you want to retry";;
        esac
    done || exit_error

    echo $contract_class_hash
}

deploy_proxy() {
    path_to_implementation=$1
    implementation_class_hash=$2
    admin_address=$3

    # deploy proxy
    PROXY_ADDRESS=`send_transaction "protostar $PROFILE_OPT deploy ./build/proxy.json --inputs $implementation_class_hash"` || exit_error

    # initialize contract and set admin
    RESULT=`send_transaction "starknet invoke $ACCOUNT_OPT $NETWORK_OPT --address $PROXY_ADDRESS --abi $path_to_implementation --function initializer --inputs $admin_address"` || exit_error

    echo $PROXY_ADDRESS
}

update_proxified_contract() {
    path_to_implementation=$1
    implementation_class_hash=$2
    proxy_address=$3

    # initialize contract and set admin
    RESULT=`send_transaction "starknet invoke $ACCOUNT_OPT $NETWORK_OPT --address $proxy_address --abi $path_to_implementation --function update_implementation --inputs $implementation_class_hash"` || exit_error
}

update_proxified_contract_with_migration() {
    path_to_implementation=$1
    implementation_class_hash=$2
    migration_class_hash=$3
    proxy_address=$4

    # initialize contract and set admin
    RESULT=`send_transaction "starknet invoke $ACCOUNT_OPT $NETWORK_OPT --address $proxy_address --abi $path_to_implementation --function update_implementation_with_migration --inputs $implementation_class_hash $migration_class_hash"` || exit_error
}

deploy_proxified_contract() {
    contract=$1
    proxy_address=$2

    log_info "Declaring contract class..."
    implementation_class_hash=`send_declare_contract_transaction "starknet declare $NETWORK_OPT --contract ./build/${contract}.json"` || exit_error

    if [ -z $proxy_address ]; then
        log_info "Deploying proxy contract..."
        proxy_address=`deploy_proxy ./build/${contract}_abi.json $implementation_class_hash $ADMIN_ADDRESS` || exit_error
    else

        migration_file_path="./build/${contract}_migration.json"

        if [ -f $migration_file_path ]; then
            log_info "Declaring migration class..."
            migration_class_hash=`send_declare_contract_transaction "starknet declare $NETWORK_OPT --contract $migration_file_path"` || exit_error

            log_info "Updating proxy contract implementation and running migration..."
            `update_proxified_contract_with_migration ./build/${contract}_abi.json $implementation_class_hash $migration_class_hash $proxy_address` || exit_error
        else

            log_info "Updating proxy contract implementation..."
            `update_proxified_contract ./build/${contract}_abi.json $implementation_class_hash $proxy_address` || exit_error
        fi
    fi

    echo $proxy_address
}

# Deploy all contracts and log the deployed addresses in the cache file
deploy_all_contracts() {
    [ -f $CACHE_FILE ] && {
        . $CACHE_FILE
        log_info "Found those deployed accounts:"
        cat $CACHE_FILE
        ask "Do you want to deploy missing contracts and initialize them" || return 
    }

    print Profile: $PROFILE
    print Account alias: $ACCOUNT
    print Admin address: $ADMIN_ADDRESS
    print Network option: $NETWORK_OPT

    ask "Are you OK to deploy with those parameters" || return 

    [ ! -z $PROFILE ] && PROFILE_OPT="--profile $PROFILE"
    [ ! -z $ACCOUNT ] && ACCOUNT_OPT="--account $ACCOUNT"

    MY_CONTRACT_ADDRESS=`deploy_proxified_contract "my_contract" "$MY_CONTRACT_ADDRESS"` || exit_error

    (
        echo "MY_CONTRACT_ADDRESS=$MY_CONTRACT_ADDRESS"
    ) | tee >&2 $CACHE_FILE
}

### ARGUMENT PARSING
while getopts a:p:h option
do
    case "${option}"
    in
        a) ACCOUNT=${OPTARG};;
        x) ADMIN_ADDRESS=${OPTARG};;
        p) PROFILE=${OPTARG};;
        w) WALLET=${OPTARG};;
        h) usage; exit_success;;
        \?) usage; exit_error;;
    esac
done

[ -z $ADMIN_ADDRESS ] && ADMIN_ADDRESS=`get_account_address $ACCOUNT`
[ -z $ADMIN_ADDRESS ] && exit_error "Unable to determine account address"

NETWORK_OPT=`get_network_opt $PROFILE`
[ -z $NETWORK_OPT ] && exit_error "Unable to determine network option"

### PRE_CONDITIONS
check_starknet
check_wallet

### BUSINESS LOGIC

build # Need to generate ABI and compiled contracts
deploy_all_contracts

exit_success
