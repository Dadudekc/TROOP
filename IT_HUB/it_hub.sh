#!/bin/bash

# IT Hub for Azure Resource Management
# Supports multiple Azure resources with command-line arguments
# Adds an agent interface (interactive menu) using fzf when no arguments are provided.

# Exit immediately if a command exits with a non-zero status,
# if an undefined variable is used, and catch errors in pipelines.
set -euo pipefail

# ---------------------------
# Configuration and Setup
# ---------------------------

ENV_FILE="/mnt/d/TROOP/.env"
LOG_FILE="/mnt/d/TROOP/IT_HUB/logs/it_hub.log"

ROOT_DIR="/mnt/d/TROOP"
PATCH_DIR="$ROOT_DIR/patches"
GUI_DIR="$ROOT_DIR/IT_HUB/gui"

TEMPLATE_FILE="$ROOT_DIR/IT_HUB/Templates/mysql_flexible_server_template.json"
PARAMETERS_FILE="$ROOT_DIR/IT_HUB/Parameters/azure-troop-mysql-parameters.json"
TEMP_PARAMETERS_FILE="$ROOT_DIR/IT_HUB//Parameters/temp_parameters.json"

# ---------------------------
# Logging Functions
# ---------------------------

INFO="INFO"
ERROR="ERROR"

log() {
  local level="$1"
  local message="$2"
  echo "$(date +"%Y-%m-%d %H:%M:%S") [$level] $message" | tee -a "$LOG_FILE"
}

# ---------------------------
# Utility Functions
# ---------------------------

load_env() {
  if [[ -f "$ENV_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$ENV_FILE"
    log "$INFO" "Successfully loaded .env file."
  else
    log "$ERROR" "'.env' file not found at $ENV_FILE. Exiting."
    exit 1
  fi
}

check_jq() {
  if ! command -v jq &> /dev/null; then
    log "$INFO" "'jq' is not installed. Attempting to install..."
    case "$OSTYPE" in
      linux-gnu*)
        sudo apt-get update && sudo apt-get install -y jq
        ;;
      darwin*)
        if command -v brew &> /dev/null; then
          brew install jq
        else
          log "$ERROR" "'brew' not found. Please install Homebrew and retry."
          exit 1
        fi
        ;;
      cygwin*|msys*)
        log "$ERROR" "Automatic installation of 'jq' is not supported on Windows. Please install it manually."
        exit 1
        ;;
      *)
        log "$ERROR" "Unsupported OS for automatic 'jq' installation. Please install it manually."
        exit 1
        ;;
    esac

    if ! command -v jq &> /dev/null; then
      log "$ERROR" "Failed to install 'jq'. Exiting."
      exit 1
    fi
    log "$INFO" "'jq' installed successfully."
  else
    log "$INFO" "'jq' is already installed."
  fi
}

# Switch Resource Group
switch_resource_group() {
  local new_group="$1"
  if [[ -z "$new_group" ]]; then
    # If no group is provided, list available groups interactively
    new_group=$(az group list --query "[].name" -o tsv | fzf --height=15 --header="Select a resource group:")
    [[ -z "$new_group" ]] && { log "$ERROR" "No resource group selected."; return 1; }
  fi

  # Verify the selected resource group exists
  if az group exists --name "$new_group"; then
    RESOURCE_GROUP="$new_group"
    log "$INFO" "Switched to resource group: $RESOURCE_GROUP"

    # Update the .env file
    sed -i "s/^RESOURCE_GROUP=.*/RESOURCE_GROUP=$RESOURCE_GROUP/" "$ENV_FILE"
    log "$INFO" "Updated .env file with the new resource group: $RESOURCE_GROUP"
  else
    log "$ERROR" "Resource group '$new_group' does not exist."
    return 1
  fi
}

