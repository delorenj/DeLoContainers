#!/usr/bin/env python3
"""
Fix AdGuard Home Roblox Filter Configuration
Removes the problematic file:// filter and adds rules to user_rules
"""

import yaml
import sys
import os
from pathlib import Path

def extract_rules_from_filter_file(filter_file_path):
    """Extract blocking rules from the filter file, ignoring comments"""
    rules = []
    try:
        with open(filter_file_path, 'r') as f:
            for line in f:
                line = line.strip()
                # Skip empty lines and comments
                if line and not line.startswith('#'):
                    rules.append(line)
    except FileNotFoundError:
        print(f"Warning: Filter file {filter_file_path} not found")
    return rules

def fix_adguard_config():
    config_path = "/home/delorenj/docker/trunk-main/stacks/utils/adguard/conf/AdGuardHome.yaml"
    filter_file_path = "/home/delorenj/docker/trunk-main/stacks/utils/adguard/filters/roblox-block.txt"
    
    # Backup the original config
    backup_path = config_path + ".backup-fix"
    os.system(f"sudo cp {config_path} {backup_path}")
    
    # Read the current config
    with open(config_path, 'r') as f:
        config = yaml.safe_load(f)
    
    # Extract rules from the roblox filter file
    roblox_rules = extract_rules_from_filter_file(filter_file_path)
    print(f"Extracted {len(roblox_rules)} rules from roblox filter")
    
    # Remove the problematic filter (id: 9999)
    original_filters = config.get('filters', [])
    updated_filters = [f for f in original_filters if f.get('id') != 9999]
    
    removed_count = len(original_filters) - len(updated_filters)
    if removed_count > 0:
        print(f"Removed {removed_count} problematic filter(s)")
        config['filters'] = updated_filters
    
    # Add roblox rules to user_rules
    current_user_rules = config.get('user_rules', [])
    
    # Add a comment to identify the roblox rules
    roblox_section = ["# Roblox Blocking Rules (migrated from filter)"] + roblox_rules
    
    # Combine existing user rules with roblox rules
    config['user_rules'] = current_user_rules + roblox_section
    
    print(f"Added {len(roblox_rules)} roblox rules to user_rules")
    
    # Write the updated config
    with open(config_path, 'w') as f:
        yaml.dump(config, f, default_flow_style=False, sort_keys=False)
    
    print(f"Configuration updated successfully")
    print(f"Backup saved to: {backup_path}")
    
    return True

if __name__ == "__main__":
    try:
        # Need to run with sudo to modify the config file
        if os.geteuid() != 0:
            print("This script needs to be run with sudo to modify AdGuard config files")
            sys.exit(1)
            
        fix_adguard_config()
        print("✅ AdGuard configuration fixed successfully!")
        
    except Exception as e:
        print(f"❌ Error fixing configuration: {e}")
        sys.exit(1)
