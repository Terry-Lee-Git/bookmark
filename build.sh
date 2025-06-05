#!/bin/bash

set -e

# 获取当前分支名
BRANCH_NAME=$(git rev-parse --abbrev-ref HEAD)

# 你当前的主版本号
BASE_VERSION="1.0.0"

# 发布 release（master）
if [ "$BRANCH_NAME" == "master" ]; then
  echo "🔧 On master branch: performing release..."

  # 使用 Maven release 插件进行正式发布和打 tag
  mvn -B release:prepare release:perform \
      -DreleaseVersion=${BASE_VERSION} \
      -DdevelopmentVersion=${BASE_VERSION}-SNAPSHOT \
      -Dtag=v${BASE_VERSION} \
      -Darguments="-DskipTests"

else
  # 构建 SNAPSHOT 版本名，例如：1.0.0-feature-login-page-SNAPSHOT
  # 将分支名中斜杠 / 替换为连字符 -
  SAFE_BRANCH=$(echo "$BRANCH_NAME" | sed 's#/#-#g')
  SNAPSHOT_VERSION="${BASE_VERSION}-${SAFE_BRANCH}-SNAPSHOT"

  echo "🔧 On feature branch ($BRANCH_NAME): deploying snapshot as version $SNAPSHOT_VERSION"

  # 设置版本并部署（不会打 tag）
  mvn -B versions:set -DnewVersion=${SNAPSHOT_VERSION}
  mvn -B deploy -DskipTests

  # 可选：恢复回原始版本
  mvn versions:revert
fi