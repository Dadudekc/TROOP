#!/bin/bash

# GUI Module: Agent Menu
# Provides an interactive menu using fzf for user interactions.

# Ensure this script is sourced, not executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "This script is intended to be sourced by it_hub.sh" >&2
  exit 1
fi

agent_menu() {
  if ! command -v fzf &>/dev/null; then
    log "$ERROR" "fzf not found. Please install fzf for the agent interface."
    log "$INFO"  "Running usage instructions instead."
    usage
    return
  fi

  while true; do
    # Build the menu options dynamically
    menu_options=("List Resources"
                  "Deploy Resource"
                  "Delete Resource"
                  "View Resource Details"
                  "Switch Resource Group"
                  "Delete Resource Group")

    [[ "$PREMIUM_FEATURES_ENABLED" == "true" ]] && menu_options+=("Premium Features")
    menu_options+=("Exit")

    # Display the main menu
    action=$(printf "%s\n" "${menu_options[@]}" | fzf --height=25 --border --header="Select an action to perform:")

    case "$action" in
      "List Resources") handle_resource_action "list" ;;
      "Deploy Resource") handle_resource_action "deploy" ;;
      "Delete Resource") handle_resource_action "delete" ;;
      "View Resource Details") handle_resource_action "view" ;;
      "Switch Resource Group") switch_resource_group_interactive ;;
      "Delete Resource Group") delete_resource_group_interactive ;;
      "Premium Features") handle_premium_features ;;
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

# Handle resource-related actions
handle_resource_action() {
  local action=$1
  local resource_types=("mysql" "vm" "storage")
  [[ "$action" == "list" ]] && resource_types+=("all" "resource-group")

  resource_type=$(printf "%s\n" "${resource_types[@]}" | fzf --height=15 --border --header="Select resource type:")
  [[ -z "$resource_type" ]] && return

  case "$action" in
    "list") list_resources "$resource_type" ;;
    "deploy") deploy_"$resource_type" ;;
    "delete")
      echo "Type the name of the $resource_type to delete, then press Enter."
      read -r resource_name
      [[ -n "$resource_name" ]] && delete_"$resource_type" "$resource_name"
      ;;
    "view")
      echo "Type the name of the $resource_type to view, then press Enter."
      read -r resource_name
      [[ -n "$resource_name" ]] && view_"$resource_type" "$resource_name"
      ;;
    *)
      log "$ERROR" "Unknown resource action: $action"
      ;;
  esac
}

# Switch resource group interactively or by name
switch_resource_group_interactive() {
  echo "Enter the name of the new resource group, or leave blank to select interactively."
  read -r -p "Resource group name: " new_group
  switch_resource_group "$new_group"
}

# Delete resource group interactively or by name
delete_resource_group_interactive() {
  echo "Enter the name of the resource group to delete, or leave blank to select interactively."
  read -r -p "Resource group name: " del_group
  delete_resource_group_func "$del_group"
}

# Handle premium feature selection
handle_premium_features() {
  if [[ "$PREMIUM_FEATURES_ENABLED" != "true" ]]; then
    log "$ERROR" "Premium Features are not enabled. Please upgrade to access."
    return
  fi

  # Define premium feature options
  premium_options=("Cost Optimization"
                   "Advanced Scheduling"
                   "Backup and Restore"
                   "Kubernetes Management"
                   "Exit")

  premium_action=$(printf "%s\n" "${premium_options[@]}" | fzf --height=20 --border --header="Select a premium feature:")
  
  case "$premium_action" in
    "Cost Optimization") run_premium_action "cost_optimization" ;;
    "Advanced Scheduling") run_premium_action "advanced_scheduling" ;;
    "Backup and Restore") run_premium_action "backup_and_restore" ;;
    "Kubernetes Management") kubernetes_menu ;;
    "Exit") ;;
    *) log "$ERROR" "Invalid premium action: $premium_action" ;;
  esac
}

# Helper function to execute premium actions
run_premium_action() {
  local action=$1
  if type "$action" &>/dev/null; then
    "$action"
  else
    log "$ERROR" "$action feature not available."
  fi
}

# Kubernetes submenu
kubernetes_menu() {
  kubernetes_options=("Deploy Kubernetes Cluster"
                      "Delete Kubernetes Cluster"
                      "View Kubernetes Cluster Details"
                      "Back to Main Menu")

  kubernetes_action=$(printf "%s\n" "${kubernetes_options[@]}" | fzf --height=10 --border --header="Select a Kubernetes action:")
  
  case "$kubernetes_action" in
    "Deploy Kubernetes Cluster") deploy_kubernetes ;;
    "Delete Kubernetes Cluster")
      echo "Type the name of the Kubernetes cluster to delete, then press Enter."
      read -r cluster_name
      [[ -n "$cluster_name" ]] && delete_kubernetes "$cluster_name"
      ;;
    "View Kubernetes Cluster Details")
      echo "Type the name of the Kubernetes cluster to view, then press Enter."
      read -r cluster_name
      [[ -n "$cluster_name" ]] && view_kubernetes "$cluster_name"
      ;;
    "Back to Main Menu") ;;
    *) log "$ERROR" "Invalid Kubernetes action. Returning to main menu." ;;
  esac
}
