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
LOG_FILE="/mnt/d/TROOP/it_hub.log"

ROOT_DIR="/mnt/d/TROOP"
TEMPLATE_FILE="$ROOT_DIR/Templates/mysql_flexible_server_template.json"
PARAMETERS_FILE="$ROOT_DIR/Parameters/azure-troop-mysql-parameters.json"
TEMP_PARAMETERS_FILE="$ROOT_DIR/Parameters/temp_parameters.json"

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
      log "$INFO" "Listing all MySQL Flexible Servers in the subscription..."
      az mysql flexible-server list -o table | tee -a "$LOG_FILE"
      ;;
    vm)
      log "$INFO" "Listing all Virtual Machines in the subscription..."
      az vm list -o table | tee -a "$LOG_FILE"
      ;;
    storage)
      log "$INFO" "Listing all Storage Accounts in the subscription..."
      az storage account list -o table | tee -a "$LOG_FILE"
      ;;
    all)
      list_resources mysql
      list_resources vm
      list_resources storage
      ;;
    *)
      log "$ERROR" "Unsupported resource type for listing: $resource_type"
      ;;
  esac
}

deploy_mysql() {
  log "$INFO" "Deploying a new MySQL Flexible Server..."

  if server_exists "$MYSQL_SERVER_NAME"; then
    log "$INFO" "Server name '$MYSQL_SERVER_NAME' already exists. Generating a unique name."
    MYSQL_SERVER_NAME=$(generate_unique_name "$MYSQL_SERVER_NAME")
    log "$INFO" "Generated unique server name: $MYSQL_SERVER_NAME"
  fi

  create_mysql_temp_parameters

  log "$INFO" "Validating the deployment template for MySQL..."
  if ! VALIDATION_OUTPUT=$(az deployment group validate \
    --resource-group "$RESOURCE_GROUP" \
    --template-file "$TEMPLATE_FILE" \
    --parameters "@$TEMP_PARAMETERS_FILE" 2>&1); then
    log "$ERROR" "Template validation failed for MySQL. Details:"
    log "$ERROR" "$VALIDATION_OUTPUT"
    log "$INFO" "Retaining temp_parameters.json for debugging."
    exit 1
  fi
  log "$INFO" "Template validation passed for MySQL."

  log "$INFO" "Deploying the MySQL Flexible Server..."
  if ! DEPLOYMENT_OUTPUT=$(az deployment group create \
    --resource-group "$RESOURCE_GROUP" \
    --template-file "$TEMPLATE_FILE" \
    --parameters "@$TEMP_PARAMETERS_FILE" 2>&1); then
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
  log "$INFO" "Deploying a new Virtual Machine..."

  if vm_exists "$VM_NAME"; then
    log "$INFO" "VM name '$VM_NAME' already exists. Generating a unique name."
    VM_NAME=$(generate_unique_name "$VM_NAME")
    log "$INFO" "Generated unique VM name: $VM_NAME"
  fi

  if ! az vm create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VM_NAME" \
    --size "$VM_SIZE" \
    --image "$VM_IMAGE" \
    --admin-username "$VM_ADMIN_USERNAME" \
    --admin-password "$VM_ADMIN_PASSWORD" \
    --no-wait | tee -a "$LOG_FILE"; then
    log "$ERROR" "Deployment failed for VM '$VM_NAME'."
    exit 1
  fi
  log "$INFO" "Deployment of VM '$VM_NAME' initiated successfully!"
}

deploy_storage() {
  log "$INFO" "Deploying a new Storage Account..."

  if storage_exists "$STORAGE_ACCOUNT_NAME"; then
    log "$INFO" "Storage Account name '$STORAGE_ACCOUNT_NAME' already exists. Generating a unique name."
    STORAGE_ACCOUNT_NAME=$(generate_unique_name "$STORAGE_ACCOUNT_NAME")
    log "$INFO" "Generated unique Storage Account name: $STORAGE_ACCOUNT_NAME"
  fi

  if ! az storage account create \
    --name "$STORAGE_ACCOUNT_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$STORAGE_LOCATION" \
    --sku "$STORAGE_SKU" | tee -a "$LOG_FILE"; then
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
}

# ---------------------------
# Command-Line Argument Parsing
# ---------------------------

usage() {
  cat <<EOF
Usage: $0 <command> [options]

Commands:
  list <resource_type>                List resources. resource_type can be: mysql, vm, storage, all
  deploy <resource_type>              Deploy a new resource. resource_type can be: mysql, vm, storage
  delete <resource_type> <name>       Delete a resource. resource_type can be: mysql, vm, storage
  view <resource_type> <name>         View details of a resource. resource_type can be: mysql, vm, storage
  help                                Display this help message

Examples:
  $0 list mysql
  $0 deploy vm
  $0 delete storage troopstorage
  $0 view mysql troop-mysql
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
    help|--help|-h)
      usage
      ;;
    *)
      log "$ERROR" "Unknown command: $command"
      usage
      exit 1
      ;;
  esac
}

# ---------------------------
# Agent Interface (fzf)
# ---------------------------
agent_menu() {
  if ! command -v fzf &>/dev/null; then
    log "$ERROR" "fzf not found. Please install fzf for the agent interface."
    log "$INFO"  "Running usage instructions instead."
    usage
    return
  fi

  while true; do
    action=$(printf "List Resources\nDeploy Resource\nDelete Resource\nView Resource Details\nExit" \
      | fzf --height=15 --border --header="Select an action to perform:")

    case "$action" in
      "List Resources")
        resource_type=$(printf "mysql\nvm\nstorage\nall" \
          | fzf --height=10 --border --header="Select resource type:")
        [[ -n "$resource_type" ]] && list_resources "$resource_type"
        ;;
      "Deploy Resource")
        resource_type=$(printf "mysql\nvm\nstorage" \
          | fzf --height=6 --border --header="Select resource type to deploy:")
        if [[ -n "$resource_type" ]]; then
          case "$resource_type" in
            mysql)    deploy_mysql ;;
            vm)       deploy_vm ;;
            storage)  deploy_storage ;;
          esac
        fi
        ;;
      "Delete Resource")
        resource_type=$(printf "mysql\nvm\nstorage" \
          | fzf --height=6 --border --header="Select resource type to delete:")
        if [[ -n "$resource_type" ]]; then
          echo "Type the name of the $resource_type to delete, then press Enter."
          read -r resource_name
          [[ -n "$resource_name" ]] && delete_"$resource_type" "$resource_name"
        fi
        ;;
      "View Resource Details")
        resource_type=$(printf "mysql\nvm\nstorage" \
          | fzf --height=6 --border --header="Select resource type to view:")
        if [[ -n "$resource_type" ]]; then
          echo "Type the name of the $resource_type to view, then press Enter."
          read -r resource_name
          [[ -n "$resource_name" ]] && view_"$resource_type" "$resource_name"
        fi
        ;;
      "Exit")
        log "$INFO" "Exiting the agent interface."
        break
        ;;
      *)
        log "$ERROR" "Invalid choice. Please try again."
        ;;
    esac
  done
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
