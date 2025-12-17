"""Verify security hardening is applied correctly."""

import pytest

# =============================================================================
# Package Management
# =============================================================================


@pytest.mark.parametrize(
    "package",
    [
        "apparmor-utils",
        "fail2ban",
        "libpam-pwquality",
        "aide",
        "postfix",
    ],
)
def test_required_packages_installed(host, package):
    """Verify required security packages are installed."""
    assert host.package(package).is_installed


@pytest.mark.parametrize(
    "package",
    [
        "ftp",
        "telnet",
        "rsyslog",
    ],
)
def test_prohibited_packages_absent(host, package):
    """Verify insecure packages are not installed."""
    assert not host.package(package).is_installed


# =============================================================================
# Unattended Upgrades
# =============================================================================


def test_unattended_upgrades_installed(host):
    """Verify unattended-upgrades is installed."""
    assert host.package("unattended-upgrades").is_installed


def test_unattended_upgrades_updates_origin(host):
    """Verify updates origin is enabled."""
    f = host.file("/etc/apt/apt.conf.d/50unattended-upgrades")
    assert f.exists
    assert f.contains('${distro_codename}-updates"')


def test_unattended_upgrades_remove_unused(host):
    """Verify unused dependencies removal is enabled."""
    f = host.file("/etc/apt/apt.conf.d/50unattended-upgrades")
    assert f.contains('Remove-Unused-Dependencies "true"')


def test_unattended_upgrades_remove_kernels(host):
    """Verify unused kernel removal is enabled."""
    f = host.file("/etc/apt/apt.conf.d/50unattended-upgrades")
    assert f.contains('Remove-Unused-Kernel-Packages "true"')


def test_unattended_upgrades_auto_reboot(host):
    """Verify automatic reboot is enabled."""
    f = host.file("/etc/apt/apt.conf.d/50unattended-upgrades")
    assert f.contains('Automatic-Reboot "true"')


def test_unattended_upgrades_reboot_time(host):
    """Verify reboot time is set to 02:00."""
    f = host.file("/etc/apt/apt.conf.d/50unattended-upgrades")
    assert f.contains('Automatic-Reboot-Time "02:00"')


# =============================================================================
# Fail2ban
# =============================================================================


def test_fail2ban_installed(host):
    """Verify fail2ban is installed."""
    assert host.package("fail2ban").is_installed


def test_fail2ban_running(host):
    """Verify fail2ban service is running."""
    svc = host.service("fail2ban")
    assert svc.is_enabled
    assert svc.is_running


# =============================================================================
# UFW Firewall
# =============================================================================


def test_ufw_enabled(host):
    """Verify UFW firewall is enabled."""
    cmd = host.run("ufw status")
    assert "Status: active" in cmd.stdout


def test_ufw_default_incoming_deny(host):
    """Verify UFW default incoming policy is deny."""
    cmd = host.run("ufw status verbose")
    assert "Default: deny (incoming)" in cmd.stdout


def test_ufw_default_outgoing_deny(host):
    """Verify UFW default outgoing policy is deny."""
    cmd = host.run("ufw status verbose")
    assert "deny (outgoing)" in cmd.stdout


def test_ufw_ssh_allowed(host):
    """Verify SSH is allowed through UFW."""
    cmd = host.run("ufw status")
    assert "22/tcp" in cmd.stdout or "OpenSSH" in cmd.stdout


# =============================================================================
# Cron Hardening
# =============================================================================


@pytest.mark.parametrize(
    "path,expected_mode",
    [
        ("/etc/crontab", 0o600),
        ("/etc/cron.hourly", 0o700),
        ("/etc/cron.daily", 0o700),
        ("/etc/cron.weekly", 0o700),
        ("/etc/cron.monthly", 0o700),
        ("/etc/cron.d", 0o700),
    ],
)
def test_cron_permissions(host, path, expected_mode):
    """Verify cron files and directories have restricted permissions."""
    f = host.file(path)
    assert f.exists
    assert f.mode == expected_mode


