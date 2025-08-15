
.PHONY: setup
setup: installtools installdev installansibledeps
# 安装 mise 管理的工具版本
.PHONY: installtools
installtools:
	mise install

.PHONY: installdev
installdev:
	pip install -r requirements-dev.txt

.PHONY: installansibledeps
installansibledeps:
	ansible-galaxy install -r ./ansible/requirements.yml --roles-path ~/.ansible/roles
	ansible-galaxy collection install -r ./ansible/requirements.yml

.PHONY: lint
lint:
	ansible-lint ansible/

.PHONY: bootstrapserver
bootstrapserver:
	ansible-playbook ansible/playbooks/bootstrap.yml -i ansible/inventory.ini --ask-pass

.PHONY: bootstrapserverwithoutpass
bootstrapserverwithoutpass:
	ansible-playbook ansible/playbooks/bootstrap.yml -i ansible/inventory.ini
