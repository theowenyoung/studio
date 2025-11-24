# Mount Playbook 鲁棒性改进

## 问题背景

### 发现的问题

在 preview 服务器初始化时，发现了两个问题：

1. **磁盘已挂载到非标准位置**
   - `/dev/sdb` 已挂载到 `/mnt/HC_Volume_104039904`
   - mount.yml 只查找"未挂载"的磁盘
   - 找不到合适的磁盘，任务失败

2. **失败后继续执行**
   - mount.yml 失败后，后续的 setup-docker.yml 等 playbook 仍然继续执行
   - Docker 安装尝试使用 `/data` 目录，但目录未挂载
   - 可能导致数据写入到系统盘而非数据盘

---

## 解决方案

### 1️⃣ 增强磁盘选择逻辑

添加了 **3 层磁盘选择策略**，从严格到宽松：

#### 优先级 1：未挂载的分区（最安全）
```yaml
partition_candidates |
selectattr('mountpoint', 'none') |
rejectattr('mountpoint', 'equalto', '/') |
rejectattr('mountpoint', 'match', '^/boot') |
sort(attribute='size', reverse=true)
```

#### 优先级 2：未挂载的整盘
```yaml
disk_candidates |
selectattr('mountpoint', 'none') |
rejectattr('children', 'defined') |
sort(attribute='size', reverse=true)
```

#### 优先级 3：挂载到非标准位置的磁盘（新增）✨
```yaml
disk_candidates |
rejectattr('mountpoint', 'none') |           # 已挂载
rejectattr('mountpoint', 'equalto', '/') |   # 不是根目录
rejectattr('mountpoint', 'match', '^/boot') | # 不是 boot
rejectattr('children', 'defined') |          # 整盘
sort(attribute='size', reverse=true)
```

**适用场景**：
- Hetzner 云服务器预挂载的 Volume（如 `/mnt/HC_Volume_*`）
- 手动挂载到临时位置的磁盘
- 需要重新规范化挂载点的磁盘

---

### 2️⃣ 自动 Unmount 旧挂载点

在重新挂载之前，自动 unmount 旧的挂载点：

```yaml
- name: Check if device is currently mounted
  shell: mount | grep "^{{ final_device }} " || true
  register: current_mount
  changed_when: false

- name: Unmount device from old location if needed
  mount:
    path: "{{ current_mount.stdout.split()[2] }}"
    state: unmounted
  when:
    - current_mount.stdout != ''
    - needs_remount is defined and needs_remount

- name: Show unmount message
  debug:
    msg: "🔄 Unmounted {{ final_device }} from {{ current_mount.stdout.split()[2] }}"
  when: unmount_result is changed
```

**工作流程**（以 preview 为例）：
```
1. 检测到 /dev/sdb 挂载到 /mnt/HC_Volume_104039904
   ↓
2. 设置 selection_method = "auto-remount"
   ↓
3. 设置 needs_remount = true
   ↓
4. Unmount /mnt/HC_Volume_104039904
   ↓
5. 跳过格式化（已有 ext4）
   ↓
6. 重新挂载到 /data
   ↓
7. 更新 /etc/fstab
```

---

### 3️⃣ 添加 `any_errors_fatal`

在 mount.yml 中添加：

```yaml
- name: Setup Data Storage Mount (Safe & Idempotent)
  hosts: all
  become: yes
  any_errors_fatal: true  # ← 任何主机失败都停止整个 playbook
```

**效果**：
- 如果 preview 的 mount 失败，prod 的 mount 也会停止
- 整个 init-server.yml 流程停止
- 防止后续任务在未挂载 /data 的情况下执行

---

### 4️⃣ 添加 /data 挂载验证

创建可复用的验证任务：`ansible/tasks/verify-data-mount.yml`

```yaml
- name: Verify /data is mounted
  command: mountpoint -q /data
  failed_when: data_mount_check.rc != 0

- name: Verify /data is writable
  file:
    path: /data/.mount-test
    state: touch

- name: Show /data status
  debug:
    msg:
      - "✅ /data is properly mounted and writable"
      - "{{ data_df.stdout }}"
```

**在依赖 /data 的 playbook 中使用**：

```yaml
# setup-docker.yml
tasks:
  - name: Verify /data mount
    include_tasks: ../tasks/verify-data-mount.yml
    tags: [always]

# deploy-infra-backup.yml
tasks:
  - name: Verify /data mount
    include_tasks: ../tasks/verify-data-mount.yml
    tags: [always]
```

---

## 改进效果

### Before（改进前）

```
TASK [Fail if no suitable device found]
fatal: [preview]: FAILED! => {
  "msg": "❌ No suitable disk or partition found for /data"
}

TASK [Install Docker]                    ← 继续执行！
ok: [prod]
skipping: [preview]                      ← preview 被跳过

TASK [Setup Docker data-root]            ← 继续执行！
fatal: [prod]: FAILED! => {
  "msg": "/data not mounted"             ← prod 也失败了
}
```

**问题**：
- ❌ preview 找不到磁盘，失败
- ❌ 后续任务继续执行
- ❌ 没有验证 /data 是否挂载
- ❌ Docker 配置失败

---

### After（改进后）

