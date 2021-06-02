#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# -e: immediately exit if any command has a non-zero exit status
# -o: prevents errors in a pipeline from being masked
# IFS new value is less likely to cause confusing bugs when looping arrays or arguments (e.g. $@)
#
# Deploy Azure API for FHIR and setup Service Client Access --- Author Steve Ordahl Principal Architect Health Data Platform
#

usage() { echo "Usage: $0  -i <subscriptionId> -g <resourceGroupName> -l <resourceGroupLocation> -k <keyvault> -n <fhir server name> -p (to generate postman environment)" 1>&2; exit 1; }

function fail {
  echo $1 >&2
  exit 1
}

function retry {
  local n=1
  local max=5
  local delay=15
  while true; do
    "$@" && break || {
      if [[ $n -lt $max ]]; then
        ((n++))
        echo "Command failed. Retry Attempt $n/$max in $delay seconds:" >&2
        sleep $delay;
      else
        fail "The command has failed after $n attempts."
      fi
    }
  done
}
declare stepresult=""
declare kvname=""
declare kvexists=""
declare defsubscriptionId=""
declare fsresourceid=""
declare fsname=""
declare fsexists=""
declare fsclientid=""
declare fstenantid=""
declare fssecret=""
declare fsaudience=""
declare fsoid=""
declare spname=""
declare repurls=""
declare resourceGroupName=""
declare resourceGroupLocation=""
declare subscriptionId=""
declare genpostman=""
declare pmenv=""
declare pmuuid=""
declare pmfhirurl=""
# Initialize parameters specified from command line
while getopts ":k:n:p" arg; do
	case "${arg}" in
		k)
			kvname=${OPTARG}
			;;
		n)
			fsname=${OPTARG}
			;;
		p)
			genpostman="yes"
			;;
		i)
			subscriptionId=${OPTARG}
			;;
		g)
			resourceGroupName=${OPTARG}
			;;
		l)
			resourceGroupLocation=${OPTARG}
			;;
	esac
done
shift $((OPTIND-1))
echo "Deploy Azure API for FHIR..."
echo "Checking Azure Authentication..."
#login to azure using your credentials
az account show 1> /dev/null

if [ $? != 0 ];
then
	az login
fi
defsubscriptionId=$(az account show --query "id" --out json | sed 's/"//g') 

#Prompt for parameters is some required parameters are missing
if [[ -z "$subscriptionId" ]]; then
	echo "Enter your subscription ID ["$defsubscriptionId"]:"
	read subscriptionId
	if [ -z "$subscriptionId" ] ; then
		subscriptionId=$defsubscriptionId
	fi
	[[ "${subscriptionId:?}" ]]
fi

if [[ -z "$resourceGroupName" ]]; then
	echo "This script will look for an existing resource group, otherwise a new one will be created "
	echo "You can create new resource groups with the CLI using: az group create "
	echo "Enter a resource group name"
	read resourceGroupName
	[[ "${resourceGroupName:?}" ]]
fi

if [[ -z "$resourceGroupLocation" ]]; then
	echo "If creating a *new* resource group, you need to set a location "
	echo "You can lookup locations with the CLI using: az account list-locations "
	
	echo "Enter resource group location:"
	read resourceGroupLocation
fi


defsubscriptionId=$(az account show --query "id" --out json | sed 's/"//g') 

#Prompt for parameters is some required parameters are missing
if [[ -z "$kvname" ]]; then
	echo "Enter keyvault name to store FHIR Server configuration: "
	read kvname
fi
if [ -z "$kvname" ]; then
	echo "Keyvault name must be specified"
	usage
fi
if [[ -z "$fsname" ]]; then
	echo "Enter a name for this API for FHIR Server:"
	read fsname
fi
if [ -z "$fsname" ]; then
	echo "API For FHIR Server name must be specified"
	usage
fi
#Check for existing RG
if [ $(az group exists --name $resourceGroupName) = false ]; then
	echo "Resource group with name" $resourceGroupName "could not be found. Creating new resource group.."
	set -e
	(
		set -x
		az group create --name $resourceGroupName --location $resourceGroupLocation 1> /dev/null
	)
	else
	echo "Using existing resource group..."