# Delete Resource Group
delete_resource_group_func() {
  local group_name="$1"
  if [[ -z "$group_name" ]]; then
    # If no group is provided, list available groups interactively
    group_name=$(az group list --query "[].name" -o tsv | fzf --height=15 --header="Select a resource group to delete:")
    [[ -z "$group_name" ]] && { log "$ERROR" "No resource group selected for deletion."; return 1; }
  fi

  # Confirm deletion
  read -r -p "Are you sure you want to delete the resource group '$group_name' and all its resources? [y/N]: " confirmation
  case "$confirmation" in
    [yY][eE][sS]|[yY])
      ;;
    *)
      log "$INFO" "Deletion of resource group '$group_name' canceled."
      return 0
      ;;
  esac

  # Delete the resource group
  log "$INFO" "Deleting resource group '$group_name'..."
  if ! az group delete --name "$group_name" --yes --no-wait | tee -a "$LOG_FILE"; then
    log "$ERROR" "Failed to delete resource group '$group_name'."
    exit 1
  fi
  log "$INFO" "Deletion of resource group '$group_name' initiated successfully."
}

# Check if MySQL server exists
server_exists() {
  local server_name="$1"
  az mysql flexible-server show --name "$server_name" --resource-group "$RESOURCE_GROUP" &> /dev/null
}

# Check if a VM exists
vm_exists() {
  local vm_name="$1"
  az vm show --name "$vm_name" --resource-group "$RESOURCE_GROUP" &> /dev/null
}

# Check if a Storage Account exists
storage_exists() {
  local storage_name="$1"
  # If "nameAvailable" is true, grep won't find "true", so it returns 1 => not existing
  ! az storage account check-name --name "$storage_name" --query "nameAvailable" -o tsv | grep -q "true"
}

# Generate a unique name by appending a random suffix
generate_unique_name() {
  local base_name="$1"
  local unique_suffix
  unique_suffix=$(date +%s | sha256sum | base64 | head -c6)
  echo "${base_name}-${unique_suffix}"
}

# Create parameters file for MySQL
create_mysql_temp_parameters() {
  jq \
    --arg serverName "$MYSQL_SERVER_NAME" \
    --arg location "$MYSQL_LOCATION" \
    --arg serverEdition "$MYSQL_SERVER_EDITION" \
    --argjson vCores "$MYSQL_VCORES" \
    --argjson storageSize "$MYSQL_STORAGE_SIZE" \
    --arg adminUsername "$MYSQL_ADMIN_USERNAME" \
    --arg adminPassword "$MYSQL_ADMIN_PASSWORD" \
    --arg databaseName "$MYSQL_DATABASE_NAME" \
    --arg clientIp "$CLIENT_IP" \
    '
    .parameters.serverName.value = $serverName |
    .parameters.location.value = $location |
    .parameters.serverEdition.value = $serverEdition |
    .parameters.vCores.value = $vCores |
    .parameters.storageSizeGB.value = $storageSize |
    .parameters.administratorLogin.value = $adminUsername |
    .parameters.administratorLoginPassword.value = $adminPassword |
    .parameters.databaseName.value = $databaseName |
    .parameters.firewallRules.value[0].startIpAddress = $clientIp |
    .parameters.firewallRules.value[0].endIpAddress = $clientIp
    ' "$PARAMETERS_FILE" > "$TEMP_PARAMETERS_FILE"

  log "$INFO" "Generated temp_parameters.json for MySQL successfully."
}

ensure_compatibility() {
  case "$OSTYPE" in
    linux-gnu*|darwin*|cygwin*|msys*)
      # Supported OS
      ;;
    *)
      log "$ERROR" "Unsupported OS: $OSTYPE. Exiting."
      exit 1
      ;;
  esac
}

# ---------------------------
# Resource Management
# ---------------------------