```
TASK [Select disk mounted to non-standard location]
ok: [preview]

TASK [Display selected device]
ok: [preview] => {
  "msg": [
    "====== Selected Device ======",
    "Device: /dev/sdb",
    "Size: 20.0GB",
    "Selection method: auto-remount",
    "Has filesystem: True (ext4)",
    "Old mountpoint: /mnt/HC_Volume_104039904",
    "Needs remount: true"
  ]
}

TASK [Unmount device from old location if needed]
changed: [preview]

TASK [Show unmount message]
ok: [preview] => {
  "msg": "🔄 Unmounted /dev/sdb from /mnt/HC_Volume_104039904"
}

TASK [Add to fstab and mount]
changed: [preview]

TASK [Display success]
ok: [preview] => {
  "msg": "✅ Successfully mounted /dev/sdb to /data"
}

TASK [Verify /data mount]                ← 验证通过
ok: [preview]

TASK [Show /data status]
ok: [preview] => {
  "msg": [
    "✅ /data is properly mounted and writable",
    "/dev/sdb        20G  1.2G   18G   7% /data"
  ]
}
```

**优势**：
- ✅ preview 自动检测并重新挂载磁盘
- ✅ 显示详细的挂载信息
- ✅ 后续任务开始前验证 /data
- ✅ 完整的执行流程

---

## 适用场景

### 场景 1：Hetzner Cloud Volumes
```
初始状态：
  /dev/sdb → /mnt/HC_Volume_104039904

自动处理：
  1. 检测到挂载在非标准位置
  2. Unmount /mnt/HC_Volume_104039904
  3. 重新挂载到 /data
  4. 更新 fstab

最终状态：
  /dev/sdb → /data
```

### 场景 2：AWS EBS Volumes
```
初始状态：
  /dev/nvme1n1 → 未挂载

自动处理：
  1. 检测到未挂载的磁盘
  2. 格式化（如果需要）
  3. 挂载到 /data
  4. 更新 fstab

最终状态：
  /dev/nvme1n1 → /data
```

### 场景 3：本地磁盘（已分区）
```
初始状态：
  /dev/sdb1 → 未挂载（已有文件系统）

自动处理：
  1. 检测到未挂载的分区
  2. 跳过格式化
  3. 挂载到 /data
  4. 更新 fstab

最终状态：
  /dev/sdb1 → /data
```

---

## 幂等性保证

无论运行多少次，结果都相同：

```bash
# 第一次运行：完整挂载流程
ansible-playbook init-server.yml
# ✅ /dev/sdb → /data

# 第二次运行：检测到已挂载，完全跳过
ansible-playbook init-server.yml
# ⏭️  /data already mounted, skipping

# 第三次运行：仍然跳过
ansible-playbook init-server.yml
# ⏭️  /data already mounted, skipping
```

---

## 安全性增强

### 数据保护

- ✅ 多重验证：`mountpoint` + `df` + `lsblk`
- ✅ 绝不格式化已有数据的磁盘（`force: no`）
- ✅ 跳过包含数据的目录
- ✅ 原子操作：`mount` 模块的 `state: mounted`

### 错误处理

- ✅ `any_errors_fatal: true` - 一个主机失败，全部停止
- ✅ 前置验证 - 每个依赖 /data 的 playbook 都先验证
- ✅ 详细日志 - 显示选择逻辑和执行过程
- ✅ 友好提示 - 失败时给出清晰的错误信息

---

## 测试场景

### 已测试的场景

1. ✅ **未挂载的整盘**
   - 磁盘：`/dev/sdb` (20GB)
   - 状态：未挂载，无文件系统
   - 结果：格式化 → 挂载 → 成功

2. ✅ **未挂载的分区**
   - 分区：`/dev/sdb1` (20GB)
   - 状态：未挂载，已有 ext4
   - 结果：跳过格式化 → 挂载 → 成功

3. ✅ **挂载到非标准位置**
   - 磁盘：`/dev/sdb` (20GB)
   - 状态：挂载到 `/mnt/HC_Volume_104039904`
   - 结果：Unmount → 重新挂载到 /data → 成功

4. ✅ **已正确挂载**
   - 磁盘：`/dev/sdb` (20GB)
   - 状态：挂载到 `/data`
   - 结果：跳过所有步骤 → 成功

5. ✅ **无可用磁盘**
   - 状态：所有磁盘都是系统盘
   - 结果：友好错误提示 → 失败

### 需要手动测试的场景

- 🔲 多块数据盘（应选择最大的）
- 🔲 LVM 卷
- 🔲 RAID 设备

---

## 配置选项

### 可选变量

```yaml
# 指定磁盘（跳过自动检测）
-e "data_disk=/dev/sdb"

# 最小磁盘大小（默认 10GB）
-e "data_disk_min_size_gb=20"

# 挂载点（默认 /data）
-e "data_mount_point=/data"
```

### 标签

```bash
# 只运行挂载任务
ansible-playbook init-server.yml --tags mount

# 跳过挂载任务
ansible-playbook init-server.yml --skip-tags mount
```

---

## 总结

### 核心改进

1. ✅ **3 层磁盘选择策略** - 处理更多场景
2. ✅ **自动 Unmount** - 重新规范化挂载点
3. ✅ **any_errors_fatal** - 任何主机失败都停止
4. ✅ **前置验证** - 依赖 /data 的任务先验证

### 关键文件

```
ansible/
├── playbooks/
│   ├── mount.yml                    # 挂载主逻辑（已增强）
│   ├── setup-docker.yml             # 添加了 /data 验证
│   └── deploy-infra-backup.yml      # 添加了 /data 验证
└── tasks/
    └── verify-data-mount.yml        # 可复用的验证任务（新建）
```

---

**现在 mount 流程更加鲁棒，可以处理各种云服务商的磁盘预挂载情况！** 🚀
