#!/bin/bash -xv
# SPDX-FileCopyrightText: 2023 Ryuichi Ueda ryuichiueda@gmail.com
# SPDX-License-Identifier: BSD-3-Clause

err () {
	echo "ERROR!" FILE: $0, LINENO: $1
	exit 1
}

cargo build --release || err $LINENO

cd $(dirname $0)
com=../target/release/sush

: > error
: > ok

./test_job.bash nobuild &
./test_brace.bash nobuild &
./test_builtins.bash nobuild &

### SIMPLE COMMAND TEST ###

res=$($com <<< 'echo hoge')
[ "$res" = "hoge" ] || err $LINENO

res=$($com <<< ' echo hoge')
[ "$res" = "hoge" ] || err $LINENO

res=$($com <<< '	echo hoge')
[ "$res" = "hoge" ] || err $LINENO

res=$($com <<< 'echo hoge;')
[ "$res" = "hoge" ] || err $LINENO

res=$($com <<< '! eeee' )
[ "$?" = "0" ] || err $LINENO

res=$($com <<< '! echo' )
[ "$?" = "1" ] || err $LINENO

res=$($com <<< '! cd' )
[ "$?" = "1" ] || err $LINENO

res=$($com <<< '!' )
[ "$?" = "1" ] || err $LINENO

### PARAMETER TEST ###

res=$($com <<< 'echo ${A:-abc}' )
[ "$res" = "abc" ] || err $LINENO

res=$($com <<< 'echo ${A:-abc}; echo $A' )
[ "$res" = "abc" ] || err $LINENO

