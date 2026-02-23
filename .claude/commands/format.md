# /format

**描述**: 格式化代码，统一代码风格
**哲学**: Consistency - 一致的代码风格提升可读性

---

## 用法

```
/format              # 格式化当前文件
/format filename.R   # 格式化指定文件
/format --apply      # 原地格式化（默认）
/format --check      # 只检查不修改
```

---

## 格式化规则

### R 语言
- 缩进：2 空格
- 行宽：80 字符
- 运算符两侧空格
- 逗号后空格
- 函数名后无空格

### 示例

```r
# 格式化前
foo<-function(x,y){
if(x>0){
return(x+y)
}else{
return(0)
}
}

# 格式化后
foo <- function(x, y) {
  if (x > 0) {
    return(x + y)
  } else {
    return(0)
  }
}
```

---

## 自动修复项

- [x] 缩进对齐
- [x] 空格规范化
- [x] 换行符统一
- [x] 多余空行删除
- [x] 行尾空格删除
