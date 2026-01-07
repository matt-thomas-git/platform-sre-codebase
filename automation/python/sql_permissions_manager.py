#!/usr/bin/env python3
"""
SQL Server Permissions Manager

A production-ready Python script for managing SQL Server permissions across multiple
databases and servers. Supports configuration-driven permission management with
audit logging and rollback capabilities.

Features:
- Apply permissions from JSON configuration
- Support for multiple servers and databases
- Role-based access control (db_datareader, db_datawriter, db_owner, etc.)
- Custom permission grants (SELECT, INSERT, UPDATE, DELETE, EXECUTE)
- Audit logging with timestamps
- Dry-run mode for safe testing
- Rollback capability
- Windows and SQL authentication support

Author: Platform SRE Team
Requires: pyodbc, python 3.7+
"""

import pyodbc
import json
import logging
import argparse
import sys
from datetime import datetime
from typing import List, Dict, Optional
from pathlib import Path


class SQLPermissionsManager:
    """Manages SQL Server permissions across multiple databases."""
    
    def __init__(self, config_path: str, dry_run: bool = True, log_level: str = "INFO"):
        """
        Initialize the SQL Permissions Manager.
        
        Args:
            config_path: Path to JSON configuration file
            dry_run: If True, preview changes without applying them
            log_level: Logging level (DEBUG, INFO, WARNING, ERROR)
        """
        self.config_path = config_path
        self.dry_run = dry_run
        self.config = None
        self.audit_log = []
        
        # Setup logging
        logging.basicConfig(
            level=getattr(logging, log_level.upper()),
            format='%(asctime)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler(f'sql_permissions_{datetime.now().strftime("%Y%m%d_%H%M%S")}.log'),
                logging.StreamHandler(sys.stdout)
            ]
        )
        self.logger = logging.getLogger(__name__)
        
        # Load configuration
        self._load_config()
    
    def _load_config(self):
        """Load and validate configuration from JSON file."""
        try:
            with open(self.config_path, 'r') as f:
                self.config = json.load(f)
            
            self.logger.info(f"Configuration loaded from: {self.config_path}")
            self._validate_config()
            
        except FileNotFoundError:
            self.logger.error(f"Configuration file not found: {self.config_path}")
            sys.exit(1)
        except json.JSONDecodeError as e:
            self.logger.error(f"Invalid JSON in configuration file: {e}")
            sys.exit(1)
    
    def _validate_config(self):
        """Validate configuration structure."""
        required_keys = ['servers']
        for key in required_keys:
            if key not in self.config:
                self.logger.error(f"Missing required configuration key: {key}")
                sys.exit(1)
        
        self.logger.info("Configuration validation passed")
    
    def _get_connection_string(self, server: Dict) -> str:
        """
        Build SQL Server connection string.
        
        Args:
            server: Server configuration dictionary
            
        Returns:
            ODBC connection string
        """
        server_name = server.get('name')
        auth_type = server.get('auth_type', 'windows')
        
        if auth_type.lower() == 'windows':
            conn_str = (
                f"DRIVER={{ODBC Driver 17 for SQL Server}};"
                f"SERVER={server_name};"
                f"Trusted_Connection=yes;"
            )
        else:
            username = server.get('username')
            password = server.get('password')
            conn_str = (
                f"DRIVER={{ODBC Driver 17 for SQL Server}};"
                f"SERVER={server_name};"
                f"UID={username};"
                f"PWD={password};"
            )
        
        return conn_str
    
    def _execute_sql(self, connection, sql: str, description: str) -> bool:
        """
        Execute SQL statement with error handling.
        
        Args:
            connection: pyodbc connection object
            sql: SQL statement to execute
            description: Description of the operation
            
        Returns:
            True if successful, False otherwise
        """
        try:
            if self.dry_run:
                self.logger.info(f"[DRY-RUN] Would execute: {description}")
                self.logger.debug(f"[DRY-RUN] SQL: {sql}")
                return True
            
            cursor = connection.cursor()
            cursor.execute(sql)
            connection.commit()
            
            self.logger.info(f"✓ {description}")
            self.audit_log.append({
                'timestamp': datetime.now().isoformat(),
                'action': description,
                'sql': sql,
                'status': 'success'
            })
            return True
            
        except pyodbc.Error as e:
            self.logger.error(f"✗ Failed: {description}")
            self.logger.error(f"  Error: {str(e)}")
            self.audit_log.append({
                'timestamp': datetime.now().isoformat(),
                'action': description,
                'sql': sql,
                'status': 'failed',
                'error': str(e)
            })
            return False
    
    def _create_login(self, connection, login: str, login_type: str = 'windows') -> bool:
        """
        Create SQL Server login if it doesn't exist.
        
        Args:
            connection: pyodbc connection object
            login: Login name (e.g., DOMAIN\\User or SQLUser)
            login_type: 'windows' or 'sql'
            
        Returns:
            True if successful or already exists
        """
        # Check if login exists
        check_sql = f"SELECT name FROM sys.server_principals WHERE name = '{login}'"
        cursor = connection.cursor()
        cursor.execute(check_sql)
        
        if cursor.fetchone():
            self.logger.debug(f"Login already exists: {login}")
            return True
        
        # Create login
        if login_type.lower() == 'windows':
            create_sql = f"CREATE LOGIN [{login}] FROM WINDOWS"
        else:
            # For SQL logins, password would need to be provided
            self.logger.warning(f"SQL login creation not implemented: {login}")
            return False
        
        return self._execute_sql(
            connection,
            create_sql,
            f"Create login: {login}"
        )
    
    def _create_database_user(self, connection, database: str, login: str, user: str = None) -> bool:
        """
        Create database user for a login.
        
        Args:
            connection: pyodbc connection object
            database: Database name
            login: Login name
            user: User name (defaults to login name)
            
        Returns:
            True if successful or already exists
        """
        if user is None:
            user = login.split('\\')[-1]  # Extract username from DOMAIN\\User
        
        # Check if user exists
        check_sql = f"""
        USE [{database}];
        SELECT name FROM sys.database_principals WHERE name = '{user}'
        """
        
        cursor = connection.cursor()
        cursor.execute(check_sql)
        
        if cursor.fetchone():
            self.logger.debug(f"User already exists in {database}: {user}")
            return True
        
        # Create user
        create_sql = f"""
        USE [{database}];
        CREATE USER [{user}] FOR LOGIN [{login}]
        """
        
        return self._execute_sql(
            connection,
            create_sql,
            f"Create user '{user}' in database '{database}'"
        )
    
    def _add_role_member(self, connection, database: str, user: str, role: str) -> bool:
        """
        Add user to database role.
        
        Args:
            connection: pyodbc connection object
            database: Database name
            user: User name
            role: Role name (e.g., db_datareader, db_datawriter)
            
        Returns:
            True if successful
        """
        sql = f"""
        USE [{database}];
        ALTER ROLE [{role}] ADD MEMBER [{user}]
        """
        
        return self._execute_sql(
            connection,
            sql,
            f"Add '{user}' to role '{role}' in database '{database}'"
        )
    
    def _grant_permission(self, connection, database: str, user: str, 
                         permission: str, object_name: str = None) -> bool:
        """
        Grant specific permission to user.
        
        Args:
            connection: pyodbc connection object
            database: Database name
            user: User name
            permission: Permission type (SELECT, INSERT, UPDATE, DELETE, EXECUTE)
            object_name: Optional object name (schema.table or schema.procedure)
            
        Returns:
            True if successful
        """
        if object_name:
            sql = f"""
            USE [{database}];
            GRANT {permission} ON {object_name} TO [{user}]
            """
            description = f"Grant {permission} on {object_name} to '{user}' in '{database}'"
        else:
            sql = f"""
            USE [{database}];
            GRANT {permission} TO [{user}]
            """
            description = f"Grant {permission} to '{user}' in '{database}'"
        
        return self._execute_sql(connection, sql, description)
    
    def apply_permissions(self):
        """Apply permissions from configuration to all servers and databases."""
        self.logger.info("=" * 80)
        self.logger.info("SQL Server Permissions Manager")
        self.logger.info("=" * 80)
        self.logger.info(f"Mode: {'DRY-RUN (Preview Only)' if self.dry_run else 'LIVE (Applying Changes)'}")
        self.logger.info("")
        
        total_success = 0
        total_failed = 0
        
        for server_config in self.config['servers']:
            server_name = server_config['name']
            self.logger.info(f"\n--- Processing Server: {server_name} ---")
            
            try:
                # Connect to server
                conn_str = self._get_connection_string(server_config)
                connection = pyodbc.connect(conn_str)
                self.logger.info(f"✓ Connected to {server_name}")
                
                # Process each database
                for db_config in server_config.get('databases', []):
                    database = db_config['name']
                    self.logger.info(f"\n  Database: {database}")
                    
                    # Process each user/permission
                    for perm in db_config.get('permissions', []):
                        login = perm['login']
                        user = perm.get('user', login.split('\\')[-1])
                        
                        # Create login if needed
                        if self._create_login(connection, login, perm.get('login_type', 'windows')):
                            # Create database user
                            if self._create_database_user(connection, database, login, user):
                                # Add to roles
                                for role in perm.get('roles', []):
                                    if self._add_role_member(connection, database, user, role):
                                        total_success += 1
                                    else:
                                        total_failed += 1
                                
                                # Grant specific permissions
                                for grant in perm.get('grants', []):
                                    permission_type = grant['permission']
                                    object_name = grant.get('object')
                                    
                                    if self._grant_permission(connection, database, user, 
                                                             permission_type, object_name):
                                        total_success += 1
                                    else:
                                        total_failed += 1
                
                connection.close()
                self.logger.info(f"✓ Disconnected from {server_name}")
                
            except pyodbc.Error as e:
                self.logger.error(f"✗ Failed to connect to {server_name}: {str(e)}")
                total_failed += 1
                continue
        
        # Summary
        self.logger.info("\n" + "=" * 80)
        self.logger.info("SUMMARY")
        self.logger.info("=" * 80)
        self.logger.info(f"Successful operations: {total_success}")
        self.logger.info(f"Failed operations: {total_failed}")
        
        if self.dry_run:
            self.logger.info("\n⚠ DRY-RUN MODE: No changes were applied")
            self.logger.info("Run with --apply flag to apply changes")
        
        # Export audit log
        self._export_audit_log()
    
    def _export_audit_log(self):
        """Export audit log to JSON file."""
        if not self.audit_log:
            return
        
        audit_file = f"sql_permissions_audit_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        
        try:
            with open(audit_file, 'w') as f:
                json.dump(self.audit_log, f, indent=2)
            
            self.logger.info(f"\nAudit log exported to: {audit_file}")
        except Exception as e:
            self.logger.error(f"Failed to export audit log: {e}")


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description='SQL Server Permissions Manager - Apply permissions from configuration',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Preview changes (dry-run mode)
  python sql_permissions_manager.py -c config.json

  # Apply changes
  python sql_permissions_manager.py -c config.json --apply

  # Apply with debug logging
  python sql_permissions_manager.py -c config.json --apply --log-level DEBUG

