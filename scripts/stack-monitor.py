#!/usr/bin/env python3
"""
Docker Stack Monitor
Ensures configured stacks are always running based on stack-config.yml
"""

import os
import sys
import yaml
import subprocess
import time
import logging
from datetime import datetime
from pathlib import Path
import json
import requests
from urllib.parse import urlparse

class StackMonitor:
    def __init__(self, config_path="/home/delorenj/docker/stack-config.yml"):
        self.config_path = config_path
        self.docker_root = Path("/home/delorenj/docker")
        self.config = self.load_config()
        self.setup_logging()
        
    def load_config(self):
        """Load configuration from YAML file"""
        try:
            with open(self.config_path, 'r') as f:
                return yaml.safe_load(f)
        except Exception as e:
            print(f"Error loading config: {e}")
            sys.exit(1)
    
    def setup_logging(self):
        """Setup logging configuration"""
        log_file = self.config.get('settings', {}).get('log_file', 
                                                      '/home/delorenj/docker/logs/stack-monitor.log')
        
        # Create logs directory if it doesn't exist
        os.makedirs(os.path.dirname(log_file), exist_ok=True)
        
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler(log_file),
                logging.StreamHandler()
            ]
        )
        self.logger = logging.getLogger(__name__)
    
    def run_command(self, cmd, cwd=None):
        """Run shell command and return result"""
        try:
            result = subprocess.run(
                cmd, shell=True, capture_output=True, text=True, cwd=cwd
            )
            return result.returncode == 0, result.stdout, result.stderr
        except Exception as e:
            return False, "", str(e)
    
    def get_containers_managed_by_stack(self, compose_file):
        """Get list of container names that would be created by this compose file"""
        compose_path = self.docker_root / compose_file
        if not compose_path.exists():
            return []
        
        # Use docker compose config to get the resolved configuration
        cmd = f"docker compose -f {compose_path} config --format json"
        success, stdout, stderr = self.run_command(cmd, cwd=compose_path.parent)
        
        if not success:
            self.logger.debug(f"Failed to get compose config: {stderr}")
            return []
        
        try:
            config = json.loads(stdout)
            services = config.get('services', {})
            project_name = compose_path.parent.name  # Default project name is directory name
            
            # Build expected container names
            container_names = []
            for service_name, service_config in services.items():
                # Check if container_name is explicitly set
                if 'container_name' in service_config:
                    container_names.append(service_config['container_name'])
                else:
                    # Default naming: projectname-servicename-1
                    container_names.append(f"{project_name}-{service_name}-1")
            
            return container_names
        except Exception as e:
            self.logger.debug(f"Error parsing compose config: {e}")
            return []
    
    def get_stack_status(self, compose_file):
        """Check if a stack is running"""
        compose_path = self.docker_root / compose_file
        if not compose_path.exists():
            return False, f"Compose file not found: {compose_path}"
        
        cmd = f"docker compose -f {compose_path} ps --format json"
        success, stdout, stderr = self.run_command(cmd, cwd=compose_path.parent)
        
        if not success:
            return False, f"Failed to check status: {stderr}"
        
        try:
            if stdout.strip():
                containers = [json.loads(line) for line in stdout.strip().split('\n')]
                running_containers = [c for c in containers if c.get('State') == 'running']
                total_containers = len(containers)
                
                if total_containers == 0:
                    return False, "No containers defined"
                elif len(running_containers) == total_containers:
                    return True, f"All {total_containers} containers running"
                else:
                    return False, f"{len(running_containers)}/{total_containers} containers running"
            else:
                return False, "No containers found"
        except Exception as e:
            return False, f"Error parsing status: {e}"
    
    def start_stack(self, compose_file):
        """Start a Docker Compose stack"""
        compose_path = self.docker_root / compose_file
        
        self.logger.info(f"Starting stack: {compose_file}")
        cmd = f"docker compose -f {compose_path} up -d"
        success, stdout, stderr = self.run_command(cmd, cwd=compose_path.parent)
        
        if success:
            self.logger.info(f"Successfully started: {compose_file}")
            return True
        else:
            self.logger.error(f"Failed to start {compose_file}: {stderr}")
            return False
    
    def stop_stack(self, compose_file):
        """Stop a Docker Compose stack"""
        compose_path = self.docker_root / compose_file
        
        self.logger.info(f"Stopping stack: {compose_file}")
        cmd = f"docker compose -f {compose_path} down"
        success, stdout, stderr = self.run_command(cmd, cwd=compose_path.parent)
        
        if success:
            self.logger.info(f"Successfully stopped: {compose_file}")
            return True
        else:
            self.logger.error(f"Failed to stop {compose_file}: {stderr}")
            return False
    
    def get_traefik_hosts(self, compose_file):
        """Extract Traefik host labels from compose file"""
        compose_path = self.docker_root / compose_file
        hosts = []
        
        try:
            with open(compose_path, 'r') as f:
                compose_data = yaml.safe_load(f)
            
            services = compose_data.get('services', {})
            for service_name, service in services.items():
                labels = service.get('labels', [])
                if isinstance(labels, list):
                    # Labels as list format
                    for label in labels:
                        if isinstance(label, str) and 'traefik.http.routers' in label and '.rule=Host' in label:
                            # Extract host from label like "traefik.http.routers.service.rule=Host(`service.delo.sh`)"
                            if 'Host(`' in label:
                                start = label.find('Host(`') + 6
                                end = label.find('`)', start)
                                if end > start:
                                    host = label[start:end]
                                    hosts.append(host)
                elif isinstance(labels, dict):
                    # Labels as dict format
                    for key, value in labels.items():
                        if 'traefik.http.routers' in key and key.endswith('.rule'):
                            if value and 'Host(`' in value:
                                start = value.find('Host(`') + 6
                                end = value.find('`)', start)
                                if end > start:
                                    host = value[start:end]
                                    hosts.append(host)
        except Exception as e:
            self.logger.debug(f"Could not extract Traefik hosts from {compose_file}: {e}")
        
        return hosts
    
    def ping_check(self, host, timeout=5):
        """Check if a host is accessible via HTTP/HTTPS"""
        # Try HTTPS first, then HTTP
        for scheme in ['https', 'http']:
            url = f"{scheme}://{host}"
            try:
                # First try with SSL verification enabled
                response = requests.get(url, timeout=timeout, allow_redirects=True)
                # Consider any response (even 4xx/5xx) as "accessible"
                # as it means the service is responding
                return True, response.status_code
            except requests.exceptions.SSLError:
                # If SSL verification fails, try without verification but suppress the warning
                import urllib3
                urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
                try:
                    response = requests.get(url, timeout=timeout, allow_redirects=True, verify=False)
                    return True, response.status_code
                except requests.exceptions.RequestException:
                    continue
            except requests.exceptions.RequestException as e:
                continue
        
        return False, None
    
    def get_traefik_external_services(self):
        """Parse Traefik dynamic configuration files for external services"""
        external_services = []
        dynamic_dir = self.docker_root / "core/traefik/traefik-data/dynamic"
        
        if not dynamic_dir.exists():
            return external_services
        
        # Find all YAML files in dynamic directory
        for yaml_file in dynamic_dir.glob("*.yml"):
            try:
                with open(yaml_file, 'r') as f:
                    config = yaml.safe_load(f)
                
                if not config or 'http' not in config:
                    continue
                
                routers = config['http'].get('routers', {})
                services = config['http'].get('services', {})
                
                for router_name, router_config in routers.items():
                    # Skip internal services
                    if router_config.get('service') == 'api@internal':
                        continue
                    
                    # Extract host from rule
                    rule = router_config.get('rule', '')
                    if 'Host(`' in rule:
                        start = rule.find('Host(`') + 6
                        end = rule.find('`)', start)
                        if end > start:
                            host = rule[start:end]
                            
                            # Get service URL
                            service_name = router_config.get('service', '')
                            service_url = None
                            if service_name in services:
                                servers = services[service_name].get('loadBalancer', {}).get('servers', [])
                                if servers:
                                    service_url = servers[0].get('url', '')
                            
                            external_services.append({
                                'host': host,
                                'service_url': service_url,
                                'file': yaml_file.name,
                                'router': router_name
                            })
                            
            except Exception as e:
                self.logger.debug(f"Error parsing {yaml_file}: {e}")
        
        return external_services
    
    def check_and_fix_stack(self, compose_file, config):
        """Check a single stack and fix if needed"""
        enabled = config.get('enabled', False)
        description = config.get('description', 'No description')
        
        is_running, status_msg = self.get_stack_status(compose_file)
        
        if enabled and not is_running:
            self.logger.warning(f"Stack {compose_file} should be running but isn't: {status_msg}")
            if self.start_stack(compose_file):
                # Wait a bit and check again
                time.sleep(10)
                is_running_after, _ = self.get_stack_status(compose_file)
                if is_running_after:
                    self.logger.info(f"Successfully recovered stack: {compose_file}")
                else:
                    self.logger.error(f"Failed to recover stack: {compose_file}")
        elif not enabled and is_running:
            # Before stopping, check if this might conflict with other stacks
            managed_containers = self.get_containers_managed_by_stack(compose_file)
            
            # Special handling for stacks that might have duplicate services
            if 'qdrant' in compose_file.lower():
                # Check if qdrant is running as part of persistence stack
                persistence_compose = "stacks/persistence/compose.yml"
                if persistence_compose in self.config.get('stacks', {}):
                    if self.config['stacks'][persistence_compose].get('enabled', False):
                        persistence_running, _ = self.get_stack_status(persistence_compose)
                        if persistence_running:
                            self.logger.info(f"Stack {compose_file} is disabled but Qdrant is running as part of persistence stack, skipping stop")
                            return
            
            self.logger.info(f"Stack {compose_file} is running but disabled, stopping...")
            self.stop_stack(compose_file)
        elif enabled and is_running:
            self.logger.debug(f"Stack {compose_file} is running as expected: {status_msg}")
            
            # Perform ping check for running enabled stacks
            hosts = self.get_traefik_hosts(compose_file)
            if hosts:
                for host in hosts:
                    accessible, status_code = self.ping_check(host)
                    if accessible:
                        self.logger.debug(f"Service {host} is accessible (HTTP {status_code})")
                    else:
                        self.logger.warning(f"Service {host} is NOT accessible via Traefik")
                        # Optionally restart the stack if not accessible
                        if config.get('restart_on_ping_fail', True):
                            self.logger.info(f"Restarting {compose_file} due to failed ping check")
                            self.stop_stack(compose_file)
                            time.sleep(5)
                            self.start_stack(compose_file)
                            break  # Only restart once per check cycle
            else:
                self.logger.debug(f"No Traefik hosts found for {compose_file}")
        else:
            self.logger.debug(f"Stack {compose_file} is stopped as expected")
    
    def run_check(self):
        """Run a single check cycle"""
        self.logger.info("Starting stack monitoring check")
        
        stacks = self.config.get('stacks', {})
        
        # Sort by priority
        sorted_stacks = sorted(
            stacks.items(), 
            key=lambda x: x[1].get('priority', 999)
        )
        
        for compose_file, config in sorted_stacks:
            try:
                self.check_and_fix_stack(compose_file, config)
                
                # Small delay between stack operations
                restart_delay = self.config.get('settings', {}).get('restart_delay', 30)
                time.sleep(2)  # Short delay between checks
                
            except Exception as e:
                self.logger.error(f"Error checking stack {compose_file}: {e}")
        
        self.logger.info("Stack monitoring check completed")
    
    def status_report(self):
        """Generate a status report of all stacks"""
        stacks = self.config.get('stacks', {})
        sorted_stacks = sorted(stacks.items(), key=lambda x: x[1].get('priority', 999))
        
        # Gather statistics
        total_stacks = len(stacks)
        enabled_stacks = sum(1 for _, cfg in stacks.items() if cfg.get('enabled', False))
        running_stacks = 0
        healthy_services = 0
        total_services = 0
        
        # Process stacks and categorize them
        active_stacks = []
        inactive_stacks = []
        issues = []
        
        for compose_file, config in sorted_stacks:
            enabled = config.get('enabled', False)
            description = config.get('description', 'No description')
            is_running, status_msg = self.get_stack_status(compose_file)
            
            if is_running:
                running_stacks += 1
            
            stack_info = {
                'file': compose_file,
                'enabled': enabled,
                'running': is_running,
                'description': description,
                'status_msg': status_msg,
                'hosts': []
            }
            
            # Check hosts for running stacks
            if is_running and enabled:
                hosts = self.get_traefik_hosts(compose_file)
                for host in hosts:
                    accessible, status_code = self.ping_check(host)
                    total_services += 1
                    if accessible:
                        healthy_services += 1
                    stack_info['hosts'].append({
                        'host': host,
                        'accessible': accessible,
                        'status_code': status_code
                    })
            
            # Categorize stacks
            if enabled:
                if is_running:
                    active_stacks.append(stack_info)
                else:
                    issues.append(stack_info)
            else:
                inactive_stacks.append(stack_info)
        
        # Print header with summary
        print("\n╭─ Docker Stack Monitor ─────────────────────────────────────────────────╮")
        print(f"│ {datetime.now().strftime('%Y-%m-%d %H:%M:%S')} │ Stacks: {running_stacks}/{enabled_stacks} running │ Services: {healthy_services}/{total_services} healthy │")
        print("╰────────────────────────────────────────────────────────────────────────╯")
        
        # Active stacks (enabled and running)
        if active_stacks:
            print("\n🟢 Active Stacks")
            print("─" * 72)
            for stack in active_stacks:
                stack_name = stack['file'].split('/')[-2] if '/' in stack['file'] else stack['file']
                hosts_str = ""
                if stack['hosts']:
                    host_statuses = []
                    for h in stack['hosts']:
                        if h['accessible']:
                            host_statuses.append(f"✓ {h['host']}")
                        else:
                            host_statuses.append(f"✗ {h['host']}")
                    hosts_str = f" │ {', '.join(host_statuses)}"
                
                print(f"  {stack_name:<20} {stack['description']:<30}{hosts_str}")
        
        # Issues (enabled but not running)
        if issues:
            print("\n🔴 Issues")
            print("─" * 72)
            for stack in issues:
                stack_name = stack['file'].split('/')[-2] if '/' in stack['file'] else stack['file']
                print(f"  {stack_name:<20} {stack['status_msg']}")
        
        # Inactive stacks (disabled) - compact display
        if inactive_stacks:
            print("\n⚪ Inactive")
            print("─" * 72)
            inactive_names = []
            for stack in inactive_stacks:
                stack_name = stack['file'].split('/')[-2] if '/' in stack['file'] else stack['file']
                inactive_names.append(stack_name)
            
            # Print in columns
            for i in range(0, len(inactive_names), 4):
                line = "  " + "".join(f"{name:<18}" for name in inactive_names[i:i+4])
                print(line.rstrip())
        
        # External services - compact display
        external_services = self.get_traefik_external_services()
        if external_services:
            print("\n🌐 External Services")
            print("─" * 72)
            
            service_status = []
            for service in external_services:
                accessible, status_code = self.ping_check(service['host'])
                icon = "✓" if accessible else "✗"
                service_status.append(f"{icon} {service['host']}")
            
            # Print in columns
            for i in range(0, len(service_status), 3):
                line = "  " + "".join(f"{svc:<24}" for svc in service_status[i:i+3])
                print(line.rstrip())
        
        print()
    
    def monitor_loop(self):
        """Main monitoring loop"""
        check_interval = self.config.get('settings', {}).get('check_interval', 300)
        
        self.logger.info(f"Starting stack monitor with {check_interval}s interval")
        
        try:
            while True:
                self.run_check()
                time.sleep(check_interval)
        except KeyboardInterrupt:
            self.logger.info("Stack monitor stopped by user")
        except Exception as e:
            self.logger.error(f"Stack monitor error: {e}")

def main():
    if len(sys.argv) > 1:
        command = sys.argv[1]
        monitor = StackMonitor()
        
        if command == "check":
            monitor.run_check()
        elif command == "status":
            monitor.status_report()
        elif command == "monitor":
            monitor.monitor_loop()
        else:
            print("Usage: stack-monitor.py [check|status|monitor]")
            print("  check   - Run a single check cycle")
            print("  status  - Show current status of all stacks")
            print("  monitor - Start continuous monitoring")
    else:
        print("Usage: stack-monitor.py [check|status|monitor]")

if __name__ == "__main__":
    main()
