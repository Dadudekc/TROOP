#!/bin/bash

# Patch: Logic Apps Management
# Adds functionality to manage Azure Logic Apps.

# Function to deploy a Logic App
deploy_logic_app() {
  log "$INFO" "Deploying a new Logic App in resource group '$RESOURCE_GROUP'..."

  if az logicapp show --resource-group "$RESOURCE_GROUP" --name "$LOGIC_APP_NAME" &>/dev/null; then
    log "$INFO" "Logic App '$LOGIC_APP_NAME' already exists. Generating a unique name."
    LOGIC_APP_NAME=$(generate_unique_name "$LOGIC_APP_NAME")
    log "$INFO" "Generated unique Logic App name: $LOGIC_APP_NAME"
  fi

  # Example deployment command (replace with actual deployment logic)
  az logicapp create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$LOGIC_APP_NAME" \
    --location "$LOGIC_APP_LOCATION" \
    --definition "@$LOGIC_APP_DEFINITION_FILE" | tee -a "$LOG_FILE"

  log "$INFO" "Deployment of Logic App '$LOGIC_APP_NAME' initiated successfully!"
}

# Function to delete a Logic App
delete_logic_app() {
  local logic_app_name="$1"
  if [[ -z "$logic_app_name" ]]; then
    log "$ERROR" "No Logic App name provided for deletion."
    exit 1
  fi

  if ! az logicapp show --resource-group "$RESOURCE_GROUP" --name "$logic_app_name" &>/dev/null; then
    log "$ERROR" "Logic App '$logic_app_name' does not exist in resource group '$RESOURCE_GROUP'."
    exit 1
  fi

  log "$INFO" "Deleting Logic App '$logic_app_name'..."
  if ! az logicapp delete --resource-group "$RESOURCE_GROUP" --name "$logic_app_name" --yes --no-wait | tee -a "$LOG_FILE"; then
    log "$ERROR" "Failed to delete Logic App '$logic_app_name'."
    exit 1
  fi
  log "$INFO" "Deletion of Logic App '$logic_app_name' initiated successfully."
}

# Function to view Logic App details
view_logic_app() {
  local logic_app_name="$1"
  if [[ -z "$logic_app_name" ]]; then
    log "$ERROR" "No Logic App name provided for viewing details."
    exit 1
  fi

  if ! az logicapp show --resource-group "$RESOURCE_GROUP" --name "$logic_app_name" &>/dev/null; then
    log "$ERROR" "Logic App '$logic_app_name' does not exist in resource group '$RESOURCE_GROUP'."
    exit 1
  fi

  az logicapp show --resource-group "$RESOURCE_GROUP" --name "$logic_app_name" | tee -a "$LOG_FILE"
}

# Extend command parsing to include Logic Apps commands
extend_commands() {
  local command="$1"
  shift

  case "$command" in
    deploy-logic-app)
      deploy_logic_app "$@"
      ;;
    delete-logic-app)
      delete_logic_app "$@"
      ;;
    view-logic-app)
      view_logic_app "$@"
      ;;
    *)
      log "$ERROR" "Unknown premium command: $command"
      return 1
      ;;
  esac
}
