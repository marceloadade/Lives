# Automating SQL Server at Scale with Ansible

This is the content of the session: Automating SQL Server at Scale with Ansible,
delivered on Sep 26, 2026 in the Toronto Data Saturday community event.

If you have never used Ansible, start at the top and read down. Every file in
this repo is meant to be readable without knowing Ansible first.

---

## What Ansible actually is

Three things, and that is genuinely all:

1. **An inventory** — a list of servers. That's `inventory.yml`.
2. **Variables** — settings for those servers. That's `group_vars/`.
3. **Playbooks** — a list of tasks to run. That's `playbooks/`.

You run a playbook from your laptop. Ansible connects to each server — WinRM
on Windows, SSH on Linux — runs what it needs to, and disconnects. **Nothing is
installed on the servers.** Both of those are already part of the operating
system. There is no agent, no service, no scheduler. That surprises people.

---

## Setup (once)

You need Python 3.12 or newer, because that's what Ansible requires now.

```bash
brew install python@3.12

python3.12 -m venv .venv
source .venv/bin/activate

# pywinrm is what lets Ansible talk to Windows. Without it every Windows
# task fails with "winrm or requests is not installed".
pip install ansible-core pywinrm

ansible-galaxy collection install -r requirements.yml
```

`requirements.yml` lists the extra module packages ("collections") these
playbooks use — the Windows ones and the SQL Server ones.

### The passwords

Every server is managed through one account, `ansiuser`, with one password:

| Server | `ansiuser` is | Created by |
|---|---|---|
| sqlwin01, sqlwin02 | a domain account, local admin on both | `../lab/win_ad/join-sqlservers.ps1` |
| sqllin01 | a local account, with passwordless sudo | `../lab/bootstrap-linux.sh` |

It is deliberately **not** `azureuseradmin`. That is the account Azure made for
you, the human, and it is what you fall back on when something is broken.
Automation gets its own account, so "what did Ansible do" and "what did I do"
stay separate questions — and so that revoking Ansible's access is one command
rather than a password change everybody notices.

The password lives encrypted in `group_vars/sqlservers/vault.yml` as
`vault_lab_ansiuser_password`, locked with a second password — the *vault*
password — that you choose.

That file holds a second secret too: `vault_lab_sa_password`, the SQL Server
`sa` password. Both install playbooks read it, so Windows and Linux end up
with the same one:

| Playbook | Where it goes |
|---|---|
| `2_install.yml` | `SAPWD` in the setup answer file, with `SECURITYMODE="SQL"` to turn mixed mode on |
| `install_linux.yml` | `MSSQL_SA_PASSWORD` for `mssql-conf setup` |

The file in this repo has placeholders, so do these two things once:

```bash
# 1. Pick your own vault password. The current one is "datasat".
ansible-vault rekey group_vars/sqlservers/vault.yml

# 2. Put the real password in, on the CHANGE-ME line. Opens your editor;
#    the file is re-encrypted when you save.
ansible-vault edit group_vars/sqlservers/vault.yml
```

### One more thing, on a Mac

```bash
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
```

Without it, Ansible dies with `A worker was found in a dead state` and macOS
writes a Python crash report. Nothing is wrong with your setup. Ansible splits
into worker processes to talk to several servers at once, and macOS refuses to
let one of those workers use a part of the system that was already loaded
before the split. This tells it to allow it.

You need this in every terminal.

Every command from here on that connects to a server needs the vault
password, so each one ends in `--ask-vault-pass`. Ansible stops and asks you
to type it. It is never saved anywhere, which is the point.

Check it all worked:

```bash
ansible --version
ansible-inventory --graph      # should print your server list

# These two actually connect, so they need the vault password.
ansible windows -m ansible.windows.win_ping --ask-vault-pass   # "pong" from both
ansible linux   -m ansible.builtin.ping    --ask-vault-pass
```

Two commands, not one, and the reason is worth knowing. `ansible.builtin.ping`
is a *Python* module — it runs Python on the far end. Windows has no Python, so
against a Windows server it fails with `The term '/usr/bin/python3' is not
recognized`. `win_ping` is the PowerShell equivalent.

Playbooks do not have this problem: each play names a group and uses the right
module for it, which is how `1_facts.yml` covers all three servers in one run.
Choosing the module yourself is only an ad-hoc thing.

Note that `ansible-inventory --graph` works with or without the vault password,
because it only reads the list of servers and never opens the encrypted file.
So it passing tells you the inventory is fine — not that your vault is.

Forget `--ask-vault-pass` and anything that connects stops with `Attempting to
decrypt but no vault secrets found`. Add the flag and run it again.

> **In every new terminal**: `source .venv/bin/activate`, and the `export`
> line above. The first two failures anyone has are a missing
> `ansible` command and a crashed worker, and both are just a forgotten line.

---

## The demos

Run these from this folder. Ansible picks up `ansible.cfg` automatically, so
the only flag you always need is `--ask-vault-pass`.

### 1. Prove there is no agent

```bash
ansible-playbook playbooks/1_facts.yml --ask-vault-pass
```

Connects to every server and reports what version of SQL Server is on it.
Read-only — it cannot change anything.

### 2. Install SQL Server 2025

```bash
ansible-playbook playbooks/2_install.yml --ask-vault-pass
```

Takes 6–12 minutes the first time. **Then run it again.** The second run does
nothing and reports `changed=0`, because there is nothing left to do.

That second run is the whole point of the demo. A copied PowerShell script
cannot do that.

### 3. Find and fix configuration drift ← *the main one*

