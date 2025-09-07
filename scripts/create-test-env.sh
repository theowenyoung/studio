#!/bin/bash
# 创建测试环境脚本

set -e

# 参数
TEST_ID="${1:-test-$(date +%s)}"
TEST_COMMIT="${2:-main}"
SERVER_IP="${3}"

if [ -z "$SERVER_IP" ]; then
  echo "Usage: $0 <test-id> <commit> <server-ip>"
  exit 1
fi

# 创建测试环境目录
TEST_DIR="inventory/testing/hosts-${TEST_ID}"
mkdir -p "$TEST_DIR"

# 生成 hosts 文件
cat >"$TEST_DIR/hosts.yml" <<EOF
---
all:
  children:
    testing:
      hosts:
        test-${TEST_ID}:
          ansible_host: ${SERVER_IP}
          ansible_user: root
          ansible_port: 22
          server_name: test-${TEST_ID}
          environment: testing
          test_id: "${TEST_ID}"
          test_commit: "${TEST_COMMIT}"
EOF

echo "Test environment created: ${TEST_ID}"
echo "Deploy with: ansible-playbook -i ${TEST_DIR}/hosts.yml playbooks/site.yml"

# 运行部署
read -p "Deploy now? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  ansible-playbook -i "${TEST_DIR}/hosts.yml" playbooks/site.yml
fi