list_resources() {
  local resource_type="$1"
  case "$resource_type" in
    mysql)
      log "$INFO" "Listing all MySQL Flexible Servers in resource group '$RESOURCE_GROUP'..."
      az mysql flexible-server list --resource-group "$RESOURCE_GROUP" -o table | tee -a "$LOG_FILE"
      ;;
    vm)
      log "$INFO" "Listing all Virtual Machines in resource group '$RESOURCE_GROUP'..."
      az vm list --resource-group "$RESOURCE_GROUP" -o table | tee -a "$LOG_FILE"
      ;;
    storage)
      log "$INFO" "Listing all Storage Accounts in resource group '$RESOURCE_GROUP'..."
      az storage account list --resource-group "$RESOURCE_GROUP" -o table | tee -a "$LOG_FILE"
      ;;
    all)
      list_resources mysql
      list_resources vm
      list_resources storage
      ;;
    resource-group)
      log "$INFO" "Listing all Resource Groups in the subscription..."
      az group list -o table | tee -a "$LOG_FILE"
      ;;
    *)
      log "$ERROR" "Unsupported resource type for listing: $resource_type"
      ;;
  esac
}

deploy_mysql() {
  log "$INFO" "Deploying a new MySQL Flexible Server in resource group '$RESOURCE_GROUP'..."

  if server_exists "$MYSQL_SERVER_NAME"; then
    log "$INFO" "Server name '$MYSQL_SERVER_NAME' already exists. Generating a unique name."
    MYSQL_SERVER_NAME=$(generate_unique_name "$MYSQL_SERVER_NAME")
    log "$INFO" "Generated unique server name: $MYSQL_SERVER_NAME"
  fi

  create_mysql_temp_parameters

  log "$INFO" "Validating the deployment template for MySQL..."
  if ! VALIDATION_OUTPUT=$(az deployment group validate --resource-group "$RESOURCE_GROUP" --template-file "$TEMPLATE_FILE" --parameters "@$TEMP_PARAMETERS_FILE" 2>&1); then
    log "$ERROR" "Template validation failed for MySQL. Details:"
    log "$ERROR" "$VALIDATION_OUTPUT"
    log "$INFO" "Retaining temp_parameters.json for debugging."
    exit 1
  fi
  log "$INFO" "Template validation passed for MySQL."

  log "$INFO" "Deploying the MySQL Flexible Server..."
  if ! DEPLOYMENT_OUTPUT=$(az deployment group create --resource-group "$RESOURCE_GROUP" --template-file "$TEMPLATE_FILE" --parameters "@$TEMP_PARAMETERS_FILE" 2>&1); then
    if [[ "$DEPLOYMENT_OUTPUT" == *"ServerNameAlreadyExists"* ]]; then
      log "$ERROR" "Deployment failed: Server name already exists, even after adjustments."
    else
      log "$ERROR" "Deployment failed for MySQL. Details:"
      log "$ERROR" "$DEPLOYMENT_OUTPUT"
    fi
    log "$INFO" "Retaining temp_parameters.json for debugging."
    exit 1
  fi

  log "$INFO" "Deployment of MySQL Flexible Server successful!"
  rm -f "$TEMP_PARAMETERS_FILE"
}

deploy_vm() {
  log "$INFO" "Deploying a new Virtual Machine in resource group '$RESOURCE_GROUP'..."

  if vm_exists "$VM_NAME"; then
    log "$INFO" "VM name '$VM_NAME' already exists. Generating a unique name."
    VM_NAME=$(generate_unique_name "$VM_NAME")
    log "$INFO" "Generated unique VM name: $VM_NAME"
  fi

  if ! az vm create --resource-group "$RESOURCE_GROUP" --name "$VM_NAME" --size "$VM_SIZE" --image "$VM_IMAGE" --admin-username "$VM_ADMIN_USERNAME" --admin-password "$VM_ADMIN_PASSWORD" --no-wait | tee -a "$LOG_FILE"; then
    log "$ERROR" "Deployment failed for VM '$VM_NAME'."
    exit 1
  fi
  log "$INFO" "Deployment of VM '$VM_NAME' initiated successfully!"
}

