# Azure MySQL Flexible Server Deployment Parameters

This directory contains the parameters file required for deploying the MySQL Flexible Server using the ARM template.

## Files
- `deploymentParameters.json`: The file defining specific values for parameters in the deployment template.

## Purpose
This file allows you to customize your MySQL Flexible Server deployment with user-specific configurations, such as server name, location, and credentials.

## How to Use
1. Open `deploymentParameters.json` and fill in the required fields:
   - `administratorLogin`: The admin username for the MySQL server.
   - `administratorLoginPassword`: The secure password for the admin user (leave null for security purposes and provide during deployment).
   - `serverName`: A unique name for your MySQL Flexible Server.
2. Review optional fields and adjust as needed:
   - `vCores`: Number of virtual cores for the server.
   - `storageSizeGB`: Storage size in GB.
   - `haEnabled`: Enable or disable high availability.
   - `firewallRules`: Configure IP addresses allowed to access the server.

3. Deploy the parameters file alongside the template:
   ```bash
   az deployment group create \
     --resource-group <your-resource-group> \
     --template-file ../template/deploymentTemplate.json \
     --parameters @deploymentParameters.json