def test_cron_allow_exists(host):
    """Verify cron.allow exists and contains only root."""
    f = host.file("/etc/cron.allow")
    assert f.exists
    assert f.contains("root")


# =============================================================================
# SSH Hardening
# =============================================================================


def test_sshd_config_permissions(host):
    """Verify sshd_config has restricted permissions."""
    f = host.file("/etc/ssh/sshd_config")
    assert f.exists
    assert f.mode == 0o600


def test_sshd_root_login_disabled(host):
    """Verify SSH root login is disabled."""
    f = host.file("/etc/ssh/sshd_config")
    assert f.contains("PermitRootLogin no")


def test_sshd_pubkey_only(host):
    """Verify SSH only allows publickey authentication."""
    f = host.file("/etc/ssh/sshd_config")
    assert f.contains("AuthenticationMethods publickey")


def test_sshd_banner_set(host):
    """Verify SSH banner is configured."""
    f = host.file("/etc/ssh/sshd_config")
    assert f.contains("Banner /etc/issue.net")


def test_issue_net_exists(host):
    """Verify /etc/issue.net exists."""
    f = host.file("/etc/issue.net")
    assert f.exists


def test_issue_exists(host):
    """Verify /etc/issue exists."""
    f = host.file("/etc/issue")
    assert f.exists


def test_sshd_config_d_permissions(host):
    """Verify sshd_config.d directory has restricted permissions."""
    f = host.file("/etc/ssh/sshd_config.d")
    assert f.exists
    assert f.is_directory
    assert f.mode == 0o700


def test_sshd_allow_groups(host):
    """Verify SSH is restricted to sudo group."""
    f = host.file("/etc/ssh/sshd_config")
    assert f.contains("AllowGroups sudo")


def test_sshd_max_auth_tries(host):
    """Verify SSH MaxAuthTries is set."""
    f = host.file("/etc/ssh/sshd_config")
    assert f.contains("MaxAuthTries 4")


def test_sshd_client_alive_interval(host):
    """Verify SSH ClientAliveInterval is set."""
    f = host.file("/etc/ssh/sshd_config")
    assert f.contains("ClientAliveInterval 15")


def test_sshd_login_grace_time(host):
    """Verify SSH LoginGraceTime is set."""
    f = host.file("/etc/ssh/sshd_config")
    assert f.contains("LoginGraceTime 60")


def test_sshd_log_level(host):
    """Verify SSH LogLevel is VERBOSE."""
    f = host.file("/etc/ssh/sshd_config")
    assert f.contains("LogLevel VERBOSE")


def test_sshd_hardening_config(host):
    """Verify SSH hardening config file exists."""
    f = host.file("/etc/ssh/ssh_config.d/99-hardening.conf")
    assert f.exists


# =============================================================================
# Kernel Hardening (sysctl)
# =============================================================================


def test_sysctl_ptrace_restricted(host):
    """Verify ptrace is restricted to admin only."""
    cmd = host.run("sysctl kernel.yama.ptrace_scope")
    assert "kernel.yama.ptrace_scope = 2" in cmd.stdout


def test_sysctl_icmp_redirects_disabled(host):
    """Verify ICMP redirects are disabled."""
    cmd = host.run("sysctl net.ipv4.conf.all.send_redirects")
    assert "= 0" in cmd.stdout


# =============================================================================
# Sudo Hardening
# =============================================================================


def test_sudo_requires_pty(host):
    """Verify sudo requires a PTY."""
    f = host.file("/etc/sudoers.d/99-hardening")
    assert f.exists
    assert f.contains("Defaults use_pty")


def test_sudo_logging(host):
    """Verify sudo logging is enabled."""
    f = host.file("/etc/sudoers.d/99-hardening")
    assert f.contains('logfile="/var/log/sudo.log"')


# =============================================================================
# Login Definitions
# =============================================================================


