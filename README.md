
# [利用git hook规范你的代码与commit message](https://razeencheng.com/post/golang-and-git-commit-message-pre-commit.html)

在团队协作时，由于个人编码习惯的差异，导致代码格式，风格都会有所不同，这就给代码审核带来一定的困难，更严重的是会导致整体的代码质量不可控。这时，我们有必要借助一些工具来约束我们的代码格式。在Go中，我们经常使用的工具有：

- `goimports`: 自动导包；
- `gofmt` : 格式化我们的代码；
- `golint`: 检查代码命名，注释等；
- `go vet`: 静态错误检查。

那么，我们可以利用这些工具来规范团队的代码风格。但如果每次手动执行这些命令，或者仅仅依靠IDE去检查，这是不靠谱的，因为人的行为本身是不靠谱的==。

于是，我们可以结合`git hook`, 强制执行这些检查，检查不通过，代码都无法提交，从而达到强一致性。

同时，结合上一篇[<<规范git commit message与自动化版本控制>>](https://razeencheng.com/post/conventional-commits-and-standard-version.html),  这里我们介绍一下利用pre-commit 约束commit-msg来约束我们的代码与git commit message。

### go pre-commit hook

那么，我们怎么写一个pre-commit hook呢？

- 首先，我们需要判断用户是否装上面这些工具；
- 然后，我们需要对git暂存区的代码(不包括vendor)，利用上面提到的四个工具进检查。

直接上代码。

``` bash
#!/bin/sh

has_errors=0

# 获取git暂存的所有go代码
# --cached 暂存的
# --name-only 只显示名字
# --diff-filter=ACM 过滤暂存文件，A=Added C=Copied M=Modified, 即筛选出添加/复制/修改的文件
allgofiles=$(git diff --cached --name-only --diff-filter=ACM | grep '.go$')

gofiles=()
godirs=()
for allfile in ${allgofiles[@]}; do 
    # 过滤vendor的
    # 过滤prootobuf自动生产的文件
    if [[ $allfile == "vendor"* || $allfile == *".pb.go" ]];then
        continue
    else
        gofiles+=("$allfile")

        # 文件夹去重
        existdir=0
        dir=`echo "$allfile" |xargs -n1 dirname|sort -u`
        for somedir in ${godirs[@]}; do
            if [[ $dir == $somedir ]]; then 
                existdir=1
                break
            fi
        done

        if [[ $existdir -eq 0 ]]; then 
            godirs+=("$dir")
        fi
    fi
done

[ -z "$gofiles" ] && exit 0

# gofmt 格式化代码
unformatted=$(gofmt -l ${gofiles[@]})
if [ -n "$unformatted" ]; then
	echo >&2 "gofmt FAIL:\n Run following command:"
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
		echo >&2 "goimports FAIL:\nRun following command:"
		for f in ${unimports[@]} ; do
			echo >&2 " goimports -w $PWD/$f"
		done
		echo "\n"
		has_errors=1
	fi
else
	echo 'Error: goimports not install. Run: "go get -u golang.org/x/tools/cmd/goimports"' >&2
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
	echo 'Error: golint not install. Run: "go get -u github.com/golang/lint/golint"' >&2
	exit 1
fi

# go vet 静态错误检查
show_vet_header=true
for dir in ${godirs[@]} ; do
    vet=$(go vet $PWD/$dir 2>&1)
    if [ -n "$vet" -a $show_vet_header = true ] ; then
	echo "govet FAIL:"
	show_vet_header=false
    fi
    if [ -n "$vet" ] ; then
	echo "$vet\n"
	has_errors=1
    fi
done


exit $has_errors
```



### commit-msg hook

结合上一篇的规范化git commit message提交，我们这里做几点限制：

- 至少15个字符（15个字符都没有，提交信息肯定不详细)；
- 必须以`feat|fix|chore|docs`关键词开头，可选`(scope)` , 之后必须紧跟冒号和空格`:  ` ,之后就是具体的描述。

直接上脚本：

``` bash
#!/bin/sh

COMMIT_MSG=`cat $1 | egrep "^(feat|fix|docs|chore)\(\w+\)?:\s(\S|\w)+"`

if [ "$COMMIT_MSG" = "" ]; then
	echo "Commit Message 不规范，请检查!\n"
	exit 1
fi

if [ ${#COMMIT_MSG} -lt 15 ]; then
	echo "Commit Message 太短了，请再详细点!\n"
	exit 1
fi
```



### 配置Hooks

`git hooks`已经写好了，我们开始配置。

首先进入你的项目，找到`.git/hooks`文件夹，可以看到很多`*.simple`结尾的文件，我们新增`commit-msg`和`pre-commit`文件，或者去掉`commit-msg.simple`和`pre-commit.simple`的`simple`后缀。

然后，我们分别用 **go pre-commit hook** 和 **commit-msg hook**两部分的脚本替换`pre-commit`和`commit-msg`的内容。

最后，我们给这两个文件执行权限。

```bash
chmod +x commit-msg pre-commit
```

之后我们就可以正常使用了。



**一键安装**

用Mac电脑的童鞋，可以在需要支持的项目下面，一键安装。

```bash
curl -kSL https://raw.githubusercontent.com/razeencheng/git-hooks/master/install.sh | sh
```