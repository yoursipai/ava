# AVA-AI Makefile to repeatably set up machines.
SHELL=/bin/bash

#REPO=https://github.com/hkjarral/Asterisk-AI-Voice-Agent.git
GITREPO=git@github.com:hkjarral/AVA-AI-Voice-Agent-for-Asterisk.git
GITBRANCH=main
AIDESTDIR=/usr/local/ai/$(notdir $(basename $(GITREPO)))
DOTENV=$(AIDESTDIR)/.env

# Default real name and email for ~/.gitconfig
DEFREALNAME=Rob Thomas
DEFEMAIL=xrobau@gmail.com
# This is the system username that owns the commit in git metadata
DEFUSERNAME=avaai

# These are the usernames that should be added to /root/.ssh/authorized_keys if needed
# This is processed in includes/Makefile.sshkeys
GITHUBKEYS=xrobau hkjarral

ANSBIN=/usr/bin/ansible-playbook
# Which roles and collections should be installed? Use dots for roles, slashes for collections
ROLES=gantsign.golang geerlingguy.php-versions jhu-sheridan-libraries.postfix-smarthost geerlingguy.nodejs
COLLECTIONS=community/general ansible/posix community/docker community/mysql

# Required bins and packages - if any bins are missing, it installs all packages
BINS=$(ANSBIN) /usr/bin/vim /usr/bin/ping /usr/bin/netstat /usr/bin/wget /usr/bin/unzip /usr/bin/uuid /usr/bin/bc
PKGS=ansible vim iputils-ping net-tools wget unzip uuid bc

ANSIBLE_HOST_KEY_CHECKING=False
export ANSIBLE_HOST_KEY_CHECKING

# This directory
ANSDIR=$(shell pwd)

# These need to be defined early, as includes are non-deterministic
GITCONFIG=$(HOME)/.gitconfig
GROUPVARS=$(ANSDIR)/group_vars

# This is where local config files are kept
CONFDIR=$(ANSDIR)/config

# This is first so that `make` by itself always runs `make setup`
.PHONY: setup
setup: $(BINS) $(GITCONFIG) $(GROUPVARS)/all/cloudflare.yaml ansible-packages /etc/rc.local $(VIMFIXED) /.rootvolok
# /.rootvolok is in includes/Makefile.volumes

AVERS=1.0
UAGENT=AVA-Endpoint-v$(AVERS)

# If there's a NVidia/GeForce/Quadro Card, use it.
NVIDIAENV=$(shell lspci | egrep -q '\[(GeForce|Quadr)' && echo '-e nvidiagpu=true')
ANSENV=-e dotenv=$(DOTENV) -e uagent=$(UAGENT) $(NVIDIAENV)

include $(wildcard includes/Makefile.*)

.PHONY: bins
bins $(BINS):
	apt-get -y install $(PKGS)

.PHONY: me
me: setup /etc/ansible.hostname
	@MYIPS=$$(ip -o addr | egrep -v '(\ lo|\ docker)' | awk '/inet / { print $$4 }' | cut -d/ -f1 | paste -sd ','); \
		echo ansible-playbook main.yml $(ANSENV) -l $$MYIPS; \
		ansible-playbook main.yml $(ANSENV) -l $$MYIPS

.PHONY: base
base /etc/hosts: /etc/ansible.hostname | setup $(ASTYAML) $(PEERSYAML)
	$(ANSBIN) basesystem.yml -e hostname=$(shell cat /etc/ansible.hostname) $(ANSENV)

.PHONY: fhostname
fhostname /etc/ansible.hostname:
	@C=$(shell hostname); echo "Current hostname '$$C'"; read -e -p "Set hostname (blank to not change): " h; \
		if [ "$$h" ]; then \
			echo $$h > /etc/ansible.hostname; \
		else \
			if [ ! -s /etc/ansible.hostname ]; then \
				hostname > /etc/ansible.hostname; \
			fi; \
		fi

.PHONY: dev
dev:
	ansible-playbook -i localhost, development.yml -e devmachine=true $(ANSENV)

# This checks that the machine has hostkeys and a machine-id. Mainly
# used when a VM is broken or has been sysprep'ed
/etc/rc.local: scripts/rc.local
	cp $< $@ && chmod 755 $<