fi
#Check KV exists
echo "Checking for keyvault "$kvname"..."
kvexists=$(az keyvault list --query "[?name == '$kvname'].name" --out tsv)
if [[ -z "$kvexists" ]]; then
	echo "Creating Key Vault "$kvname"..."
	stepresult=$(az keyvault create --name $kvname --resource-group $resourceGroupName --location  $resourceGroupLocation)
	if [ $? != 0 ]; then
		echo "Could not create new keyvault "$kvname
		exit 1
	fi
fi
#Check FS exists
echo "Checking for exiting FHIR Server "$fsname"..."
stepresult=$(az config set extension.use_dynamic_install=yes_without_prompt)
fsexists=$(az healthcareapis service list --query "[?name == '$fsname'].name" --out tsv)
if [[ -n "$fsexists" ]]; then
	echo "An API for FHIR Server Named "$fsname" already exists in this subscription...Retry deployment with another name"
	exit 1
fi
#Start deployment
echo "Deploy Azure API for FHIR and Service Client..."
(
		echo "Creating Azure API for FHIR Instance ["$fsname"]..."
		stepresult=$(az healthcareapis service create --resource-group $resourceGroupName --resource-name $fsname --kind "fhir-R4" --location $resourceGroupLocation --cosmos-db-configuration offer-throughput=1000)
		fsaudience=$(echo $stepresult | jq -r '.properties.authenticationConfiguration.audience')
		fsresourceid=$(echo $stepresult | jq -r '.id')
		spname=$fsname"-svc-client"
		echo "Creating FHIR Server Client Service Principal["$spname"]..."
		stepresult=$(az ad sp create-for-rbac -n $spname --skip-assignment)
		fsclientid=$(echo $stepresult | jq -r '.appId')
		fstenantid=$(echo $stepresult | jq -r '.tenant')
		fssecret=$(echo $stepresult | jq -r '.password')
		#Get OID for role assignment
		fsoid=$(az ad sp show --id $fsclientid --query "objectId" --out tsv)
		echo "Updating Keyvault with new FHIR Service Client Settings..."
		stepresult=$(az keyvault secret set --vault-name $kvname --name "FS-TENANT-NAME" --value $fstenantid)
		stepresult=$(az keyvault secret set --vault-name $kvname --name "FS-CLIENT-ID" --value $fsclientid)
		stepresult=$(az keyvault secret set --vault-name $kvname --name "FS-SECRET" --value $fssecret)
		stepresult=$(az keyvault secret set --vault-name $kvname --name "FS-RESOURCE" --value $fsaudience)
		stepresult=$(az keyvault secret set --vault-name $kvname --name "FS-URL" --value $fsaudience)
		echo "Placing Service Client in FHIR Data Contributor Role..."
		stepresult=$(az role assignment create --role "FHIR Data Contributor" --assignee-object-id $fsoid --scope $fsresourceid) 
		if [ -n "$genpostman" ]; then
			echo "Generating Postman environment for FHIR Server access..."
			pmuuid=$(cat /proc/sys/kernel/random/uuid)
			pmenv=$(<postmantemplate.json)
			pmfhirurl=$fsaudience
			pmenv=${pmenv/~guid~/$pmuuid}
			pmenv=${pmenv/~envname~/$fsname}
			pmenv=${pmenv/~tenentid~/$fstenantid}
			pmenv=${pmenv/~clientid~/$fsclientid}
			pmenv=${pmenv/~clientsecret~/$fssecret}
			pmenv=${pmenv/~fhirurl~/$pmfhirurl}
			pmenv=${pmenv/~resource~/$fsaudience}
			echo $pmenv >> $fsname".postman_environment.json"
		fi
		echo " "
		echo "************************************************************************************************************"
		echo "Created Azure API for FHIR Server "$fsname" and service client "$spname" on "$(date)
		echo "This client can be used for OAuth2 client_credentials flow authentication to the FHIR Server"
		echo "Your client credentials have been securely stored as secrets in keyvault "$kvname
		echo "The secret prefix is FS-"
		echo " "
		if [ -n "$genpostman" ]; then
			echo "For your convenience a Postman environment "$fsname".postman_environment.json has been generated"
			echo "It can be imported along with the FHIR-CALLS-Sample.postman-collection.json into postman to test access to your FHIR Server"
			echo "For Postman Importing help please reference the following URL:"
			echo "https://learning.postman.com/docs/getting-started/importing-and-exporting-data/#importing-postman-data"
		fi
		echo "************************************************************************************************************"
		echo " "
		echo "Note: The display output and files created by this script can contain sensitive resource access information please protect it!"
		echo " "
)
