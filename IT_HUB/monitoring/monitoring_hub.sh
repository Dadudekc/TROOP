#!/bin/bash

# Monitoring Hub for Azure Resource Management
# Provides resource health checks, performance metrics, and alerts.

set -euo pipefail

# ---------------------------
# Configuration and Setup
# ---------------------------

ENV_FILE="/mnt/d/TROOP/.env"
LOG_FILE="/mnt/d/TROOP/monitoring.log"

ROOT_DIR="/mnt/d/TROOP"
ALERT_CONFIG="$ROOT_DIR/monitoring/alert_rules.json"

INFO="INFO"
ERROR="ERROR"

log() {
  local level="$1"
  local message="$2"
  echo "$(date +"%Y-%m-%d %H:%M:%S") [$level] $message" | tee -a "$LOG_FILE"
}

load_env() {
  if [[ -f "$ENV_FILE" ]]; then
    source "$ENV_FILE"
    log "$INFO" "Environment variables loaded."
  else
    log "$ERROR" "'.env' file not found. Exiting."
    exit 1
  fi
}

check_dependencies() {
  for cmd in az jq; do
    if ! command -v "$cmd" &>/dev/null; then
      log "$ERROR" "Dependency '$cmd' not found. Please install it."
      exit 1
    fi
  done
}

# ---------------------------
# Monitoring Functions
# ---------------------------

# Check the status of VMs in the resource group
check_vm_health() {
  log "$INFO" "Checking VM health in resource group '$RESOURCE_GROUP'..."
  az vm list -d --resource-group "$RESOURCE_GROUP" --query "[].{Name:name,Status:powerState}" -o table
}

# Check the status of MySQL servers in the resource group
check_mysql_health() {
  log "$INFO" "Checking MySQL health in resource group '$RESOURCE_GROUP'..."
  az mysql flexible-server list --resource-group "$RESOURCE_GROUP" --query "[].{Name:name,Status:state}" -o table
}

# Check the status of storage accounts in the resource group
check_storage_health() {
  log "$INFO" "Checking Storage Account health in resource group '$RESOURCE_GROUP'..."
  az storage account list --resource-group "$RESOURCE_GROUP" --query "[].{Name:name,Status:statusOfPrimary}" -o table
}

# Collect performance metrics for a VM
get_vm_metrics() {
  local vm_name="$1"
  log "$INFO" "Collecting performance metrics for VM '$vm_name'..."
  az monitor metrics list \
    --resource "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Compute/virtualMachines/$vm_name" \
    --metric "Percentage CPU" \
    --interval PT1M \
    --aggregation Average \
    --output table
}

# Monitor storage utilization
get_storage_metrics() {
  local storage_name="$1"
  log "$INFO" "Collecting performance metrics for Storage Account '$storage_name'..."
  az monitor metrics list \
    --resource "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Storage/storageAccounts/$storage_name" \
    --metric "UsedCapacity" \
    --interval PT1H \
    --aggregation Average \
    --output table
}

# ---------------------------
# Alerting System
# ---------------------------

# Set an alert for a resource
set_alert() {
  local resource_name="$1"
  local resource_type="$2"
  local metric_name="$3"
  local threshold="$4"
  log "$INFO" "Setting alert for $resource_type '$resource_name' on metric '$metric_name' with threshold $threshold..."

  az monitor metrics alert create \
    --name "Alert-$resource_name-$metric_name" \
    --resource-group "$RESOURCE_GROUP" \
    --scopes "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.$resource_type/$resource_name" \
    --condition "avg $metric_name > $threshold" \
    --window-size "5m" \
    --evaluation-frequency "1m" \
    --action-groups "ActionGroupName"
}

# Trigger alerts based on alert rules
trigger_alerts() {
  if [[ -f "$ALERT_CONFIG" ]]; then
    jq -c '.alerts[]' "$ALERT_CONFIG" | while read -r alert; do
      local name=$(echo "$alert" | jq -r '.name')
      local type=$(echo "$alert" | jq -r '.type')
      local metric=$(echo "$alert" | jq -r '.metric')
      local threshold=$(echo "$alert" | jq -r '.threshold')
      set_alert "$name" "$type" "$metric" "$threshold"
    done
  else
    log "$ERROR" "Alert configuration file not found at $ALERT_CONFIG."
  fi
}

# ---------------------------
# Interactive Menu
# ---------------------------

monitoring_menu() {
  while true; do
    action=$(printf "Check VM Health\nCheck MySQL Health\nCheck Storage Health\nGet VM Metrics\nGet Storage Metrics\nSet Alerts\nExit" \
      | fzf --height=20 --border --header="Monitoring Hub: Select an action")

    case "$action" in
      "Check VM Health")
        check_vm_health
        ;;
      "Check MySQL Health")
        check_mysql_health
        ;;
      "Check Storage Health")
        check_storage_health
        ;;
      "Get VM Metrics")
        echo "Enter VM name:"
        read -r vm_name
        get_vm_metrics "$vm_name"
        ;;
      "Get Storage Metrics")
        echo "Enter Storage Account name:"
        read -r storage_name
        get_storage_metrics "$storage_name"
        ;;
      "Set Alerts")
        trigger_alerts
        ;;
      "Exit")
        log "$INFO" "Exiting Monitoring Hub."
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

initialize() {
  load_env
  check_dependencies
}

initialize
monitoring_menu