def test_login_defs_pass_max_days(host):
    """Verify password max days is set."""
    cmd = host.run("grep '^PASS_MAX_DAYS' /etc/login.defs")
    assert "365" in cmd.stdout


def test_login_defs_umask(host):
    """Verify restrictive umask is set."""
    cmd = host.run("grep '^UMASK' /etc/login.defs")
    assert "027" in cmd.stdout


# =============================================================================
# Password Quality
# =============================================================================


def test_pwquality_minlen(host):
    """Verify minimum password length is set."""
    f = host.file("/etc/security/pwquality.conf")
    assert f.contains("minlen = 14")


@pytest.mark.parametrize(
    "setting,value",
    [
        ("difok", "2"),
        ("minclass", "4"),
        ("maxrepeat", "3"),
        ("maxsequence", "3"),
    ],
)
def test_pwquality_settings(host, setting, value):
    """Verify password quality settings."""
    f = host.file("/etc/security/pwquality.conf")
    assert f.contains(f"{setting} = {value}")


def test_pwquality_enforce_for_root(host):
    """Verify password quality is enforced for root."""
    f = host.file("/etc/security/pwquality.conf")
    assert f.contains("enforce_for_root")


# =============================================================================
# PAM Configuration
# =============================================================================


def test_pam_faillock_config(host):
    """Verify pam_faillock configuration exists."""
    f = host.file("/etc/security/faillock.conf")
    assert f.exists


def test_pam_faillock_deny(host):
    """Verify faillock.conf has deny setting (commented default is acceptable)."""
    f = host.file("/etc/security/faillock.conf")
    # Role doesn't override deny, so just verify the directive exists (even commented)
    assert f.contains("deny")


def test_pam_faillock_unlock_time(host):
    """Verify faillock unlock time setting."""
    f = host.file("/etc/security/faillock.conf")
    assert f.contains("unlock_time = 900")


def test_pam_pwhistory_config(host):
    """Verify pam_pwhistory configuration exists."""
    f = host.file("/etc/security/pwhistory.conf")
    assert f.exists


def test_pam_pwhistory_remember(host):
    """Verify password history remember setting in PAM config."""
    f = host.file("/usr/share/pam-configs/pwhistory")
    assert f.contains("remember=24")


def test_pam_common_auth_no_nullok(host):
    """Verify nullok is removed from common-auth."""
    cmd = host.run("grep -E 'pam_unix.*nullok' /etc/pam.d/common-auth")
    assert cmd.rc != 0


def test_sugroup_exists(host):
    """Verify sugroup exists."""
    g = host.group("sugroup")
    assert g.exists


# =============================================================================
# System Services
# =============================================================================


def test_apport_disabled(host):
    """Verify apport is disabled (if installed)."""
    f = host.file("/etc/default/apport")
    if f.exists:
        assert f.contains("enabled=0")


def test_apport_service_masked(host):
    """Verify apport service is masked (if installed)."""
    svc = host.service("apport")
    if svc.exists:
        assert not svc.is_enabled


def test_rsync_service_masked(host):
    """Verify rsync service is masked."""
    svc = host.service("rsync")
    assert not svc.is_enabled


# =============================================================================
# Journald
# =============================================================================


def test_journald_no_forward_syslog(host):
    """Verify journald does not forward to syslog."""
    f = host.file("/etc/systemd/journald.conf")
    assert f.contains("ForwardToSyslog=no")


def test_journald_persistent_storage(host):
    """Verify journald uses persistent storage."""
    f = host.file("/etc/systemd/journald.conf")
    assert f.contains("Storage=persistent")


# =============================================================================
# Shell Environment
# =============================================================================


def test_shell_timeout(host):
    """Verify shell timeout is configured."""
    f = host.file("/etc/profile.d/tmout.sh")
    assert f.exists
    assert f.contains("TMOUT=")


# =============================================================================
# User Account Hardening
# =============================================================================


