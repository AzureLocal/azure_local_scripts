az login --use-device-code
az account set –subscription [Subscription id]
az account show
az ad app create --display-name “Azure Local Deployment”
az ad sp create-for-rbac --name “Azure Local Deployment”