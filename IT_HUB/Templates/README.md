# Azure MySQL Flexible Server Deployment Template

This directory contains the Azure Resource Manager (ARM) template for deploying a MySQL Flexible Server on Azure. The template defines the infrastructure, configuration, and deployment properties for the server.

## Files
- `deploymentTemplate.json`: The main ARM template file that specifies the structure and configuration of the MySQL server.

## Purpose
This template is designed for users who need to deploy a MySQL Flexible Server on Azure with pre-defined configurations. It supports both public and private network setups and includes high availability and backup options.

## How to Use
1. Open the `deploymentTemplate.json` file to review the template structure.
2. Ensure that all required parameters are correctly referenced in the accompanying parameters file.
3. Deploy the template:
   - Use the Azure Portal:
     - Navigate to "Deploy a Custom Template."
     - Upload the `deploymentTemplate.json` file.
   - Use Azure CLI:
     ```bash
     az deployment group create \
       --resource-group <your-resource-group> \
       --template-file deploymentTemplate.json \
       --parameters @../parameters/deploymentParameters.json
     ```

## Customization
You can modify the following in the `deploymentTemplate.json`:
- **Compute Resources**: Adjust `vCores`, `storageSizeGB`, and `vmName`.
- **Network Access**: Configure `firewallRules` and `publicNetworkAccess`.
- **Backup and Availability**: Set `geoRedundantBackup` and `haEnabled`.

## Learn More
- [Azure Documentation: MySQL Flexible Server](https://learn.microsoft.com/en-us/azure/mysql/flexible-server/overview)
