	.text
	.file	"/b/build/slave/linux/build/src/buildbot/work/gcc/gcc/testsuite/gcc.c-torture/execute/20030209-1.c"
	.globl	main
	.type	main,@function
main:                                   # @main
	.result 	i32
	.local  	i32
# BB#0:                                 # %entry
	i32.const	$0=, 0
	i64.const	$push0=, 4631107791820423168
	i64.store	$discard=, x+79200($0), $pop0
	call    	exit, $0
	unreachable
.Lfunc_end0:
	.size	main, .Lfunc_end0-main

	.type	x,@object               # @x
	.bss
	.globl	x
	.align	4
x:
	.zero	80000
	.size	x, 80000


	.ident	"clang version 3.8.0 "
	.section	".note.GNU-stack","",@progbits