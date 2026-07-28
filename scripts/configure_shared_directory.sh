#!/usr/bin/env bash

configure_shared_directory() {
  local shared_dir=$1
  local sanitized_name
  local service_name
  local fix_script
  local watcher_script
  local service_file
  local timer_file
  local backup_file
  local file_count

  sanitized_name="$(basename "$shared_dir" | tr -c 'a-zA-Z0-9-' '-' | sed 's/^-*//;s/-*$//')"
  service_name="${sanitized_name:-shared}-perms"
  fix_script="/usr/local/bin/$FIX_SCRIPT_NAME"
  watcher_script="/usr/local/bin/${service_name}_watcher.sh"
  service_file="/etc/systemd/system/${service_name}.service"
  timer_file="/etc/systemd/system/${service_name}.timer"

  step "4/9 - Creating directory $shared_dir..."
  if [[ -d $shared_dir ]]; then
    warn "Directory $shared_dir already exists."
    warn 'Existing files will be preserved and permissions will be updated.'

    if getfacl "$shared_dir" &>/dev/null; then
      backup_file="/tmp/shared_dir_acl_backup_$(date +%Y%m%d_%H%M%S).txt"
      getfacl -R "$shared_dir" > "$backup_file" 2>/dev/null || true
      info "ACL backup saved to: $backup_file"
    fi
  elif ! mkdir -p "$shared_dir"; then
    error "Could not create directory $shared_dir."
    return 1
  else
    ok "Directory $shared_dir created."
  fi

  step '5/9 - Configuring owner and base permissions...'
  if ! chown root:"$SHARE_GROUP" "$shared_dir"; then
    error "Could not change owner of $shared_dir."
    return 1
  fi
  ok "Owner set to: root:$SHARE_GROUP"

  if ! chmod 2770 "$shared_dir"; then
    error "Could not set permissions on $shared_dir."
    return 1
  fi
  ok 'Base permissions set: 2770 (SGID + rwx owner/group, no sticky bit)'

  step "6/9 - Applying ACLs for full access for group $SHARE_GROUP..."
  setfacl -b "$shared_dir" 2>/dev/null || true
  if ! setfacl -R -m g:"$SHARE_GROUP":rwx "$shared_dir" 2>/dev/null; then
    warn 'No existing files to apply ACLs to, or there was a minor error.'
  fi
  if ! setfacl -d -R -m g:"$SHARE_GROUP":rwx "$shared_dir"; then
    error 'Could not apply default ACLs.'
    return 1
  fi
  ok 'ACLs applied successfully.'

  file_count=$(find "$shared_dir" -mindepth 1 2>/dev/null | wc -l)
  if [[ $file_count -gt 0 ]]; then
    info "Adjusting $file_count existing files/folders..."
    find "$shared_dir" ! -group "$SHARE_GROUP" -exec chown :"$SHARE_GROUP" {} + 2>/dev/null || true
    find "$shared_dir" -type f -exec chmod g+rwx {} + 2>/dev/null || true
    find "$shared_dir" -type d -exec chmod g+rwxs {} + 2>/dev/null || true
    ok 'Existing files adjusted.'
  fi

  step '7/9 - Creating permission-fix script...'
  {
    printf '%s\n' '#!/usr/bin/env bash'
    printf '%s\n' "# $FIX_SCRIPT_NAME"
    printf '%s\n' "# Repairs permissions for $shared_dir and accepts an explicit target from a watcher."
    printf '%s\n' "DEFAULT_SHARED_DIR=\"$shared_dir\""
    printf '%s\n' "DEFAULT_GROUP=\"$SHARE_GROUP\""
    printf '%s\n' 'SHARED_DIR="${1:-$DEFAULT_SHARED_DIR}"'
    printf '%s\n' 'GROUP="${2:-$DEFAULT_GROUP}"'
    printf '%s\n' 'find "$SHARED_DIR" ! -group "$GROUP" -exec chown :"$GROUP" {} + 2>/dev/null'
    printf '%s\n' 'find "$SHARED_DIR" -type f ! -perm -g=rwx -exec chmod g+rwx {} + 2>/dev/null'
    printf '%s\n' 'find "$SHARED_DIR" -type d ! -perm -g=rwxs -exec chmod g+rwxs {} + 2>/dev/null'
    printf '%s\n' 'setfacl -d -R -m g:"$GROUP":rwx "$SHARED_DIR" 2>/dev/null'
  } > "$fix_script"
  chmod +x "$fix_script"
  ok "Fix script created at $fix_script"
  "$fix_script" "$shared_dir" "$SHARE_GROUP"
  ok 'Permissions fixed on initial run.'

  step '8/9 - Creating real-time monitoring systemd service...'
  {
    printf '%s\n' '#!/usr/bin/env bash'
    printf '%s\n' "# ${service_name}_watcher.sh"
    printf '%s\n' "SHARED_DIR=\"$shared_dir\""
    printf '%s\n' "FIX_SCRIPT=\"$fix_script\""
    printf '%s\n' "GROUP=\"$SHARE_GROUP\""
    printf '%s\n' '"$FIX_SCRIPT" "$SHARED_DIR" "$GROUP"'
    printf '%s\n' 'while true; do'
    printf '%s\n' '  inotifywait -r -e create,modify,move,attrib --exclude ".git" "$SHARED_DIR" 2>/dev/null || true'
    printf '%s\n' '  sleep 0.1'
    printf '%s\n' '  "$FIX_SCRIPT" "$SHARED_DIR" "$GROUP"'
    printf '%s\n' 'done'
  } > "$watcher_script"
  chmod +x "$watcher_script"
  ok "Watcher script created at $watcher_script"

  {
    printf '%s\n' '[Unit]'
    printf '%s\n' "Description=Monitors $shared_dir and fixes permissions in real time"
    printf '%s\n' 'After=local-fs.target'
    printf '%s\n\n' '[Service]'
    printf '%s\n' 'Type=simple'
    printf '%s\n' "ExecStart=$watcher_script"
    printf '%s\n' 'Restart=always'
    printf '%s\n\n' 'RestartSec=5'
    printf '%s\n' '[Install]'
    printf '%s\n' 'WantedBy=multi-user.target'
  } > "$service_file"
  ok "Systemd service created: ${service_name}.service"

  {
    printf '%s\n' '[Unit]'
    printf '%s\n' "Description=Fixes permissions on $shared_dir every 30 seconds (backup)"
    printf '%s\n\n' '[Timer]'
    printf '%s\n' 'OnBootSec=10'
    printf '%s\n' 'OnUnitActiveSec=30s'
    printf '%s\n\n' 'AccuracySec=1s'
    printf '%s\n' '[Install]'
    printf '%s\n' 'WantedBy=timers.target'
  } > "$timer_file"
  ok "Systemd timer created: ${service_name}.timer"

  systemctl daemon-reload
  systemctl stop "${service_name}.service" 2>/dev/null || true
  systemctl stop "${service_name}.timer" 2>/dev/null || true
  if ! systemctl enable --now "${service_name}.service"; then
    error "Could not start service ${service_name}.service"
    error "Check the logs with: journalctl -u ${service_name}.service"
    return 1
  fi
  ok "Service ${service_name}.service enabled and started."
  if ! systemctl enable --now "${service_name}.timer"; then
    warn "Could not start timer ${service_name}.timer"
    warn 'The main service should be sufficient.'
  else
    ok "Timer ${service_name}.timer enabled and started."
  fi

  step '9/9 - Verifying final configuration...'
  printf '\n========================================\n'
  printf '%s\n' '       CONFIGURATION VERIFICATION'
  printf '%s\n' '========================================'
  printf '\n--- Service status ---\n'
  systemctl status "${service_name}.service" --no-pager -l || true
  printf '\n--- Timer status ---\n'
  systemctl status "${service_name}.timer" --no-pager -l || true
  printf '\n--- Directory permissions ---\n'
  ls -ld "$shared_dir"
  printf '\n--- Directory ACLs ---\n'
  getfacl "$shared_dir"
  printf '\n--- Current members of group %s ---\n' "$SHARE_GROUP"
  getent group "$SHARE_GROUP"
  printf '\n========================================\n'
  printf '%s\n' '              FINAL SUMMARY'
  printf '%s\n' '========================================'
  printf '\n  Directory:            %s\n' "$shared_dir"
  printf '  Group:                %s\n' "$SHARE_GROUP"
  printf '%s\n' '  Base permissions:     2770 (SGID, no sticky bit)'
  printf '%s\n' '  Group access:         Read, write, execute FULL'
  printf '%s\n\n' '  Other access:         NONE'
  printf '%s\n' '  Active monitoring:'
  printf '    - inotify (real-time):  %s.service\n' "$service_name"
  printf '    - Timer (every 30s):    %s.timer\n' "$service_name"
  printf '\n%s\n' "  Any member of '$SHARE_GROUP' can:"
  printf '%s\n' '      - Create files and folders'
  printf '%s\n' '      - Read other group members'\'' files'
  printf '%s\n' '      - Modify other group members'\'' files'
  printf '%s\n' '      - Delete other group members'\'' files'
  printf '%s\n\n' '      - Execute other group members'\'' scripts'
  printf '%s\n' '  New files automatically inherit:'
  printf '      - Group: %s\n' "$SHARE_GROUP"
  printf '%s\n' '      - Permissions: g+rwx (fixed in real time)'
  printf '%s\n' '========================================'
  printf '\nTo add users to group %s:\n' "$SHARE_GROUP"
  printf '  sudo usermod -aG %s <username>\n' "$SHARE_GROUP"
  printf '%s\n' 'The added user'\''s current group membership is cached until they'
  printf '%s\n' 'start a new session. Either option works:'
  printf '%s\n' '  - Log out and log back in, or'
  printf '%s\n' "  - Run 'newgrp $SHARE_GROUP' in their current terminal (only affects"
  printf '%s\n' '    that terminal, not the whole desktop session).'
  printf '\n%s\n' 'Useful commands:'
  printf '  sudo systemctl status %s.service   # Check status\n' "$service_name"
  printf '  sudo systemctl restart %s.service  # Restart\n' "$service_name"
  printf '  sudo journalctl -u %s.service -f   # View logs\n\n' "$service_name"
  ok 'Configuration completed successfully.'
}