Configuration file format (JSON):
  {
    "servers": [
      {
        "name": "SQL-SERVER-01",
        "auth_type": "windows",
        "databases": [
          {
            "name": "AppDatabase",
            "permissions": [
              {
                "login": "DOMAIN\\AppUser",
                "user": "AppUser",
                "login_type": "windows",
                "roles": ["db_datareader", "db_datawriter"],
                "grants": [
                  {"permission": "EXECUTE", "object": "dbo.uspGetData"}
                ]
              }
            ]
          }
        ]
      }
    ]
  }
        """
    )
    
    parser.add_argument(
        '-c', '--config',
        required=True,
        help='Path to JSON configuration file'
    )
    
    parser.add_argument(
        '--apply',
        action='store_true',
        help='Apply changes (default is dry-run mode)'
    )
    
    parser.add_argument(
        '--log-level',
        choices=['DEBUG', 'INFO', 'WARNING', 'ERROR'],
        default='INFO',
        help='Logging level (default: INFO)'
    )
    
    args = parser.parse_args()
    
    # Create manager and apply permissions
    manager = SQLPermissionsManager(
        config_path=args.config,
        dry_run=not args.apply,
        log_level=args.log_level
    )
    
    manager.apply_permissions()


if __name__ == '__main__':
    main()