```bash
# Show me what's wrong. Changes nothing.
ansible-playbook playbooks/3_baseline.yml --check --diff --ask-vault-pass

# Now fix it.
ansible-playbook playbooks/3_baseline.yml --diff --ask-vault-pass
```

Same file both times. `--check` means "pretend", `--diff` means "show me the
before and after". Together they are a free audit of your whole estate.

The settings being enforced are in `group_vars/all.yml`. That file is your
build standard, written down and reviewable.

### 4. Build an availability group

```bash
ansible-playbook playbooks/4_availability_group.yml --ask-vault-pass
```

### 5. Patch every server safely

```bash
ansible-playbook playbooks/5_patch.yml --ask-vault-pass
```

One server at a time, and it stops the moment one fails.

### 6. Install SSMS with no internet

```bash
ansible-playbook playbooks/6_ssms.yml --ask-vault-pass
```

SSMS 22 is installed by the Visual Studio Installer, which normally downloads
what it needs as it goes. A locked-down server can't do that, so you give it
an **offline layout** instead: a folder holding every file it would have
downloaded. You make the layout once, on a machine with internet:

```
vs_SSMS.exe --layout C:\media\SSMS\SSMS_Layout --lang en-US
```

Then copy the whole folder to `C:\media\SSMS\SSMS_Layout` on each server.
Making the layout is a human job; installing from it on every server is the
playbook's job. Like demo 2, run it twice — the second run does nothing.

Run the `vs_SSMS.exe` that sits **inside** the layout folder. A copy anywhere
else doesn't know the layout is there, and fails with `A product matching the
following parameters cannot be found`.

---

## Useful flags

```bash
# Try it without changing anything
ansible-playbook playbooks/3_baseline.yml --check --diff --ask-vault-pass

# Only one server
ansible-playbook playbooks/3_baseline.yml --limit sqlwin01 --ask-vault-pass

# See what's happening (add more v's for more detail)
ansible-playbook playbooks/3_baseline.yml -v --ask-vault-pass

# Check a playbook for mistakes without running it
ansible-playbook playbooks/3_baseline.yml --syntax-check --ask-vault-pass
```

`--limit` is the one to build a habit around. It is how you avoid running
something against 500 servers when you meant to test on one.

---

## Files

```
ansible.cfg           Settings, so you don't have to pass flags
inventory.yml         The list of servers
requirements.yml      Extra module packages to install

group_vars/
  all.yml             THE BUILD STANDARD — the important file
  windows.yml         How to connect to Windows
  linux.yml           How to connect to Linux
  sqlservers/
    vault.yml         The passwords, encrypted with Ansible Vault

playbooks/
  1_facts.yml                 read-only inventory of the estate
  2_install.yml               install SQL Server 2025
  3_baseline.yml              enforce the build standard
  4_availability_group.yml    cluster + availability group
  5_patch.yml                 rolling cumulative update
  6_ssms.yml                  SSMS 22, from an offline layout
  install_linux.yml           the Linux version of demo 2
  break_the_baseline.yml      rehearsal helper: breaks things on purpose
  undo_availability_group.yml rehearsal helper: undoes demo 4

docs/                 The session slides (PDF)

(The scripts that create the Azure VMs live in ../lab/ - separate on purpose,
since they are not part of the demo.)
```

---

## Things that will catch you out

These are worth knowing before you try this at work.

**On a Mac, Ansible crashes without `OBJC_DISABLE_INITIALIZE_FORK_SAFETY`.**
"A worker was found in a dead state", plus a crash report. It is macOS being
strict about what a forked process may touch, not a problem with Ansible, the
playbook or the servers. Set it and it goes away.

**Windows servers have no Python.** Ansible modules for Windows are written in
PowerShell instead. This is why the Windows modules are all named `win_*` and
most of the normal modules don't work on them.

**A local admin over WinRM is not an admin.** Log in over the network with a
local account and Windows quietly hands you a stripped-down token, so tasks
fail with "Access is denied" from an account you can see is an administrator.
`LocalAccountTokenFilterPolicy` in `../lab/bootstrap-windows.ps1` is what turns
that off. A domain account does not have the problem, which is the real reason
production uses Kerberos.

**`setup.exe` is not idempotent.** Neither is `mssql-conf setup` on Linux.
Ansible does not magically fix that. The "is it already installed?" check at
the top of `2_install.yml` is what makes it safe to re-run, and a human had to
write that check.

**`--check` is not a guarantee.** It works properly for the settings in
`3_baseline.yml`, because that module reads the current value before writing.
Not every module is that well behaved. Treat a clean `--check` as strong
evidence, not proof.

**Some modules don't exist.** Building a Windows failover cluster, creating a
mirroring endpoint, and installing a cumulative update all have no ready-made
module. You write those yourself — see `4_availability_group.yml`, where the
steps with and without modules are labelled.

**A few module options are not named what you'd guess.** Verified against
`lowlydba.sqlserver` 3.1.0:

| You'd expect | It's actually |
|---|---|
| a `maxdop` module | `sp_configure` with `max degree of parallelism` |
| `memory: max_memory` | `memory: max` |
| `traceflag: trace_flags: [3226]` | `trace_flag: 3226` plus `enabled: true` |

---

## SQL Server 2025 notes

- Released 18 November 2025. Engine version 17, compatibility level 170.
- The Linux repo is `mssql-server-2025`, not `mssql-server-preview`.
- SUSE is not supported from 2025 onward.
- **Standard edition went up to 32 cores and a 256 GB buffer pool.** If your
  memory settings were written for SQL Server 2022 Standard, they now give the
  server *less* than it could use. This one catches everybody.
