#!/bin/bash
#Script to generate a config and credentials file from AWS account's and different profile that you have in there
#Author Jhonnatan Gil jgilc1@ucentral.edu.co
#Pres:
#   - jq
#   - awscli >= 2
#   - AWS SSO profile in ~/.aws/config and config this profile in AWS_PROFILE_SSO var
#   - Replace SSO_START_URL for your URL's company

TMP_ACCOUNTS_FILE=tmp_accounts.json
TMP_IDS_ACCOUNTS=tmp_idsaccounts
TMP_NAMES_ACCOUNTS=tmp_namesaccounts
TMP_CONFIG_FILE=tmp_awsconfig
TMP_CRED_FILE=tmp_awscredentials


#Using one account to read all asigned accounts
AWS_PROFILE_SSO=enterprise-ops
AWS_SSO_START_URL=https://yourcompany-aws.awsapps.com/start
AWS_SSO_REGION=us-east-1
AWS_CRE_REGION=us-east-2
AWS_TOKEN_SSO=''

GENERATE_CREDENTIALS=true

#start with login over AWS
function obtainLoginAWS(){
    aws sso login
}

#Obtain token from SSO login
function obtainToken(){
    AWS_TOKEN_SSO=$(jq -r ".accessToken" $(find ~/.aws/sso/cache/ ! -name \*boto\* -type f)) 
}

function obtainAccounts(){
    #List accounts
    aws sso list-accounts --access-token $AWS_TOKEN_SSO --profile $AWS_PROFILE_SSO --region us-east-1 > $TMP_ACCOUNTS_FILE
    #Obtain all accounts IDs and Names
    jq -r '.accountList[] | .accountId, .accountName' $TMP_ACCOUNTS_FILE > $TMP_IDS_ACCOUNTS
}


#Iterate accounts for obtain roles
function obtainRoles(){
    if [ -e $TMP_CONFIG_FILE ];
    then
        rm $TMP_CONFIG_FILE
        rm $TMP_CRED_FILE
    fi
    initConfig
    currentAccountID=""
    currentAccountName=""
    isID=true

    while read accountID
        do
        if [ "$isID" = true ]; then
            currentAccountID=$accountID
            echo "Obtain info from $accountID"
            aws sso list-account-roles --access-token $AWS_TOKEN_SSO --profile $AWS_PROFILE_SSO --region us-east-1 --account-id $accountID|jq -r ".roleList[].roleName" > $accountID
            isID=false
        else
            currentAccountName=$(echo ${accountID// /_})
            echo "Loading info with $currentAccountID $currentAccountName"
            addRoleInConfig $currentAccountID $currentAccountName
            isID=true
        fi
        
        done < $TMP_IDS_ACCOUNTS
}

function initConfig(){
    echo "Init config file"
    echo "[default]" > $TMP_CONFIG_FILE
    echo "output = json" >> $TMP_CONFIG_FILE
    echo "region = us-east-2" >> $TMP_CONFIG_FILE
    echo "" >> $TMP_CONFIG_FILE
    echo "[profile base-profile]" >> $TMP_CONFIG_FILE
    echo "output = json" >> $TMP_CONFIG_FILE
    echo "region = us-east-2" >> $TMP_CONFIG_FILE
    echo "" >> $TMP_CONFIG_FILE

    if [ "$GENERATE_CREDENTIALS" = true ]; then
        initCredentials
    fi
}

function initCredentials(){
    echo "Init credentials file"
    echo "[default]" > $TMP_CRED_FILE
    echo "aws_access_key_id = ''" >> $TMP_CRED_FILE
    echo "aws_secret_access_key = ''" >> $TMP_CRED_FILE
    echo "" >> $TMP_CRED_FILE
}

function addRoleInConfig(){
    account=$1
    accountName=$2
    echo "Adding in config for $accountName-$account"
    
    while read profile
    do
        #cat <<EOF >> $TMP_CONFIG_FILE
        #    [profile $profile-$account]
        #    sso_start_url = $AWS_SSO_START_URL
        #    sso_region = $AWS_SSO_REGION
        #    sso_account_id = $account
        #    sso_role_name = $profile
        #    source_profile = base-profile
        #EOF

        echo "[profile $accountName-$profile-$account] " >> $TMP_CONFIG_FILE
        echo "sso_start_url = $AWS_SSO_START_URL " >> $TMP_CONFIG_FILE
        echo "sso_region = $AWS_SSO_REGION " >> $TMP_CONFIG_FILE
        echo "sso_account_id = $account " >> $TMP_CONFIG_FILE
        echo "sso_role_name = $profile " >> $TMP_CONFIG_FILE
        echo "source_profile = base-profile " >> $TMP_CONFIG_FILE
        echo "" >> $TMP_CONFIG_FILE

        if [ "$GENERATE_CREDENTIALS" = true ]; then
            addRoleInCred $accountName $profile $account
        fi

    done < $account

    rm $account
}

function addRoleInCred(){
    accountName=$1
    profile=$2
    account=$3

    echo "Adding in credentials for $accountName-$account"

    echo "[$accountName-$profile-$account] " >> $TMP_CRED_FILE
    echo "region = $AWS_CRE_REGION " >> $TMP_CRED_FILE
    echo "account_id = $account " >> $TMP_CRED_FILE
    echo "role_name = $profile " >> $TMP_CRED_FILE
    echo "aws_access_key_id = ''" >> $TMP_CRED_FILE
    echo "aws_secret_access_key = ''" >> $TMP_CRED_FILE
    echo "aws_session_token = ''" >> $TMP_CRED_FILE
    echo "" >> $TMP_CRED_FILE
}


#Clean tmp files
function cleanfiles(){
    rm $TMP_ACCOUNTS_FILE
    rm $TMP_IDS_ACCOUNTS
}

obtainLoginAWS
obtainToken
obtainAccounts
obtainRoles
cleanfiles