deploy_storage() {
  log "$INFO" "Deploying a new Storage Account in resource group '$RESOURCE_GROUP'..."

  if storage_exists "$STORAGE_ACCOUNT_NAME"; then
    log "$INFO" "Storage Account name '$STORAGE_ACCOUNT_NAME' already exists. Generating a unique name."
    STORAGE_ACCOUNT_NAME=$(generate_unique_name "$STORAGE_ACCOUNT_NAME")
    log "$INFO" "Generated unique Storage Account name: $STORAGE_ACCOUNT_NAME"
  fi

  if ! az storage account create --name "$STORAGE_ACCOUNT_NAME" --resource-group "$RESOURCE_GROUP" --location "$STORAGE_LOCATION" --sku "$STORAGE_SKU" | tee -a "$LOG_FILE"; then
    log "$ERROR" "Deployment failed for Storage Account '$STORAGE_ACCOUNT_NAME'."
    exit 1
  fi
  log "$INFO" "Deployment of Storage Account '$STORAGE_ACCOUNT_NAME' successful!"
}

delete_mysql() {
  local server_name="$1"
  if [[ -z "$server_name" ]]; then
    log "$ERROR" "No MySQL server name provided for deletion."
    exit 1
  fi

  if ! server_exists "$server_name"; then
    log "$ERROR" "MySQL Server '$server_name' does not exist in resource group '$RESOURCE_GROUP'."
    exit 1
  fi

  log "$INFO" "Deleting MySQL Server '$server_name'..."
  if ! az mysql flexible-server delete --name "$server_name" --resource-group "$RESOURCE_GROUP" --yes | tee -a "$LOG_FILE"; then
    log "$ERROR" "Failed to delete MySQL Server '$server_name'."
    exit 1
  fi

  log "$INFO" "Waiting for MySQL Server '$server_name' to be fully deleted..."
  until ! server_exists "$server_name"; do
    log "$INFO" "Server deletion in progress. Retrying in 10 seconds..."
    sleep 10
  done
  log "$INFO" "MySQL Server '$server_name' deleted successfully."
}

delete_vm() {
  local vm_name="$1"
  if [[ -z "$vm_name" ]]; then
    log "$ERROR" "No VM name provided for deletion."
    exit 1
  fi

  if ! vm_exists "$vm_name"; then
    log "$ERROR" "Virtual Machine '$vm_name' does not exist in resource group '$RESOURCE_GROUP'."
    exit 1
  fi

  log "$INFO" "Deleting Virtual Machine '$vm_name'..."
  if ! az vm delete --name "$vm_name" --resource-group "$RESOURCE_GROUP" --yes --no-wait | tee -a "$LOG_FILE"; then
    log "$ERROR" "Failed to delete Virtual Machine '$vm_name'."
    exit 1
  fi
  log "$INFO" "Deletion of Virtual Machine '$vm_name' initiated successfully."
}

delete_storage() {
  local storage_name="$1"
  if [[ -z "$storage_name" ]]; then
    log "$ERROR" "No Storage Account name provided for deletion."
    exit 1
  fi

  if ! storage_exists "$storage_name"; then
    log "$ERROR" "Storage Account '$storage_name' does not exist or is already deleted."
    exit 1
  fi

  log "$INFO" "Deleting Storage Account '$storage_name'..."
  if ! az storage account delete --name "$storage_name" --resource-group "$RESOURCE_GROUP" --yes --no-wait | tee -a "$LOG_FILE"; then
    log "$ERROR" "Failed to delete Storage Account '$storage_name'."
    exit 1
  fi
  log "$INFO" "Deletion of Storage Account '$storage_name' initiated successfully."
}