res=$($com <<< 'echo ${A:=abc}; echo $A' )
[ "$res" = "abc
abc" ] || err $LINENO

res=$($com <<< 'echo ${A:="aaa
bbb"}
echo "$A"' )
[ "$res" = "aaa bbb
aaa
bbb" ] || err $LINENO

res=$($com <<< 'echo ${A:?error}' )
[ "$?" = "1" ] || err $LINENO
[ "$res" = "" ] || err $LINENO

res=$($com <<< '(echo ${A:?error}) |& cat' )
[ "$res" = "sush: A: error" ] || err $LINENO

res=$($com <<< 'A= ; echo ${A:+set}' )
[ "$res" = "" ] || err $LINENO

res=$($com <<< 'A=aaa ; echo ${A:+set}' )
[ "$res" = "set" ] || err $LINENO

res=$($com <<< 'A=aaa ; echo ${A:+"set
ok"}' )
[ "$res" = "set
ok" ] || err $LINENO

res=$($com <<< 'A=aaa ; echo ${A- - - - -}' )
[ "$res" = "aaa" ] || err $LINENO

res=$($com <<< 'echo ${A:-   abc}' )
[ "$res" = "abc" ] || err $LINENO

res=$($com <<< 'echo ${A:-abc def}' )
[ "$res" = "abc def" ] || err $LINENO

res=$($com <<< 'B=あ ; echo ${A:-$B def}' )
[ "$res" = "あ def" ] || err $LINENO

res=$($com <<< 'B=あ ; echo ${A:-$B
def}' )
[ "$res" = "あ def" ] || err $LINENO

res=$($com <<< 'B=あ ; echo ${A:-"$B
def"}' )
[ "$res" = "あ
def" ] || err $LINENO

### COMPOUND COMMAND TEST ###

res=$($com <<< '(echo hoge; echo fuge)')
[ "$res" = "hoge
fuge" ] || err $LINENO

res=$($com <<< '(echo a; (echo b ; echo c) )')
[ "$res" = "a
b
c" ] || err $LINENO

res=$($com <<< '(
echo a; (echo b ; 
echo c) )')
[ "$res" = "a
b
c" ] || err $LINENO

res=$($com <<< '   (

echo a; (echo b ; 

echo c) )   ')
[ "$res" = "a
b
c" ] || err $LINENO

res=$($com <<< '   (#aaaa

echo a; (echo b ;  #bbb

echo c) )   ')
[ "$res" = "a
b
c" ] || err $LINENO

res=$($com <<< '(
echo a; (echo b ; 
')
[ "$?" = "2" ] || err $LINENO

res=$($com <<< '(echo hoge; false)')
[ "$?" = 1 ] || err $LINENO

res=$($com <<< 'cd / ; (cd /etc); pwd')
[ "$res" = / ] || err $LINENO

res=$($com <<< 'cd ; { cd / ; } ; pwd')
[ "$res" = / ] || err $LINENO

res=$($com <<< '( )')
[ "$?" = 2 ] || err $LINENO

res=$($com <<< '( echo a ; }')
[ "$?" = 2 ] || err $LINENO

res=$($com <<< '{ echo a ; }')
[ $res = "a" ] || err $LINENO

res=$($com <<< '{ echo a ; echo b ;}')
[ "$res" = "a
b" ] || err $LINENO

res=$($com <<< '{ echo a ; (echo b ; echo c) ;}')
[ "$res" = "a
b
c" ] || err $LINENO

res=$($com <<< '{ echo } ; }')
[ "$res" = "}" ] || err $LINENO

res=$($com <<< '{ echo a }')
[ "$?" = 2 ] || err $LINENO

res=$($com <<< 'echo (')
[ "$?" = 2 ] || err $LINENO

### IRREGULAR INPUT TEST ###

res=$($com <<< 'eeeeeecho hoge')
[ "$?" = 127 ] || err $LINENO

res=$($com <<< ';')
[ "$?" = 2 ] || err $LINENO

res=$($com <<< ';a')
[ "$?" = 2 ] || err $LINENO

### PIPELINE ###

res=$($com <<< 'seq 10 | rev | tail -n 1')
[ "$res" = "01" ] || err $LINENO

res=$($com <<< 'seq 10 |
	rev | tail -n 1')
[ "$res" = "01" ] || err $LINENO

res=$($com <<< 'seq 10 |    

	  rev | tail -n 1')
[ "$res" = "01" ] || err $LINENO

res=$($com <<< 'seq 10 |  #コメントだよ

#コメントだよ
    #こめんとだよ

	  rev | tail -n 1')
[ "$res" = "01" ] || err $LINENO

res=$($com <<< 'seq 10 |   | head -n 1')
[ "$?" = "2" ] || err $LINENO

### COMMENT ###

res=$($com <<< 'echo a #aaaaa')
[ "$res" = "a" ] || err $LINENO

res=$($com <<< '
#comment comment
   #comment comment
echo a #aaaaa
#comment comment
')
[ "$res" = "a" ] || err $LINENO

res=$($com <<< '(echo a) #aaaaa')
[ "$res" = "a" ] || err $LINENO

res=$($com <<< '(echo a)#aaaaa')
[ "$res" = "a" ] || err $LINENO

res=$($com <<< '{ echo a; }#aaaaa')
[ "$res" != "a" ] || err $LINENO

res=$($com <<< '{ echo a; } #aaaaa')
[ "$res" = "a" ] || err $LINENO

### FUNCTION TEST ###

res=$($com <<< 'f () { echo a; } ; f')
[ "$res" = "a" ] || err $LINENO

res=$($com <<< 'function f () { echo a; } ; f')
[ "$res" = "a" ] || err $LINENO

res=$($com <<< 'function f () { echo $A; } ; A=OK f')
[ "$res" = "OK" ] || err $LINENO

res=$($com <<< 'function f () { echo $A; } ; A=OK f | rev')
[ "$res" = "KO" ] || err $LINENO

res=$($com <<< 'function f () { A=BBB ; } ; f; echo $A')
[ "$res" = "BBB" ] || err $LINENO

res=$($com <<< 'function f () ( A=BBB ) ; f; echo $A')
[ "$res" = "" ] || err $LINENO

res=$($com <<< 'function f () { A=BBB ; } ; f | cat; echo $A')
[ "$res" = "" ] || err $LINENO

res=$($com <<< 'function f () { tr -d \\n ; } ; seq 3 | f')
[ "$res" = "123" ] || err $LINENO

res=$($com <<< 'set a b c ; function f () { echo $2 ; } ; f')
[ "$res" = "" ] || err $LINENO

res=$($com <<< 'set a b c ; function f () { echo $2 ; } ; f; echo $2')
[ "$res" = "
b" ] || err $LINENO

res=$($com <<< 'set a b c ; function f () { set 1 2 3 ; echo $2 ; } ; f; echo $2')
[ "$res" = "2
b" ] || err $LINENO

res=$($com <<< 'function f () { local A=BBB ; echo $A; } ; f')
[ "$res" = BBB ] || err $LINENO

res=$($com <<< 'function f () { local A=BBB ; echo $A ; } ; echo $A')
[ "$res" = "" ] || err $LINENO

res=$($com <<< 'function f () { local A=( a b c ) ; echo ${A[1]}; } ; f')
[ "$res" = b ] || err $LINENO

res=$($com <<< 'function f () { return; echo NG; } ; f')
[ "$res" = "" ] || err $LINENO

res=$($com <<< 'function f () { echo ok && return 3; } ; f')
[ "$?" = "3" ] || err $LINENO
[ "$res" = "ok" ] || err $LINENO

res=$($com <<< 'f () { g () { return; echo NG; } ; g ; echo OK; } ; f')
[ "$res" = "OK" ] || err $LINENO

### NEW LINE ###

res=$($com <<< 'e\
c\
ho hoge')
[ "$res" = "hoge" ] || err $LINENO

res=$($com <<< 'e\
c\
ho \
hoge')
[ "$res" = "hoge" ] || err $LINENO

res=$($com <<< 'echo hoge |\
rev')
[ "$res" = "egoh" ] || err $LINENO

res=$($com <<< 'echo hoge |\
& rev')
[ "$res" = "egoh" ] || err $LINENO

res=$($com <<< ' (seq 3; seq 3) | grep 3 | wc -l | tr -dc 0-9')
[ "$res" = "2" ] || err $LINENO

res=$($com <<< 'ls |  | rev')
[ "$?" == "2" ] || err $LINENO

### REDIRECTS ###

# <, >, >>

res=$($com <<< 'cat < /etc/passwd | wc -l')
[ "$res" != "0" ] || err $LINENO

res=$($com <<< 'cat < /etc/passwd > /tmp/rusty_bash1 ; cat /tmp/rusty_bash1 | wc -l')
[ "$res" != "0" ] || err $LINENO

res=$($com <<< 'echo a > /tmp/rusty_bash1 ; echo b >> /tmp/rusty_bash1; cat /tmp/rusty_bash1')
[ "$res" = "a
b" ] || err $LINENO

# non-fork redirects

res=$($com <<< '
	cd /etc/
	cd /tmp
	cd - > /tmp/rusty_bash1
	cd - > /tmp/rusty_bash2
	cat /tmp/rusty_bash1
	cat /tmp/rusty_bash2
	pwd' | sed s@.private@@)
[ "$res" = "/etc
/tmp
/tmp" ] || err $LINENO

res=$($com <<< '
	cd /etc/
	cd /tmp
	{ cd - ; cd - ; /bin/echo a; } > /tmp/rusty_bash1
	{ cd - ; } > /tmp/rusty_bash2
	cat /tmp/rusty_bash1
	cat /tmp/rusty_bash2
	pwd' | sed s@.private@@)
[ "$res" = "/etc
/tmp
a
/etc
/etc" ] || err $LINENO

# 2>, 2>>

res=$($com <<< '
	ls /aaaa 2> /tmp/rusty_bash
	ls /bbbb 2>> /tmp/rusty_bash
	cat /tmp/rusty_bash | grep ls | wc -l
	' | tr -dc 0-9)
[ "$res" = "2" ] || err $LINENO

# &>

res=$($com <<< 'ls /etc/passwd aaaa &> /tmp/rusty_bash; cat /tmp/rusty_bash | wc -l | tr -dc 0-9')
[ "$res" == "2" ] || err $LINENO

# &> for non-fork redirects

res=$($com <<< '
	{ ls /etc/passwd aaaa ; } &> /tmp/rusty_bash
	cat /tmp/rusty_bash | wc -l | tr -dc 0-9')
[ "$res" == "2" ] || err $LINENO

res=$(LANG=C $com <<< '
	{ ls /etc/passwd aaaa ; } &> /tmp/rusty_bash
	cat /tmp/rusty_bash | wc -l
	#ちゃんと標準出力が原状復帰されているか調査
	{ ls /etc/passwd ; }
	{ ls aaaa ; } 2> /tmp/rusty_bash2
	cat /tmp/rusty_bash2 | wc -l
	' | tr -d [:blank:])
[ "$res" == "2
/etc/passwd
1" ] || err $LINENO

res=$($com <<< '
	cd /etc/
	cd /tmp
	{ cd - ; cd - ; /bin/echo a; } &> /tmp/rusty_bash1
	{ cd - ; } &> /tmp/rusty_bash2
	cat /tmp/rusty_bash1
	cat /tmp/rusty_bash2
	pwd' | sed s@.private@@)
[ "$res" = "/etc
/tmp
a
/etc
/etc" ] || err $LINENO

# >&

b=$(ls aaaaaaaaaaaaaa 2>&1 | wc -l)
res=$($com <<< 'ls aaaaaaaaaaaaaa 2>&1 | wc -l')
[ "$b" == "$res" ] || err $LINENO

res=$($com <<< 'pwd 200>&100')
[ "$?" == "1" ] || err $LINENO

res=$($com <<< 'ls 200>&100')
[ "$?" == "1" ] || err $LINENO

# with expansion

res=$($com <<< 'echo a > {a,b}' 2>&1)
[ "$?" == "1" ] || err $LINENO
[ "$res" == "sush: {a,b}: ambiguous redirect" ] || err $LINENO


### JOB PARSE TEST ###

res=$($com <<< '&& echo a')
[ "$?" == "2" ] || err $LINENO
[ "$res" == "" ] || err $LINENO

res=$($com <<< 'echo a
&& echo b')
[ "$?" == "2" ] || err $LINENO

res=$($com <<< 'echo a &\
& echo b')
[ "$res" == "a
b" ] || err $LINENO

res=$($com <<< 'echo a &&\
echo b')
[ "$res" == "a
b" ] || err $LINENO

res=$($com <<< 'echo a &&
echo b')
[ "$res" == "a
b" ] || err $LINENO

res=$($com <<< 'echo a &&



echo b')
[ "$res" == "a
b" ] || err $LINENO

res=$($com <<< 'echo a ||
echo b')
[ "$res" == "a" ] || err $LINENO

res=$($com <<< 'echo a \
&& echo b')
[ "$res" == "a
b" ] || err $LINENO

# double quotation

res=$($com <<< 'echo "*"')
[ "$res" == "*" ] || err $LINENO

res=$($com <<< 'echo "{a,{b},c}"')
[ "$res" == "{a,{b},c}" ] || err $LINENO

export RUSTY_BASH_A='a
b'
res=$($com <<< 'echo "$RUSTY_BASH_A"')
[ "$res" == "a
b" ] || err $LINENO

res=$($com <<< 'echo "$BASH{PID,_SUBSHELL}"')
[ "$res" == "{PID,_SUBSHELL}" ] || err $LINENO

res=$($com <<< 'echo "\$HOME"')
[ "$res" == '$HOME' ] || err $LINENO

res=$($com <<< 'echo "\a"')
[ "$res" == '\a' ] || err $LINENO

res=$($com <<< 'echo "\\"')
[ "$res" == '\' ] || err $LINENO

res=$($com <<< 'echo "a   b"')
[ "$res" == 'a   b' ] || err $LINENO

res=$($com <<< 'echo "a
b
c"')
[ "$res" == 'a
b
c' ] || err $LINENO

res=$($com <<< 'echo "')
[ "$?" == 2 ] || err $LINENO

res=$($com <<< 'echo "" a')
[ "$res" == " a" ] || err $LINENO

res=$($com <<< 'set a b c; echo a"$@"c')
[ "$res" == "aa b cc" ] || err $LINENO

res=$($com <<< 'set a b c; A=( A"$@"C ); echo ${A[0]}')
[ "$res" == "Aa" ] || err $LINENO

res=$($com <<< 'set a b c; A=( A"$@"C ); echo ${A[2]}')
[ "$res" == "cC" ] || err $LINENO

res=$($com <<< 'set a b c; A=( A"$*"C ); echo ${A[0]}')
[ "$res" == "Aa b cC" ] || err $LINENO

res=$($com <<< 'set a b c; A=( A$*C ); echo ${A[1]}')
[ "$res" == "b" ] || err $LINENO

res=$($com <<< 'set a; A=( A"$@"C ); echo ${A[0]}')
[ "$res" == "AaC" ] || err $LINENO

res=$($com <<< 'A=( A"$@"C ); echo ${A[0]}')
[ "$res" == "AC" ] || err $LINENO

res=$($com <<< 'set あ; echo a"$@"c')
[ "$res" == "aあc" ] || err $LINENO

res=$($com <<< 'set あ い; echo a"$@"c')
[ "$res" == "aあ いc" ] || err $LINENO

res=$($com <<< 'echo a"$@"c')
[ "$res" == "ac" ] || err $LINENO

# single quoted

res=$($com <<< "echo '' a")
[ "$res" == " a" ] || err $LINENO

### WHILE TEST ###

res=$($com <<< 'touch /tmp/rusty_bash ; while [ -f /tmp/rusty_bash ] ; do echo wait ; rm /tmp/rusty_bash ; done')
[ "$res" == "wait" ] || err $LINENO

res=$($com <<< 'rm -f /tmp/rusty_bash ; while [ -f /tmp/rusty_bash ] ; do echo wait ; rm /tmp/rusty_bash ; done')
[ "$res" == "" ] || err $LINENO

res=$($com <<< 'while false ; do echo do not come here ; done')
[ "$?" == 0 ] || err $LINENO
[ "$res" == "" ] || err $LINENO

### ARG TEST ###

# substitution

res=$($com <<< 'A=BBB; echo $A')
[ "$res" == "BBB" ] || err $LINENO

res=$($com <<< 'A=BBB echo ok')
[ "$res" == "ok" ] || err $LINENO

res=$($com <<< 'A=BBB B= echo ok')
[ "$res" == "ok" ] || err $LINENO

res=$($com <<< 'A=BBB $(); echo $A')
[ "$res" == "BBB" ] || err $LINENO

res=$($com <<< 'A=BBB $(echo); echo $A')
[ "$res" == "BBB" ] || err $LINENO

res=$($com <<< 'A=BBB bash -c "echo \$A"')
[ "$res" == "BBB" ] || err $LINENO

res=$($com <<< 'A=BBB B=CCC bash -c "echo \$A \$B"')
[ "$res" == "BBB CCC" ] || err $LINENO

res=$($com <<< 'A=A$(echo BBB)C; echo $A')
[ "$res" == "ABBBC" ] || err $LINENO

res=$($com <<< 'A={a,b}; echo $A')
[ "$res" == "{a,b}" ] || err $LINENO

res=$($com <<< 'A=/*; echo $A | grep -q "*"')
[ "$?" == "1" ] || err $LINENO

res=$($com <<< 'A=/*; echo $A | grep -q "etc"')
[ "$?" == "0" ] || err $LINENO

res=$($com <<< 'A=${ }; echo NG')
[ "$ref" != "NG" ] || err $LINENO

res=$($com <<< 'A=${ }')
[ "$?" == 1 ] || err $LINENO

res=$($com <<< 'A=B cd ; echo $A')
[ "$res" == "" ] || err $LINENO

# arithmetic calculation

res=$($com <<< 'echo $((12345 ))aaa')
[ "$res" == "12345aaa" ] || err $LINENO

res=$($com <<< 'echo $((echo 123 ) )')
[ "$res" == "123" ] || err $LINENO

res=$($com <<< 'echo $((
123
))')
[ "$res" == "123" ] || err $LINENO

res=$($com <<< 'echo $((
123
)
)')
[ "$?" == "0" ] || err $LINENO
[ "$res" == "" ] || err $LINENO

res=$($com <<< 'echo $((-\
123))')
[ "$res" == "-123" ] || err $LINENO

res=$($com <<< 'echo $((-\
12\
3))')
[ "$res" == "-123" ] || err $LINENO

res=$($com <<< 'echo $((123 ) ))')
[ "$?" == "2" ] || err $LINENO
[ "$res" == "" ] || err $LINENO

res=$($com <<< 'echo $((123 + 456))')
[ "$res" == "579" ] || err $LINENO

res=$($com <<< 'echo $((123 +456))')
[ "$res" == "579" ] || err $LINENO

res=$($com <<< 'echo $((123 + 456 + 1))')
[ "$res" == "580" ] || err $LINENO

res=$($com <<< 'echo $((123 + +456))')
[ "$res" == "579" ] || err $LINENO

res=$($com <<< 'echo $((456 + -123))')
[ "$res" == "333" ] || err $LINENO

res=$($com <<< 'echo $((456 -123))')
[ "$res" == "333" ] || err $LINENO

res=$($com <<< 'echo $((- - - 1))')
[ "$res" == "-1" ] || err $LINENO

res=$($com <<< 'echo $((- + - 1))')
[ "$res" == "1" ] || err $LINENO

res=$($com <<< 'echo $((- (1 + 2 )))')
[ "$res" == "-3" ] || err $LINENO

res=$($com <<< 'echo $(( (1 + 2 ) ))')
[ "$res" == "3" ] || err $LINENO

res=$($com <<< 'echo $(( (3) ))')
[ "$res" == "3" ] || err $LINENO

res=$($com <<< 'echo $(( 1 + 2 * 3 ))')
[ "$res" == "7" ] || err $LINENO

res=$($com <<< 'echo $(( 1 + 2 / 3 ))')
[ "$res" == "1" ] || err $LINENO

res=$($com <<< 'echo $(( (1 + 2) / 3 ))')
[ "$res" == "1" ] || err $LINENO

res=$($com <<< 'echo $(( (1 + 2) / -3 ))')
[ "$res" == "-1" ] || err $LINENO

res=$($com <<< 'echo $(( (1 + 2) / - ))')
[ "$?" == "1" ] || err $LINENO
[ "$res" == "" ] || err $LINENO

res=$($com <<< 'echo $(( ))')
[ "$res" == "0" ] || err $LINENO

res=$($com <<< 'echo $(( ( ) ))')
[ "$?" == "1" ] || err $LINENO

res=$($com <<< 'A=1; echo $((A ))')
[ "$res" == "1" ] || err $LINENO

res=$($com <<< 'A=1; echo $(( $A ))')
[ "$res" == "1" ] || err $LINENO

res=$($com <<< 'A=1; echo $(( $$ - 1 ))')
[ "$?" == "0" ] || err $LINENO

res=$($com <<< 'echo $((A ))')
[ "$res" == "0" ] || err $LINENO

res=$($com <<< 'echo $((A + 3 ))')
[ "$res" == "3" ] || err $LINENO

res=$($com <<< 'A=X; echo $((A ))')
[ "$res" == "0" ] || err $LINENO

res=$($com <<< 'A=X; echo $(( ++A ))')
[ "$res" == "1" ] || err $LINENO

res=$($com <<< 'A=X; X=3 ; echo $(( ++A )); echo $A')
[ "$res" == "4
4" ] || err $LINENO

res=$(echo "echo \$(( '' ))" | $com)
[ "$?" == "1" ] || err $LINENO
[ "$res" == "" ] || err $LINENO

res=$(echo "echo \$(( '1' ))" | $com)
[ "$?" == "1" ] || err $LINENO
[ "$res" == "" ] || err $LINENO

res=$(echo "echo \$(( 1 '+' 1 ))" | $com)
[ "$?" == "1" ] || err $LINENO
[ "$res" == "" ] || err $LINENO

res=$(echo "echo \$(( 2 ** 10 ))" | $com)
[ "$res" == "1024" ] || err $LINENO

res=$(echo "echo \$(( 10000 ** 0 ))" | $com)
[ "$res" == "1" ] || err $LINENO

res=$($com <<< 'echo $(( 1 ** -1  ))')
[ "$?" == "1" ] || err $LINENO
[ "$res" == "" ] || err $LINENO

res=$($com <<< 'A=1; echo $((A++ )); echo $A')
[ "$res" == "1
2" ] || err $LINENO

res=$($com <<< 'A=1; echo $(("A"++ )); echo $A')
[ "$res" == "1
2" ] || err $LINENO

res=$($com <<< 'A=1; echo $((++"A" )); echo $A')
[ "$res" == "2
2" ] || err $LINENO

res=$($com <<< 'A=1; echo $(("A"-- )); echo $A')
[ "$res" == "1
0" ] || err $LINENO

res=$($com <<< 'A=1; echo $(("A"--1 ))')
[ "$?" == "1" ] || err $LINENO

res=$($com <<< 'A=10; echo $(( ++"$A" )) ; echo $A')
[ "$res" == "10
10" ] || err $LINENO

res=$($com <<< 'A=10; echo $(( "$A"++ ))')
[ "$?" == "1" ] || err $LINENO

res=$($com <<< 'A=1; echo $(("A"\
--1 ))')
[ "$?" == "1" ] || err $LINENO

res=$($com <<< 'A=あああ; echo $((A++ ))')
[ "$?" == "1" ] || err $LINENO

#res=$($com <<< 'A=あああ; echo $((A++ )); echo $A')
#[ "$res" == "" ] || err $LINENO

res=$($com <<< 'A=5; echo $((A-- )); echo $A')
[ "$res" == "5
4" ] || err $LINENO

res=$($com <<< 'A=1; echo $((A++1 ))')
[ "$?" == "1" ] || err $LINENO
[ "$res" == "" ] || err $LINENO

res=$($com <<< 'A=1; echo $((A ++1 ))')
[ "$?" == "1" ] || err $LINENO
[ "$res" == "" ] || err $LINENO

res=$($com <<< 'A=1; echo $((A + +1 ))')
[ "$res" == "2" ] || err $LINENO

res=$($com <<< 'A=2; echo $((A+-1 ))')
[ "$res" == "1" ] || err $LINENO

res=$($com <<< 'A=1; echo $((2++1 ))')
[ "$res" == "3" ] || err $LINENO

res=$($com <<< 'A=1; echo $((2--1 ))')
[ "$res" == "3" ] || err $LINENO

res=$($com <<< 'echo $(( -- ))')
[ "$?" == "1" ] || err $LINENO

res=$($com <<< 'A=1; echo $(( 1 ++ A ))')
[ "$?" == "1" ] || err $LINENO

res=$($com <<< 'A=1; echo $(( 1 ++ A )); echo $A')
[ "$?" == "1" ] || err $LINENO
[ "$res" == "" ] || err $LINENO

res=$($com <<< 'A=1; echo $(("2""1"++1 ))')
[ "$res" == "22" ] || err $LINENO

res=$($com <<< 'A=1; echo $(("2"++1 ))')
[ "$res" == "3" ] || err $LINENO

res=$($com <<< 'A=1; echo $((++2++1 ))')
[ "$res" == "3" ] || err $LINENO

res=$($com <<< 'A=10 ; echo $(( ++A)); echo $A')
[ "$res" == "11
11" ] || err $LINENO

res=$($com <<< 'A=10 ; echo $(( ++"A")); echo $A')
[ "$res" == "11
11" ] || err $LINENO

res=$($com <<< 'A=B ; echo $(( ++$A)); echo $A')
[ "$res" == "1
B" ] || err $LINENO

res=$($com <<< 'A=10 ; echo $(( -- A)); echo $A')
[ "$res" == "9
9" ] || err $LINENO

res=$($com <<< 'A=10 ; echo $(( - - A)); echo $A')
[ "$res" == "10
10" ] || err $LINENO

res=$($com <<< 'A=10 ; echo $(( ++A++))')
[ "$?" == "1" ] || err $LINENO
[ "$res" == "" ] || err $LINENO

res=$($com <<< 'A=1; echo $(( === ))')
[ "$?" == "1" ] || err $LINENO
[ "$res" == "" ] || err $LINENO

res=$($com <<< 'echo $(($$ / $$ ))')
[ "$res" == "1" ] || err $LINENO

res=$($com <<< 'echo $(( ! 123 )) $(( ! 0 ))')
[ "$res" == "0 1" ] || err $LINENO

res=$($com <<< 'echo $(( ~ 0 )) $(( ~ 1 )) $(( ~ -1 ))')
[ "$res" == "-1 -2 0" ] || err $LINENO

res=$($com <<< 'echo $(( 10 %3 )) $(( 10 %-3 )) $(( $$ % 1 ))')
[ "$res" == "1 1 0" ] || err $LINENO

res=$($com <<< 'echo $(( 10 % 0 ))')
[ "$?" == "1" ] || err $LINENO
[ "$res" == "" ] || err $LINENO

res=$($com <<< 'echo $(( 1 << 1 )) $(( 1 << 10 )) $(( 1024 >> 2 ))')
[ "$res" == "2 1024 256" ] || err $LINENO

res=$($com <<< 'echo $(( 1 << -1 )) $(( 1 << -10 )) $(( 1024 >> -2 ))')
[ "$res" == "0 0 0" ] || err $LINENO

res=$($com <<< 'echo $(( 1 <= -1 )) $(( 1 >= -10 )) $(( 1024 > -2 )) $(( 1 < 3 ))')
[ "$res" == "0 1 1 1" ] || err $LINENO

res=$($com <<< 'echo $(( 1 <= 1 )) $(( 1 >= 1 )) $(( 1 > 1 )) $(( 1 < 1 ))')
[ "$res" == "1 1 0 0" ] || err $LINENO

res=$($com <<< 'echo $(( 3*1 <= 2 )) $(( 1 >= 1+4 ))')
[ "$res" == "0 0" ] || err $LINENO

res=$($com <<< 'echo $(( 1+1 == 2 )) $(( 1+1 != 2*1 ))')
[ "$res" == "1 0" ] || err $LINENO

res=$($com <<< 'echo $(( 1+1 & 2 )) $(( 1 ^ 2 )) $(( 3 ^ 1 )) $(( 1 & 2 )) $(( 2 | 1 )) ')
[ "$res" == "2 3 2 0 3" ] || err $LINENO

res=$($com <<< 'echo $((1+1&2)) $((1^2)) $((3^1)) $((1&2)) $((2|1)) ')
[ "$res" == "2 3 2 0 3" ] || err $LINENO

res=$($com <<< 'echo $(( 1+1 & -1 )) $(( 1 ^ -2 )) $(( 1 & -2 ))')
[ "$res" == "2 -1 0" ] || err $LINENO

res=$($com <<< 'echo $((123 && -1 )) $(( 0 && 10 )) $(( 0 || -1 || 0 )) $(( 0 || 0  )) $(( 0 && 0))')
[ "$res" == "1 0 1 0 0" ] || err $LINENO

res=$($com<<<'echo $((123&&-1))$((0&&10))$((0||-1||0))$((0||0))$((0&&0))')
[ "$res" == "10100" ] || err $LINENO

res=$($com <<< 'echo $(( 1? 20 : 30  )) $(( -5 + 5 ? 100 :  200))')
[ "$res" == "20 200" ] || err $LINENO

res=$($com <<< 'echo $(( (1? 20 : 30 ) + 3 )) $(( -5 + ( 5 ? 100 :  200)))')
[ "$res" == "23 95" ] || err $LINENO

res=$($com <<< 'echo $(( -(0? 20 : 30 ) * 3 )) $(( -5 + ( 5 ? 100 :  200)/5 ))')
[ "$res" == "-90 15" ] || err $LINENO

res=$($com <<< 'echo $(( A= 10 ))')
[ "$res" == "10" ] || err $LINENO

res=$($com <<< 'A=1 ; echo $(( A += 10 ))')
[ "$res" == "11" ] || err $LINENO

res=$($com <<< 'A=1 ; echo $(( A -= 10 ))')
[ "$res" == "-9" ] || err $LINENO

res=$($com <<< 'A=1 ; echo $(( A -= 10 + 2 )) $((A-=10+2))')
[ "$res" == "-11 -23" ] || err $LINENO

res=$($com <<< 'A=2 ; echo $(( A *= 10 + 2 )) $((A*=10+2))') 
[ "$res" == "24 288" ] || err $LINENO

res=$($com <<< 'A=-100 ; echo $(( A /= 10 + 2 )) $((A/=10+2))')
[ "$res" == "-8 0" ] || err $LINENO

res=$($com <<< 'A=-100 ; echo $(( A %= 10 + 2 )) $((A%=10+2))')
[ "$res" == "-4 -4" ] || err $LINENO

res=$($com <<< 'A=2 ; echo $(( A <<= 2 )) $((A<<=2)) $(( A <<= -1 ))')
[ "$res" == "8 32 0" ] || err $LINENO

res=$($com <<< 'A=-8 ; echo $(( A >>= 2 )) $((A>>=1)) $(( A >>= -1 ))')
[ "$res" == "-2 -1 0" ] || err $LINENO

res=$($com <<< 'A=-8 ; echo $((A^=2)) $((A&=1)) $((A|=-1))')
[ "$res" == "-6 0 -1" ] || err $LINENO

res=$($com <<< 'echo $((A=-8, A^=2)) $((A=3,A&=1)) $((A=9 ,A|=-1))')
[ "$res" == "-6 1 -1" ] || err $LINENO

res=$($com <<< 'echo $(( -" 12" )) $(( - "- 14" ))')
[ "$res" == "-12 14" ] || err $LINENO

res=$($com <<< 'echo $(( -"1 2" ))')
[ "$?" == "1" ] || err $LINENO
[ "$res" == "" ] || err $LINENO

res=$($com <<< 'echo $(( 0x11 )) $(( -"0x11" )) $(( - "- 0x11" ))')
[ "$res" == "17 -17 17" ] || err $LINENO

res=$($com <<< 'A=0x11; echo $(( A ))')
[ "$res" == "17" ] || err $LINENO

res=$($com <<< 'echo $(( -"011" )) $(( - "- 011" ))')
[ "$res" == "-9 9" ] || err $LINENO

res=$($com <<< 'echo $(( -"2#011" )) $(( - "- 2#0111101" ))')
[ "$res" == "-3 61" ] || err $LINENO

res=$($com <<< 'echo $(( 64#a )) $(( 64#A ))')
[ "$res" == "10 36" ] || err $LINENO

res=$($com <<< 'echo $(( 0xA )) $(( 0Xa ))')
[ "$res" == "10 10" ] || err $LINENO

res=$($com <<< 'echo $(( 17#A )) $(( 17#a ))')
[ "$res" == "10 10" ] || err $LINENO

res=$($com <<< 'echo $(( 37#A )) $(( 37#a ))')
[ "$res" == "36 10" ] || err $LINENO

res=$($com <<< 'echo $(( 64#@ )) $(( 64#_ ))')
[ "$res" == "62 63" ] || err $LINENO

res=$($com <<< 'echo $(( 62#@ ))')
[ "$?" == "1" ] || err $LINENO

res=$($com <<< 'echo $(( 65#0 ))')
[ "$?" == "1" ] || err $LINENO

res=$($com <<< 'echo $(([#2] 1023)) $(( [#64]1023 )) $(([##64] 65279)) $(([#8] 64))')
[ "$res" == "2#1111111111 64#f_ fX_ 8#100" ] || err $LINENO

## float number calculation (sush original)

res=$($com <<< 'echo $((12345.0 ))aaa')
[ "$res" == "12345aaa" ] || err $LINENO

res=$($com <<< 'echo $((12345.01 ))aaa')
[ "$res" == "12345.01aaa" ] || err $LINENO

res=$($com <<< 'echo $((123.0 + 456.0))')
[ "$res" == "579" ] || err $LINENO

res=$($com <<< 'echo $((123 +456.0))')
[ "$res" == "579" ] || err $LINENO

res=$($com <<< 'echo $((123 + 456 + 1.1))')
[ "$res" == "580.1" ] || err $LINENO

res=$($com <<< 'echo $((123 + +456.2))')
[ "$res" == "579.2" ] || err $LINENO

res=$($com <<< 'echo $((456 + -123.9))')
[ "$res" == "332.1" ] || err $LINENO

res=$($com <<< 'echo $((- - - 1.09))')
[ "$res" == "-1.09" ] || err $LINENO

res=$($com <<< 'echo $((- (1 + 2.1 )))')
[ "$res" == "-3.1" ] || err $LINENO

res=$($com <<< 'echo $(( 1 + 2 * 3.2 ))')
[ "$res" == "7.4" ] || err $LINENO

res=$($com <<< 'echo $(( 1 + 2.0 / 3 )) $(( 1 + 2 / 3.0 ))')
[ "$res" == "1.6666666666666665 1.6666666666666665" ] || err $LINENO

res=$($com <<< 'echo $(( (1 + 2.0) / 3 ))')
[ "$res" == "1" ] || err $LINENO

res=$($com <<< 'A=1.23; echo $((A ))')
[ "$res" == "1.23" ] || err $LINENO

res=$($com <<< 'A=1.34; echo $(( $A ))')
[ "$res" == "1.34" ] || err $LINENO

res=$($com <<< 'echo $(( $$ - 1.1 ))')
[ "$?" == "0" ] || err $LINENO

res=$($com <<< 'echo $((A + 3.1 ))')
[ "$res" == "3.1" ] || err $LINENO

res=$($com <<< 'A=X; X=3.1 ; echo $(( ++A )); echo $A')
[ "$res" == "4.1
4.1" ] || err $LINENO

res=$(echo "echo \$(( 2.1 ** 10 ))" | $com)
[ "$res" == "1667.9880978201006" ] || err $LINENO

res=$(echo "echo \$(( 2.1 ** 3.3 ))" | $com)
[ "$res" == "11.569741950241465" ] || err $LINENO

res=$(echo "echo \$(( 1.23 ** 0 ))" | $com)
[ "$res" == "1" ] || err $LINENO

res=$($com <<< 'echo $(( 1.23 ** -1.1  ))')
[ "$?" == "1" ] || err $LINENO
[ "$res" == "" ] || err $LINENO

res=$($com <<< 'A=1.2; echo $((A++ )); echo $A')
[ "$res" == "1.2
2.2" ] || err $LINENO

res=$($com <<< 'A=1.3; echo $(("A"++ )); echo $A')
[ "$res" == "1.3
2.3" ] || err $LINENO

res=$($com <<< 'A=1.1; echo $((++"A" )); echo $A')
[ "$res" == "2.1
2.1" ] || err $LINENO

res=$($com <<< 'A=1.9; echo $(("A"-- )); echo $A')
[ "$res" == "1.9
0.8999999999999999" ] || err $LINENO

res=$($com <<< 'A=10.1; echo $(( ++"$A" )) ; echo $A')
[ "$res" == "10.1
10.1" ] || err $LINENO

res=$($com <<< 'A=5.1; echo $((A-- )); echo $A')
[ "$res" == "5.1
4.1" ] || err $LINENO

res=$($com <<< 'A=1.1; echo $((A + +1 ))')
[ "$res" == "2.1" ] || err $LINENO

res=$($com <<< 'A=2.2; echo $((A+-1 ))')
[ "$res" == "1.2000000000000002" ] || err $LINENO

res=$($com <<< 'A=1; echo $((2++1.9 ))')
[ "$res" == "3.9" ] || err $LINENO

res=$($com <<< 'A=1; echo $(("2""1"".9"++1 ))')
[ "$res" == "22.9" ] || err $LINENO

res=$($com <<< 'A=1; echo $((++2++1.2 ))')
[ "$res" == "3.2" ] || err $LINENO

res=$($com <<< 'echo $(( ! 123.1 ))')
[ "$?" == "1" ] || err $LINENO

res=$($com <<< 'echo $(( ~ 0.2 ))')
[ "$?" == "1" ] || err $LINENO

res=$($com <<< 'echo $(( 10.1 %3 ))')
[ "$?" == "1" ] || err $LINENO

res=$($com <<< 'echo $(( 10 %3.1 ))')
[ "$?" == "1" ] || err $LINENO

res=$($com <<< 'echo $(( 1.1 << 1 ))')
[ "$?" == "1" ] || err $LINENO

res=$($com <<< 'echo $(( 1 << 1.1 ))')
[ "$?" == "1" ] || err $LINENO

res=$($com <<< 'echo $(( 1.1 <= -1.1 )) $(( 1.1 >= -10.1 )) $(( 1024 > -2.2 )) $(( 1 < 3.2 ))')
[ "$res" == "0 1 1 1" ] || err $LINENO

res=$($com <<< 'echo $(( 1.01 <= 1.01 )) $(( 1.01 >= 1.01 )) $(( 1.01 > 1.01 )) $(( 1.01 < 1.01 ))')
[ "$res" == "1 1 0 0" ] || err $LINENO

res=$($com <<< 'echo $(( 3*1.1 <= 3.2 )) $(( 1.1 >= 1+4 ))')
[ "$res" == "0 0" ] || err $LINENO

res=$($com <<< 'echo $(( 1+1.1 == 2.1 )) $(( 1.1+1.1 != 2*1.1 ))')
[ "$res" == "1 0" ] || err $LINENO

res=$($com <<< 'echo $(( 1+1 & 2.1 ))')
[ "$?" == "1" ] || err $LINENO

res=$($com <<< 'echo $((123 && -1.2 ))')
[ "$?" == "1" ] || err $LINENO

res=$($com <<< 'echo $(( 1.0 ? 20 : 30  ))')
[ "$?" == "1" ] || err $LINENO

res=$($com <<< 'echo $(( -(0? 20 : 30.3 ) * 3 )) $(( -5 + ( 5 ? 100.5 :  200)/5 ))')
[ "$res" == "-90.9 15.100000000000001" ] || err $LINENO

res=$($com <<< 'echo $(( A= 10.1 ))')
[ "$res" == "10.1" ] || err $LINENO

res=$($com <<< 'A=1.1 ; echo $(( A += 10 ))')
[ "$res" == "11.1" ] || err $LINENO

res=$($com <<< 'A=1 ; echo $(( A -= 10.1 ))')
[ "$res" == "-9.1" ] || err $LINENO

res=$($com <<< 'A=1.1 ; echo $(( A -= 10 + 2 )) $((A-=10+2))')
[ "$res" == "-10.9 -22.9" ] || err $LINENO

res=$($com <<< 'A=2.2 ; echo $(( A *= 10 + 2 )) $((A*=10+2))') 
[ "$res" == "26.400000000000002 316.8" ] || err $LINENO

res=$($com <<< 'A=-100.2 ; echo $(( A /= 10 + 2 )) $((A/=10+2))')
[ "$res" == "-8.35 -0.6958333333333333" ] || err $LINENO

res=$($com <<< 'A=-100.2 ; echo $(( A %= 10 + 2 ))')
[ "$?" == "1" ] || err $LINENO

res=$($com <<< 'A=2.2 ; echo $(( A <<= 2 ))')
[ "$?" == "1" ] || err $LINENO

res=$($com <<< 'A=-8.1 ; echo $((A^=2))')
[ "$?" == "1" ] || err $LINENO

res=$($com <<< 'echo $(( -" 12.3" )) $(( - "- 14.4" ))')
[ "$res" == "-12.3 14.4" ] || err $LINENO

res=$($com <<< 'echo $(( 0x11.2 ))')
[ "$?" == "1" ] || err $LINENO

res=$($com <<< 'echo $(( -" .3" )) $(( - "- .4" ))')
[ "$res" == "-0.3 0.4" ] || err $LINENO

# escaping

res=$($com <<< "echo a\ \ \ a")
[ "$res" == "a   a" ] || err $LINENO

res=$($com <<< 'echo \(')
[ "$res" == "(" ] || err $LINENO

# quotation

res=$($com <<< "echo 'abc'")
[ "$res" == "abc" ] || err $LINENO

res=$($com <<< "echo 'abあいうc'")
[ "$res" == "abあいうc" ] || err $LINENO

res=$($com <<< "echo 123'abc'")
[ "$res" == "123abc" ] || err $LINENO

res=$($com <<< "echo 123'abc'def")
[ "$res" == "123abcdef" ] || err $LINENO

# parameter expansion

res=$($com <<< 'echo $')
[ "$res" == "$" ] || err $LINENO

res=$($com <<< 'echo $?')
[ "$res" == "0" ] || err $LINENO

res=$($com <<< 'echo ${?}')
[ "$res" == "0" ] || err $LINENO

res=$($com <<< 'ls aaaaaaaa ; echo $?')
[ "$res" != "0" ] || err $LINENO

res=$($com <<< 'echo $BASH{PID,_SUBSHELL} | sed -E "s@[0-9]+@num@"')
[ "$res" == "num 0" ] || err $LINENO

res=$($com <<< 'echo ${BASHPID} ${BASH_SUBSHELL} | sed -E "s@[0-9]+@num@"')
[ "$res" == "num 0" ] || err $LINENO

res=$($com <<< 'echo ${ ')
[ "$?" == "2" ] || err $LINENO
[ "$res" == "" ] || err $LINENO

res=$($com <<< 'echo ${ A}')
[ "$?" == "1" ] || err $LINENO
[ "$res" == "" ] || err $LINENO

res=$($com <<< 'echo ${A }')
[ "$?" == "1" ] || err $LINENO
[ "$res" == "" ] || err $LINENO

res=$($com <<< 'echo ${_A32523j2}')
[ "$?" == "0" ] || err $LINENO
[ "$res" == "" ] || err $LINENO

res=$($com <<< 'echo ${_A32*523j2}')
[ "$?" == "1" ] || err $LINENO
[ "$res" == "" ] || err $LINENO

res=$($com <<< 'set a b c;echo $@')
[ "$res" == "a b c" ] || err $LINENO

# tilde

res=$($com <<< 'echo ~ | grep -q /')
[ "$?" == "0" ] || err $LINENO

res=$($com <<< 'echo ~root')
[ "$res" == "/root" -o "$res" == "/var/root" ] || err $LINENO

res=$($com <<< 'cd /; cd /etc; echo ~+; echo ~-')
[ "$res" == "/etc
/" ] || err $LINENO

# wildcard

res=$($com <<< 'echo /bin/?' | grep -F '/bin/[')
[ "$?" == "0" ] || err $LINENO

res=$($com <<< 'echo /*' | grep '/etc')
[ "$?" == 0 ] || err $LINENO

res=$($com <<< 'echo ~+/*' | grep '*')
[ "$?" == 1 ] || err $LINENO

res=$($com <<< 'echo ~/*' | grep -F '/.')
[ "$?" == 1 ] || err $LINENO

res=$($com <<< 'echo ~/.*' | grep -F '/.')
[ "$?" == 0 ] || err $LINENO

res=$($com <<< 'echo /etc*/' | grep -F '/etc/')
[ "$?" == 0 ] || err $LINENO

res=$($com <<< 'echo .*' | grep -F './.')
[ "$?" == 1 ] || err $LINENO

res=$($com <<< 'echo ./*' | grep -F './')
[ "$?" == "0" ] || err $LINENO

res=$($com <<< 'echo *"$PATH"')
[ "$?" == "0" ] || err $LINENO

res=$($com <<< 'echo /*"b"*' | grep -F '*')
[ "$?" == "1" ] || err $LINENO

res=$($com <<< "echo /*'b'*" | grep -F '*')
[ "$?" == "1" ] || err $LINENO

res=$($com <<< 'echo /"*"' | grep -F '*')
[ "$?" == "0" ] || err $LINENO

res=$($com <<< 'echo @(あ|{い,う,})')
[ "$res" == "@(あ|い) @(あ|う) @(あ|)" ] || err $LINENO

# split

export RUSTY_BASH_A='a
b'
res=$($com <<< 'echo $RUSTY_BASH_A')
[ "$res" == "a b" ] || err $LINENO

export RUSTY_BASH_A='a
b'
res=$($com <<< 'echo $RUSTY_BASH_A$RUSTY_BASH_A')
[ "$res" == "a ba b" ] || err $LINENO

export RUSTY_BASH_A='a
b'
res=$($com <<< 'echo ${RUSTY_BASH_A}c')
[ "$res" == "a bc" ] || err $LINENO

export RUSTY_BASH_A='a
b
'
res=$($com <<< 'echo ${RUSTY_BASH_A}c')
[ "$res" == "a b c" ] || err $LINENO

res=$($com <<< 'mkdir -p tmp; cd tmp; echo .* | grep -F ". .."; cd ..; rmdir tmp')
[ "$res" == '. ..' ] || err $LINENO

res=$($com <<< 'mkdir tmp; cd tmp; echo .*/ | grep -F "../ ./"; cd ..; rmdir tmp')
[ "$res" == '../ ./' ] || err $LINENO

# command expansion

res=$($com <<< 'echo a$(seq 2)b')
[ "$res" == "a1 2b" ] || err $LINENO

res=$($com <<< 'echo a$()b')
[ "$res" == "ab" ] || err $LINENO

res=$($com <<< 'echo "a$(seq 2)b"')
[ "$res" == "a1
2b" ] || err $LINENO

res=$($com <<< 'echo $(pwd)')
[ "$res" == "$(pwd)" ] || err $LINENO

res=$($com <<< 'echo $(pwd) a')
[ "$res" == "$(pwd) a" ] || err $LINENO

res=$($com <<< 'echo {,,}$(date "+%w")')
[ "$res" == "$(echo {,,}$(date "+%w"))" ] || err $LINENO

res=$($com <<< 'echo $(date) | grep "  "')
[ "$?" == "1" ] || err $LINENO

# array

res=$($com <<< 'A=( a b ); echo ${A[1]}')
[ "$res" == "b" ] || err $LINENO

res=$($com <<< 'A=( a b ); echo ${A[@]}')
[ "$res" == "a b" ] || err $LINENO

# symbol

res=$($com <<< 'echo ]')
[ "$res" == "]" ] || err $LINENO

### WHILE TEST ###

res=$($com <<< 'touch /tmp/rusty_bash ; while [ -f /tmp/rusty_bash ] ; do echo wait ; rm /tmp/rusty_bash ; done > /tmp/rusty_bash1'; cat /tmp/rusty_bash1 ; cat /tmp/rusty_bash1 )
[ "$res" == "wait
wait" ] || err $LINENO

### FOR TEST ###

res=$($com <<< 'set a b c ; for x ; do echo $x ; done')
[ "$res" == "a
b
c" ] || err $LINENO

res=$($com <<< 'set a b c ; for x
do echo $x ; done')
[ "$res" == "a
b
c" ] || err $LINENO

res=$($com <<< 'for x in a b c ; do echo $x ; done')
[ "$res" == "a
b
c" ] || err $LINENO

res=$($com <<< 'for x in a{b,c} d ; do echo $x ; done')
[ "$res" == "ab
ac
d" ] || err $LINENO

res=$($com <<< 'set a b c ; for x in "$*" ; do echo $x ; done; for x in $* ; do echo $x ; done')
[ "$res" == "a b c
a
b
c" ] || err $LINENO

res=$($com <<< 'for ((${ } ; ; )) ; do echo ; done')
[ "$?" == "1" ] || err $LINENO

res=$($com <<< 'for ((i=0 ; i<2 ; i++ )) ; do echo a ; done')
[ "$res" == "a
a" ] || err $LINENO

### IF TEST ###
res=$($com <<< 'if true ; then ; fi')
[ "$?" == "2" ] || err $LINENO

res=$($com <<< 'if ; then true ; fi')
[ "$?" == "2" ] || err $LINENO

res=$($com <<< 'if [ "a" == "a" ] ; then echo aa; fi')
[ "$res" = "aa" ] || err $LINENO

res=$($com <<< 'if [ "a" == "b" ] ; then echo aa; else echo bb; fi')
[ "$res" = "bb" ] || err $LINENO

res=$($com <<< 'if [ "a" == "b" ] ; then echo aa; fi' || echo x)
[ "$res" = "x" ] || err $LINENO

res=$($com <<< 'if [ "a" == "b" ] ; then echo a ; fi ; if [ "b" == "b" ] ; then echo bb ; fi')
[ "$res" = "bb" ] || err $LINENO

res=$($com <<< 'echo file > /tmp/rusty_bash; if [ "a" == "a" ] ; then echo aa; fi >> /tmp/rusty_bash; cat /tmp/rusty_bash')
[ "$res" = "file
aa" ] || err $LINENO

res=$($com <<< 'if [ "a" == "b" ] ; then echo aa; elif [ "b" == "c" ] ; then echo bb; else echo cc; fi')
[ "$res" = "cc" ] || err $LINENO

res=$($com <<< 'if [ "a" == "b" ] ; then echo aa; elif [ "b" == "c" ] ; then echo bb; elif [ "c" = "c" ] ; then echo cc ; else echo dd; fi')
[ "$res" = "cc" ] || err $LINENO

res=$($com <<< 'if [ "a" == "a" ] ; then echo aa; elif [ "b" == "c" ] ; then echo bb; else echo cc; fi')
[ "$res" = "aa" ] || err $LINENO

res=$($com <<< 'if [ "a" == "b" ] ; then echo aa; elif [ "b" == "b" ] ; then echo bb; else echo cc; fi')
[ "$res" = "bb" ] || err $LINENO

res=$($com <<< 'if [ "a" == "b" ] ; then echo aa; elif [ "b" == "b" ] ; then echo bb; fi')
[ "$res" = "bb" ] || err $LINENO

res=$($com << 'EOF'
if
false
then
echo hoge
elif
false
then
echo hoge
elif
false
then
echo hoge
else
echo true
fi
EOF
)
[ "$res" = "true" ] || err $LINENO

res=$($com << 'EOF'
if false ; then echo hoge
elif false ; then
echo hoge
elif false ;then echo hoge
else
echo true
echo hoge
fi
EOF
)
[ "$res" = "true
hoge" ] || err $LINENO

res=$($com << 'EOF'
if false ;then echo hoge
else
echo true
echo hoge
fi
EOF
)
[ "$res" = "true
hoge" ] || err $LINENO

res=$($com << 'EOF'
if true ;then
echo true
echo hoge
fi
EOF
)
[ "$res" = "true
hoge" ] || err $LINENO

res=$($com << 'EOF'
if false ;then
echo a
elif true ;then
echo x
echo y
else
echo true
echo hoge
fi
EOF
)
[ "$res" = "x
y" ] || err $LINENO

res=$($com << 'EOF'
if true ;then
    if true ;then
	echo a
    fi
fi
EOF
)
[ "$res" = "a" ] || err $LINENO

res=$($com << 'EOF'
if true ;then
    if true ;then
	echo a
	echo a
    fi
fi
EOF
)
[ "$res" = "a
a" ] || err $LINENO

res=$($com << 'EOF'
if true ;then
    if true ;then
	echo a
    fi
    echo a
fi
EOF
)
[ "$res" = "a
a" ] || err $LINENO


### CASE TEST ###

res=$($com <<< 'case aaa in bbb) echo NG ;; aaa) echo OK ;; esac')
[ "$res" = "OK" ] || err $LINENO

res=$($com <<< 'case aaa in bbb | aaa) echo OK ;; aaa) echo NG ;; esac')
[ "$res" = "OK" ] || err $LINENO

res=$($com <<< 'case aaa in | aaa) echo OK ;; aaa) echo NG ;; esac')
[ "$?" = "2" ] || err $LINENO

res=$($com <<< 'case aaa in bbb) echo NG ;; aaa) echo OK ;; aaa) echo OK ;; esac')
[ "$res" = "OK" ] || err $LINENO

res=$($com <<< 'case aaa in bbb) echo NG ;; aaa) echo OK ;& aaa) echo OK ;; esac')
[ "$res" = "OK
OK" ] || err $LINENO

res=$($com <<< 'case aaa in bbb) echo NG ;; aaa) echo OK ;;& aaa) echo OK ;; esac')
[ "$res" = "OK
OK" ] || err $LINENO

res=$($com <<< 'case aaa in aaa) echo OK1 ;;& bbb) echo OK2 ;& aaa) echo OK3 ;; esac')
[ "$res" = "OK1
OK3" ] || err $LINENO

res=$($com <<< 'case aaa in aaa) echo OK1 ;& bbb) echo OK2 ;& aaa) echo OK3 ;; esac')
[ "$res" = "OK1
OK2
OK3" ] || err $LINENO

res=$($com <<< 'case aaa in bbb) echo OK1 ;& bbb) echo OK2 ;& aaa) echo OK3 ;; esac')
[ "$res" = "OK3" ] || err $LINENO

res=$($com <<< 'case aaa in bbb) echo OK1 ;& aaa) echo OK2 ;& aaa) echo OK3 ;; esac')
[ "$res" = "OK2
OK3" ] || err $LINENO

res=$($com <<< 'case aaa in bbb) echo OK1 ;& aaa) echo OK2 ;& bbb) echo OK3 ;; esac')
[ "$res" = "OK2
OK3" ] || err $LINENO

res=$($com <<< 'case aaa in bbb) echo OK1 ;& bbb) echo OK2 ;& bbb) echo OK3 ;; esac')
[ "$res" = "" ] || err $LINENO

res=$($com <<< 'echo ; case $? in 1) echo NG ;; 0) echo OK ;; esac')
[ "$res" = "
OK" ] || err $LINENO

res=$($com <<< 'case aaa in bbb) echo NG ;; a\aa) echo OK ;; esac')
[ "$res" = "OK" ] || err $LINENO

res=$($com <<< 'case aaa in bbb) echo NG ;; a\aa\ ) echo OK ;; esac')
[ "$res" = "" ] || err $LINENO

res=$($com <<< 'case 山 in kawa) echo NG ;; 山) echo OK ;; esac')
[ "$res" = "OK" ] || err $LINENO

res=$($com <<< 'case aaa in b*) echo NG ;; *) echo OK ;; esac')
[ "$res" = "OK" ] || err $LINENO

res=$($com <<< 'case aaa in ...) echo NG ;; *) echo OK ;; esac')
[ "$res" = "OK" ] || err $LINENO

res=$($com <<< 'case ... in aa) echo NG ;; ...) echo OK ;; esac')
[ "$res" = "OK" ] || err $LINENO

res=$($com <<< 'case あ in ?) echo OK ;; あ) echo NG ;; esac')
[ "$res" = "OK" ] || err $LINENO

res=$($com <<< 'case あbiuoあああ in ?) echo NG ;; あ*) echo OK ;; esac')
[ "$res" = "OK" ] || err $LINENO

res=$($com <<< 'case yes in y[abcde]s) echo OK ;; *) echo NG ;; esac')
[ "$res" = "OK" ] || err $LINENO

res=$($com <<< 'case yes in y[abcde\]s) echo NG ;; *) echo OK ;; esac')
[ "$res" = "OK" ] || err $LINENO

res=$($com <<< 'case yes in y[^abcde]s) echo NG ;; *) echo OK ;; esac')
[ "$res" = "OK" ] || err $LINENO

res=$($com <<< 'case yes in y[^abcde]s) echo NG ;; *) echo OK ;; esac')
[ "$res" = "OK" ] || err $LINENO

res=$($com <<< 'case yes in y[\^abcde]s) echo OK ;; *) echo NG ;; esac')
[ "$res" = "OK" ] || err $LINENO

res=$($com <<< 'case $- in *i*) echo NG ;; *) echo OK ;; esac')
[ "$res" = "OK" ] || err $LINENO

res=$($com <<< 'case aaa in ?(a)aa) echo OK ;; *) echo NG ;; esac')
[ "$res" = "OK" ] || err $LINENO

res=$($com <<< 'case aa in ?(a)aa) echo OK ;; *) echo NG ;; esac')
[ "$res" = "OK" ] || err $LINENO

res=$($com <<< 'case baa in ?(a|b)aa) echo OK ;; *) echo NG ;; esac')
[ "$res" = "OK" ] || err $LINENO

res=$($com <<< 'case baa in @(a|b)aa) echo OK ;; *) echo NG ;; esac')
[ "$res" = "OK" ] || err $LINENO

res=$($com <<< 'case aa in @(a|b)aa) echo NG ;; *) echo OK ;; esac')
[ "$res" = "OK" ] || err $LINENO

res=$($com <<< 'case aa in @(a||b)aa) echo OK ;; *) echo NG ;; esac')
[ "$res" = "OK" ] || err $LINENO

res=$($com <<< 'case acaa in @(a|b|ac)aa) echo OK ;; *) echo NG ;; esac')
[ "$res" = "OK" ] || err $LINENO

res=$($com <<< 'case caa in !(a|b)aa) echo OK ;; *) echo NG ;; esac')
[ "$res" = "OK" ] || err $LINENO

res=$($com <<< 'case aa in !(a|b)aa) echo OK ;; *) echo NG ;; esac')
[ "$res" = "OK" ] || err $LINENO

res=$($com <<< 'case "" in !(a|b)aa) echo NG ;; *) echo OK ;; esac')
[ "$res" = "OK" ] || err $LINENO

res=$($com <<< 'case cccccccccccaa in !(a|b)aa) echo OK ;; *) echo NG ;; esac')
[ "$res" = "OK" ] || err $LINENO

res=$($com <<< 'case cccccccccccaa in *(a|b|c)aa) echo OK ;; *) echo NG ;; esac')
[ "$res" = "OK" ] || err $LINENO

res=$($com <<< 'case "" in *(a|b|c)) echo OK ;; *) echo NG ;; esac')
[ "$res" = "OK" ] || err $LINENO

res=$($com <<< 'case "" in +(a|b|c)) echo NG ;; *) echo OK ;; esac')
[ "$res" = "OK" ] || err $LINENO

res=$($com <<< 'case aa in *(a|b|c)aa) echo OK ;; *) echo NG ;; esac')
[ "$res" = "OK" ] || err $LINENO

res=$($com <<< 'case cccccccccccaa in +(a|b|c)aa) echo OK ;; *) echo NG ;; esac')
[ "$res" = "OK" ] || err $LINENO

res=$($com <<< 'case aa in +(a|b|c)aa) echo NG ;; *) echo OK ;; esac')
[ "$res" = "OK" ] || err $LINENO

res=$($com <<< 'case 山田山田aa in +(山|山本|山田)aa) echo OK ;; *) echo NG ;; esac')
[ "$res" = "OK" ] || err $LINENO

res=$($com <<< 'case 山aa in 山*(本|田)aa) echo OK ;; *) echo NG ;; esac')
[ "$res" = "OK" ] || err $LINENO

res=$($com <<< 'case 山aa in 山+(本||田)aa) echo OK ;; *) echo NG ;; esac')
[ "$res" = "OK" ] || err $LINENO

res=$($com <<< 'case 山aa in 山*(本||田)aa) echo OK ;; *) echo NG ;; esac')
[ "$res" = "OK" ] || err $LINENO

res=$($com <<< 'case 山aa in 山+(本|田)aa) echo NG ;; *) echo OK ;; esac')
[ "$res" = "OK" ] || err $LINENO

res=$($com <<< 'case 上山田山田aa in 上+(山|上山|山本|山田)aa) echo OK ;; *) echo NG ;; esac')
[ "$res" = "OK" ] || err $LINENO

res=$($com <<< 'case 小山田 in !(五反|山|小山)田) echo マッチ ;; *) echo マッチせず ;; esac')
[ "$res" = "マッチせず" ] || err $LINENO

res=$($com <<< 'case 山小田 in !(山)田) echo マッチ ;; *) echo マッチせず ;; esac')
[ "$res" = "マッチ" ] || err $LINENO

res=$($com <<< 'case 山小小小田 in !(山)田) echo マッチ ;; *) echo マッチせず ;; esac')
[ "$res" = "マッチ" ] || err $LINENO

res=$($com <<< 'shopt -u extglob; case baa in @(a|b)aa) echo OK ;; *) echo NG ;; esac')
[ "$res" = "NG" ] || err $LINENO

res=$($com <<< 'shopt -u extglob; case 山小小小田 in !(山)田) echo マッチ ;; *) echo マッチせず ;; esac')
[ "$res" = "マッチせず" ] || err $LINENO

### (( )) TEST ###

res=$($com <<< '(( 0 ))')
[ "$?" = "1" ] || err $LINENO

res=$($com <<< '(( 1 ))')
[ "$?" = "0" ] || err $LINENO

res=$($com <<< '(( 0 + 1 + 2-3 ))')
[ "$?" = "1" ] || err $LINENO

res=$($com <<< '(( 0 + 1 + 2+3 ))')
[ "$?" = "0" ] || err $LINENO

### OPTION TEST ###

res=$($com <<< 'set -e ; false ; echo NG')
[ "$res" != "NG" ] || err $LINENO

res=$($com <<< 'set -e ; false | true ; echo OK')
[ "$res" == "OK" ] || err $LINENO

res=$($com <<< 'set -e ; ( false ) ; echo NG')
[ "$res" != "NG" ] || err $LINENO

res=$($com <<< 'set -e ; false || echo OK')
[ "$res" == "OK" ] || err $LINENO

res=$($com <<< 'set -e ; false || false ; echo NG')
[ "$res" == "" ] || err $LINENO

res=$($com <<< 'set -e ; while false ; do echo NG ; done ; echo OK')
[ "$res" == "OK" ] || err $LINENO

res=$($com <<< 'set -o pipefail; ls aaaa | false | true')
[ "$?" == "1" ] || err $LINENO

res=$($com <<< 'set -o pipefail; set -e; false | true ; echo NG')
[ "$res" == "" ] || err $LINENO


wait 

head ./ok ./error

[ $(cat ./error | wc -l) == "0" ]  || err $LINENO

echo OK $0
