#!/bin/bash
# 销毁测试环境脚本

set -e

TEST_ID="${1}"

if [ -z "$TEST_ID" ]; then
  echo "Usage: $0 <test-id>"
  exit 1
fi

TEST_DIR="inventory/testing/hosts-${TEST_ID}"

if [ ! -f "$TEST_DIR/hosts.yml" ]; then
  echo "Test environment not found: ${TEST_ID}"
  exit 1
fi

# 运行销毁 playbook
ansible-playbook -i "${TEST_DIR}/hosts.yml" playbooks/destroy.yml

# 删除 inventory 文件
rm -rf "$TEST_DIR"

echo "Test environment destroyed: ${TEST_ID}"