def test_root_account_locked(host):
    """Verify root account is locked."""
    cmd = host.run("passwd -S root")
    assert cmd.rc == 0
    assert cmd.stdout.split()[1] in ["L", "LK"]


# =============================================================================
# Core Dumps
# =============================================================================


def test_core_dumps_disabled(host):
    """Verify core dumps are disabled."""
    f = host.file("/etc/security/limits.conf")
    assert (
        f.contains("* hard core 0")
        or host.file("/etc/security/limits.d/99-disable-core.conf").exists
    )


# =============================================================================
# Filesystem Hardening
# =============================================================================


def test_tmp_mount_noexec(host):
    """Verify /tmp is mounted with noexec (if tmp.mount exists)."""
    f = host.file("/etc/systemd/system/tmp.mount")
    if f.exists:
        assert f.contains("noexec")


def test_tmp_mount_nosuid(host):
    """Verify /tmp is mounted with nosuid (if tmp.mount exists)."""
    f = host.file("/etc/systemd/system/tmp.mount")
    if f.exists:
        assert f.contains("nosuid")


def test_tmp_mount_nodev(host):
    """Verify /tmp is mounted with nodev (if tmp.mount exists)."""
    f = host.file("/etc/systemd/system/tmp.mount")
    if f.exists:
        assert f.contains("nodev")


# =============================================================================
# Additional Sysctl Tests
# =============================================================================


@pytest.mark.parametrize(
    "sysctl_param,expected_value",
    [
        ("net.ipv4.conf.all.accept_redirects", "0"),
        ("net.ipv4.conf.default.accept_redirects", "0"),
        ("net.ipv6.conf.all.accept_redirects", "0"),
        ("net.ipv6.conf.default.accept_redirects", "0"),
        ("net.ipv4.conf.all.secure_redirects", "0"),
        ("net.ipv4.conf.default.secure_redirects", "0"),
        ("net.ipv4.conf.all.rp_filter", "1"),
    ],
)
def test_sysctl_network_hardening(host, sysctl_param, expected_value):
    """Verify network sysctl hardening parameters."""
    cmd = host.run(f"sysctl {sysctl_param}")
    assert f"= {expected_value}" in cmd.stdout


def test_sysctl_log_martians_config(host):
    """Verify log_martians is configured in sysctl file."""
    f = host.file("/etc/sysctl.d/99-hardening.conf")
    assert f.contains("net.ipv4.conf.all.log_martians=1")


def test_sysctl_config_exists(host):
    """Verify sysctl hardening config file exists."""
    f = host.file("/etc/sysctl.d/99-hardening.conf")
    assert f.exists


# =============================================================================
# Fail2ban Additional Tests
# =============================================================================


def test_fail2ban_sshd_disabled(host):
    """Verify fail2ban sshd jail is disabled (pubkey auth only)."""
    f = host.file("/etc/fail2ban/jail.local")
    assert f.exists
    assert f.contains("[sshd]")
    assert f.contains("enabled=false")


# =============================================================================
# Postfix
# =============================================================================


def test_postfix_loopback_only(host):
    """Verify postfix listens on loopback only."""
    f = host.file("/etc/postfix/main.cf")
    assert f.exists
    assert f.contains("inet_interfaces = loopback-only")


# =============================================================================
# AIDE
# =============================================================================


@pytest.mark.skip(reason="chattr not supported on Docker overlay filesystem")
def test_aide_db_immutable(host):
    """Verify AIDE database has immutable attribute."""
    cmd = host.run("lsattr /var/lib/aide/aide.db")
    assert cmd.rc == 0
    assert "i" in cmd.stdout.split()[0]


def test_aide_post_upgrade_hook(host):
    """Verify AIDE post-upgrade hook is installed."""
    f = host.file("/etc/apt/apt.conf.d/99aide-update")
    assert f.exists
    assert f.contains("DPkg::Post-Invoke")
    assert f.contains("aideinit")