# Delete Resource Group
delete_resource_group_func() {
  local group_name="$1"
  if [[ -z "$group_name" ]]; then
    # If no group is provided, list available groups interactively
    group_name=$(az group list --query "[].name" -o tsv | fzf --height=15 --header="Select a resource group to delete:")
    [[ -z "$group_name" ]] && { log "$ERROR" "No resource group selected for deletion."; return 1; }
  fi

  # Confirm deletion
  read -r -p "Are you sure you want to delete the resource group '$group_name' and all its resources? [y/N]: " confirmation
  case "$confirmation" in
    [yY][eE][sS]|[yY])
      ;;
    *)
      log "$INFO" "Deletion of resource group '$group_name' canceled."
      return 0
      ;;
  esac

  # Delete the resource group
  log "$INFO" "Deleting resource group '$group_name'..."
  if ! az group delete --name "$group_name" --yes --no-wait | tee -a "$LOG_FILE"; then
    log "$ERROR" "Failed to delete resource group '$group_name'."
    exit 1
  fi
  log "$INFO" "Deletion of resource group '$group_name' initiated successfully."
}

view_mysql() {
  local server_name="$1"
  if [[ -z "$server_name" ]]; then
    log "$ERROR" "No MySQL server name provided for viewing details."
    exit 1
  fi

  if ! server_exists "$server_name"; then
    log "$ERROR" "MySQL Server '$server_name' does not exist in resource group '$RESOURCE_GROUP'."
    exit 1
  fi

  az mysql flexible-server show --name "$server_name" --resource-group "$RESOURCE_GROUP" | tee -a "$LOG_FILE"
}

view_vm() {
  local vm_name="$1"
  if [[ -z "$vm_name" ]]; then
    log "$ERROR" "No VM name provided for viewing details."
    exit 1
  fi

  if ! vm_exists "$vm_name"; then
    log "$ERROR" "Virtual Machine '$vm_name' does not exist in resource group '$RESOURCE_GROUP'."
    exit 1
  fi

  az vm show --name "$vm_name" --resource-group "$RESOURCE_GROUP" | tee -a "$LOG_FILE"
}

view_storage() {
  local storage_name="$1"
  if [[ -z "$storage_name" ]]; then
    log "$ERROR" "No Storage Account name provided for viewing details."
    exit 1
  fi

  if ! storage_exists "$storage_name"; then
    log "$ERROR" "Storage Account '$storage_name' does not exist in resource group '$RESOURCE_GROUP'."
    exit 1
  fi

  az storage account show --name "$storage_name" --resource-group "$RESOURCE_GROUP" | tee -a "$LOG_FILE"
}

# ---------------------------
# Initialization
# ---------------------------

initialize() {
  load_env
  check_jq
  ensure_compatibility

  # Validate essential MySQL template files
  if [[ ! -f "$TEMPLATE_FILE" ]]; then
    log "$ERROR" "Template file not found at $TEMPLATE_FILE. Exiting."
    exit 1
  fi

  if [[ ! -f "$PARAMETERS_FILE" ]]; then
    log "$ERROR" "Parameters file not found at $PARAMETERS_FILE. Exiting."
    exit 1
  fi

  # Load all patch files
  if [[ -d "$PATCH_DIR" ]]; then
    log "$INFO" "Searching for patch files in '$PATCH_DIR'..."
    for patch_file in "$PATCH_DIR"/patch-*.sh; do
      if [[ -f "$patch_file" ]]; then
        log "$INFO" "Loading patch file: $patch_file"
        # shellcheck disable=SC1090
        source "$patch_file"
      fi
    done
    log "$INFO" "All available patches loaded successfully."
  else
    log "$INFO" "No patches directory found. Proceeding without patches."
  fi

  # Load GUI module
  if [[ -f "$GUI_DIR/agent_menu.sh" ]]; then
    log "$INFO" "Loading GUI module..."
    # shellcheck disable=SC1090
    source "$GUI_DIR/agent_menu.sh"
    log "$INFO" "GUI module loaded successfully."
  else
    log "$ERROR" "GUI script 'agent_menu.sh' not found in '$GUI_DIR'. Exiting."
    exit 1
  fi
}

# ---------------------------
# Command-Line Argument Parsing
# ---------------------------

