# Azure API for FHIR Starter

Deploy an Azure API for FHIR Instance and Register a Service Client for Access
+ Provides an integrated deployment script for both FHIR Server and Registering a Service Client for Applicaition Access 
+ Securely Stores Client Access Secrets in Keyvault
+ Generates a Postman Environment for easy setup and use with included sample FHIR Calls collection  

# Prerequsites
1. The following resources providers must be registered in your subscription and you must have the ability to create/update them:
   + ResourceGroup, KeyVault, Azure API 4 FHIR
2. You must have the rights assigned to create application registrations/service principals and assign FHIR Roles in the destination active directory tenant.
3. You must deploy to a region that supports Azure API for FHIR.  You can use the [product by region page](https://azure.microsoft.com/en-us/global-infrastructure/services/?products=azure-api-for-fhir) to verify your destination region. 

# Instructions
1. [Open Azure Cloud Shell](https://shell.azure.com) you can also access this from [Azure Portal](https://portal.azure.com)
2. Select Bash Shell for the environment 
3. Clone this repo ```git clone https://github.com/sordahl-ga/api4fhirstarter```
4. Make the bash script executable ```chmod +x ./createapi4fhir.bash```
1. Execute ```createapi4fhir.bash -p```
    1. Note -p creates a Postman Envirnment file which you can download
1. Follow prompts for the following
    1. Validate Tenant ID 
    1. Create Resource Group 
    1. Choose Resource Group location 
    1. Enter new Key Vault Name 
    1. Enter name for API for FHIR Service 

# Using Postman to Connect to FHIR Server
1. [Download and Install Postman API App](https://www.postman.com/downloads/)
2. Select an existing or Create a New Postman Workspace
3. Select the import button next to your workspace name ![Import Postman](postman1.png)
4. Import the ```servername.postman_environment.json``` file that was created:
    + Upload the file using the upload file button or
    + Paste in the contents of the file useing the Raw Text tab
    ![Import Postman](postman2.png)
5. Repeat steps 3 and 4 with the ```FHIR-CALLS-Sample.postman-collection.json``` file
6. Select the ```servername``` postman environment in the workspace. (For Example my workspance name is stocore)
   ![Import Postman](postman3.png)
7. Select the ```AuthorizationGetToken``` call from the ```FHIR Calls-Sample``` collection
   ![Import Postman](postman4.png)
8. Press send you should receive a valid token it will be automatically set in the bearerToken variable for the environment
   ![Import Postman](postman5.png)
9. Select the ```List Patients``` call from the ```FHIR Calls-Samples``` collection
   ![Import Postman](postman6.png)
10. Press send you should receive and empty bundle of patients from the FHIR Server
   ![Import Postman](postman7.png)
11. You may now use the token received for the other sample calls or your own calls.  Note: After token expiry, use the ```AuthorizationGetToken``` call to get another token
# Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.opensource.microsoft.com.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

FHIR� is the registered trademark of HL7 and is used with the permission of HL7.</br>
Postman API App �Postman Inc.