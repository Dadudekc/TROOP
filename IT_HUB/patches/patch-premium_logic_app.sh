#!/bin/bash

# Patch: Logic App Management
# Adds functionality to manage Azure Logic Apps.

# Function to deploy a Logic App
deploy_logic_app() {
  local app_name="$1"
  local location="$2"
  local resource_group="$3"

  if [[ -z "$app_name" || -z "$location" || -z "$resource_group" ]]; then
    log "$ERROR" "Usage: deploy_logic_app <app_name> <location> <resource_group>"
    return 1
  fi

  log "$INFO" "Deploying Logic App '$app_name' in location '$location' within resource group '$resource_group'..."

  if az logicapp show --name "$app_name" --resource-group "$resource_group" &> /dev/null; then
    log "$ERROR" "Logic App '$app_name' already exists."
    return 1
  fi

  if ! az logicapp create --resource-group "$resource_group" --name "$app_name" --location "$location" | tee -a "$LOG_FILE"; then
    log "$ERROR" "Failed to deploy Logic App '$app_name'."
    return 1
  fi

  log "$INFO" "Logic App '$app_name' deployed successfully!"
}

# Function to delete a Logic App
delete_logic_app() {
  local app_name="$1"
  local resource_group="$2"

  if [[ -z "$app_name" || -z "$resource_group" ]]; then
    log "$ERROR" "Usage: delete_logic_app <app_name> <resource_group>"
    return 1
  fi

  if ! az logicapp show --name "$app_name" --resource-group "$resource_group" &> /dev/null; then
    log "$ERROR" "Logic App '$app_name' does not exist."
    return 1
  fi

  log "$INFO" "Deleting Logic App '$app_name' from resource group '$resource_group'..."
  if ! az logicapp delete --name "$app_name" --resource-group "$resource_group" --yes | tee -a "$LOG_FILE"; then
    log "$ERROR" "Failed to delete Logic App '$app_name'."
    return 1
  fi

  log "$INFO" "Logic App '$app_name' deleted successfully!"
}

# Function to list Logic Apps
list_logic_apps() {
  local resource_group="$1"

  if [[ -z "$resource_group" ]]; then
    log "$ERROR" "Usage: list_logic_apps <resource_group>"
    return 1
  fi

  log "$INFO" "Listing all Logic Apps in resource group '$resource_group'..."
  az logicapp list --resource-group "$resource_group" -o table | tee -a "$LOG_FILE"
}

# Function to view details of a Logic App
view_logic_app() {
  local app_name="$1"
  local resource_group="$2"

  if [[ -z "$app_name" || -z "$resource_group" ]]; then
    log "$ERROR" "Usage: view_logic_app <app_name> <resource_group>"
    return 1
  fi

  if ! az logicapp show --name "$app_name" --resource-group "$resource_group" &> /dev/null; then
    log "$ERROR" "Logic App '$app_name' does not exist."
    return 1
  fi

  az logicapp show --name "$app_name" --resource-group "$resource_group" | tee -a "$LOG_FILE"
}

# Extend command parsing to include Logic App commands
extend_commands() {
  local command="$1"
  shift

  case "$command" in
    deploy_logic_app)
      deploy_logic_app "$@"
      ;;
    delete_logic_app)
      delete_logic_app "$@"
      ;;
    list_logic_apps)
      list_logic_apps "$@"
      ;;
    view_logic_app)
      view_logic_app "$@"
      ;;
    *)
      log "$ERROR" "Unknown premium command: $command"
      return 1
      ;;
  esac
}