usage() {
  cat <<EOF
Usage: $0 <command> [options]

Commands:
  list <resource_type>                List resources. resource_type can be: mysql, vm, storage, all, resource-group
  deploy <resource_type>              Deploy a new resource. resource_type can be: mysql, vm, storage
  delete <resource_type> <name>       Delete a resource. resource_type can be: mysql, vm, storage
  view <resource_type> <name>         View details of a resource. resource_type can be: mysql, vm, storage
  set-resource-group [group_name]     Switch the active resource group. If no group_name is provided, a list will be shown.
  delete-resource-group [group_name]  Delete a resource group. If no group_name is provided, a list will be shown.
  help                                Display this help message

Premium Commands:
  <premium_command>                   Description of premium command.

Examples:
  $0 list mysql
  $0 deploy vm
  $0 delete storage troopstorage
  $0 view mysql troop-mysql
  $0 set-resource-group TROOP-Production
  $0 delete-resource-group TROOP-Test
EOF
}

parse_command() {
  local command="$1"
  shift

  case "$command" in
    list)
      if [[ $# -ne 1 ]]; then
        log "$ERROR" "'list' command requires exactly one argument."
        usage
        exit 1
      fi
      list_resources "$1"
      ;;
    deploy)
      if [[ $# -ne 1 ]]; then
        log "$ERROR" "'deploy' command requires exactly one argument."
        usage
        exit 1
      fi
      case "$1" in
        mysql)
          deploy_mysql
          ;;
        vm)
          deploy_vm
          ;;
        storage)
          deploy_storage
          ;;
        *)
          log "$ERROR" "Unsupported resource type for deploy: $1"
          usage
          exit 1
          ;;
      esac
      ;;
    delete)
      if [[ $# -ne 2 ]]; then
        log "$ERROR" "'delete' command requires exactly two arguments."
        usage
        exit 1
      fi
      case "$1" in
        mysql)
          delete_mysql "$2"
          ;;
        vm)
          delete_vm "$2"
          ;;
        storage)
          delete_storage "$2"
          ;;
        *)
          log "$ERROR" "Unsupported resource type for delete: $1"
          usage
          exit 1
          ;;
      esac
      ;;
    view)
      if [[ $# -ne 2 ]]; then
        log "$ERROR" "'view' command requires exactly two arguments."
        usage
        exit 1
      fi
      case "$1" in
        mysql)
          view_mysql "$2"
          ;;
        vm)
          view_vm "$2"
          ;;
        storage)
          view_storage "$2"
          ;;
        *)
          log "$ERROR" "Unsupported resource type for view: $1"
          usage
          exit 1
          ;;
      esac
      ;;
    set-resource-group)
      if [[ $# -gt 1 ]]; then
        log "$ERROR" "'set-resource-group' command takes at most one argument."
        usage
        exit 1
      fi
      local group_name=""
      if [[ $# -eq 1 ]]; then
        group_name="$1"
      fi
      switch_resource_group "$group_name"
      ;;
    delete-resource-group)
      if [[ $# -gt 1 ]]; then
        log "$ERROR" "'delete-resource-group' command takes at most one argument."
        usage
        exit 1
      fi
      local group_name=""
      if [[ $# -eq 1 ]]; then
        group_name="$1"
      fi
      delete_resource_group_func "$group_name"
      ;;
    help|--help|-h)
      usage
      ;;
    *)
      # Allow patches to handle unknown commands
      if [[ "$PREMIUM_FEATURES_ENABLED" == "true" ]]; then
        if type extend_commands &>/dev/null; then
          extend_commands "$command" "$@"
          exit $?
        fi
      fi
      log "$ERROR" "Unknown command: $command"
      usage
      exit 1
      ;;
  esac
}

# ---------------------------
# Main Execution
# ---------------------------
initialize

if [[ $# -eq 0 ]]; then
  # No arguments provided; run the interactive agent interface
  agent_menu
else
  # Parse commands normally
  parse_command "$@"
fi
