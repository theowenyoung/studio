#!/bin/bash
# =====================================
# 部署示例脚本
# =====================================

echo "使用方法："
echo "1. 设置 AWS 凭证："
echo "   export AWS_ACCESS_KEY_ID=your_access_key"
echo "   export AWS_SECRET_ACCESS_KEY=your_secret_key"
echo ""
echo "2. 运行部署命令："
echo "   ansible-playbook ansible/playbooks/deploy-node-app.yml \\"
echo "     --extra-vars app=node-demo \\"
echo "     --extra-vars aws_access_key_id=\$AWS_ACCESS_KEY_ID \\"
echo "     --extra-vars aws_secret_access_key=\$AWS_SECRET_ACCESS_KEY"
echo ""
echo "3. 或者直接在服务器上运行："
echo "   cd js-apps/node-demo"
echo "   export AWS_ACCESS_KEY_ID=your_access_key"
echo "   export AWS_SECRET_ACCESS_KEY=your_secret_key"
echo "   ./deploy.sh deploy"