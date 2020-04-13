#!/bin/sh

has_errors=0

# 获取git暂存的所有go代码
# --cached 暂存的
# --name-only 只显示名字
# --diff-filter=ACM 过滤暂存文件，A=Added C=Copied M=Modified, 即筛选出添加/复制/修改的文件
allgofiles=$(git diff --cached --name-only --diff-filter=ACM | grep '.go$')


# 过滤vendor的
gofiles=()
for allfile in ${allgofiles[@]}; do 
    if [[ $allfile == "vendor"* ]];then
        continue
    else
		gofiles+=("$allfile")
	fi
done

[ -z "$gofiles" ] && exit 0

for file in ${gofiles[@]}; do 
echo 'ALL: '$file
done

# gofmt 格式化代码
unformatted=$(gofmt -l ${gofiles[@]})
if [ -n "$unformatted" ]; then
	echo >&2 "gofmt FAIL:\n 运行以下命令:"
	for f in ${unformatted[@]}; do
		echo >&2 " gofmt -w $PWD/$f"
	done
	echo "\n"
	has_errors=1
fi

# goimports 自动导包
if goimports >/dev/null 2>&1; then  # 检测是否安装
	unimports=$(goimports -l ${gofiles[@]})
	if [ -n "$unimports" ]; then
		echo >&2 "goimports FAIL:\n以下文件需要重新导包:"
		for f in ${unimports[@]} ; do
			echo >&2 " goimports -w $PWD/$f"
		done
		echo "\n"
		has_errors=1
	fi
else
	echo 'Error: goimports 未安装。运行: "go get -u golang.org/x/tools/cmd/goimports" 安装' >&2
	exit 1
fi

# golint 代码规范检测
if golint >/dev/null 2>&1; then  # 检测是否安装
	lint_errors=false
	for file in ${gofiles[@]} ; do
		lint_result="$(golint $file)" # run golint
		if test -n "$lint_result" ; then
			echo "golint '$file':\n$lint_result"
			lint_errors=true
			has_errors=1
		fi
	done
	if [ $lint_errors = true ] ; then
		echo "\n"
	fi
else
	echo 'Error: golint 未安装。 运行: "go get -u github.com/golang/lint/golint" 安装' >&2
	exit 1
fi

# go vet 静态错误检查
show_vet_header=true
for file in ${gofiles[@]} ; do
	vet=$(go vet $file 2>&1)
	if [ -n "$vet" -a $show_vet_header = true ] ; then
		echo "govet:"
		show_vet_header=false
	fi
	if [ -n "$vet" ] ; then
		echo "$vet\n"
		has_errors=1
	fi
done


exit $has_errors