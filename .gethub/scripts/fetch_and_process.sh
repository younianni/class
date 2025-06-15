#!/bin/bash

# 设置错误处理
set -euo pipefail

# 创建临时目录
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

# 获取JSON数据
echo "正在获取课程数据..."
curl -s -u "$API_USERNAME:$API_PASSWORD" "$COURSE_API_URL" -o "$TEMP_DIR/courses.json"

echo "正在获取日期数据..."
curl -s -u "$API_USERNAME:$API_PASSWORD" "$DATE_API_URL" -o "$TEMP_DIR/dates.json"

# 验证数据
echo "正在验证数据..."
if ! jq -e . "$TEMP_DIR/courses.json" >/dev/null 2>&1; then
  echo "错误：获取的课程JSON数据格式不正确"
  exit 1
fi

if ! jq -e . "$TEMP_DIR/dates.json" >/dev/null 2>&1; then
  echo "错误：获取的日期JSON数据格式不正确"
  exit 1
fi

# 从日期数据中提取当前周
CURRENT_WEEK=$(jq -r '.nowweek' "$TEMP_DIR/dates.json")
echo "当前周：$CURRENT_WEEK"

# 创建输出目录
mkdir -p "$OUTPUT_DIR"

# 生成data.js文件
echo "正在生成data.js..."
cat > "$OUTPUT_DIR/data.js" << EOF
const courseData = $(jq '.' "$TEMP_DIR/courses.json");
const dateData = $(jq '.' "$TEMP_DIR/dates.json");

// 根据周次过滤课程数据的函数
function getCoursesByWeek(week) {
  return courseData.filter(course => {
    return course.weeks.includes(week);
  });
}
EOF

echo "data.js生成完成！"

# 创建周次导航页面
echo "正在生成周次导航页面..."
cat > "$OUTPUT_DIR/weeks.html" << EOF
<!DOCTYPE html>
<html>
<head>
  <title>选择周次</title>
  <style>
    body { font-family: Arial, sans-serif; text-align: center; padding: 20px; }
    .week-container { display: flex; flex-wrap: wrap; justify-content: center; gap: 10px; max-width: 800px; margin: 0 auto; }
    .week-link { display: inline-block; padding: 10px 15px; background-color: #4CAF50; color: white; text-decoration: none; border-radius: 5px; }
    .week-link:hover { background-color: #45a049; }
    .current-week { background-color: #2196F3; }
  </style>
</head>
<body>
  <h1>选择周次</h1>
  <div class="week-container">
EOF

# 假设总周数为20，可以根据实际情况修改
TOTAL_WEEKS=20
for week in $(seq 1 $TOTAL_WEEKS); do
  if [ "$week" -eq "$CURRENT_WEEK" ]; then
    echo "    <a href=\"week$week/\" class=\"week-link current-week\">第$week周 (当前周)</a>" >> "$OUTPUT_DIR/weeks.html"
  else
    echo "    <a href=\"week$week/\" class=\"week-link\">第$week周</a>" >> "$OUTPUT_DIR/weeks.html"
  fi
done

cat >> "$OUTPUT_DIR/weeks.html" << EOF
  </div>
  <p><a href="index.html">返回当前周</a></p>
</body>
</html>
EOF

echo "周次导航页面生成完成！"

# 为当前周和后续几周创建独立页面
echo "正在为当前周及后续几周生成页面..."
WEEKS_TO_GENERATE=4  # 生成当前周及后续3周的页面

for week in $(seq "$CURRENT_WEEK" "$((CURRENT_WEEK + WEEKS_TO_GENERATE - 1))"); do
  if [ "$week" -gt "$TOTAL_WEEKS" ]; then
    break
  fi
  
  # 创建周次目录
  week_dir="$OUTPUT_DIR/week$week"
  mkdir -p "$week_dir"
  
  # 复制HTML模板和data.js
  cp "$HTML_TEMPLATE" "$week_dir/index.html"
  cp "$OUTPUT_DIR/data.js" "$week_dir/"
  
  # 更新周次信息
  sed -i "s/nowweek\": [0-9]*/nowweek\": $week/" "$week_dir/data.js"
  
  echo "已生成第$week周页面"
done

# 创建根目录的index.html，重定向到当前周
echo "正在创建根目录索引页面..."
cat > "$OUTPUT_DIR/index.html" << EOF
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>课表</title>
  <meta http-equiv="refresh" content="0; url=week$CURRENT_WEEK/">
</head>
<body>
  <p>正在重定向到第$CURRENT_WEEK周的课表...</p>
  <p>如果没有自动跳转，请点击<a href="week$CURRENT_WEEK/">这里</a>。</p>
</body>
</html>
EOF

echo "根目录索引页面生成完成！"    
