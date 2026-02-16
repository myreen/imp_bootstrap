	.bss
  	.p2align 3          /* 8-byte align        */
  heapS:
  	.space 8*1024*1024  /* bytes of heap space */
  	.p2align 3          /* 8-byte align        */
  heapE:
  
  	.text
  	.globl main
  main:
  	subq $8, %rsp        /* 16-byte align %rsp */
  	movabs $heapS, %r14  /* r14 := heap start  */
  	movabs $heapE, %r15  /* r15 := heap end    */
  
  L0:	movq $0, %rax
L1:	movq $16, %r12
L2:	movq $9223372036854775807, %r13
L3:	call L23
L4:	movq $0, %rdi
L5:	call exit@PLT
L6:	
  
  	/* malloc */
L7:	movq %r15, %rax
L8:	subq %r14, %rax
L9:	cmpq %r14, %r15 ; jb L15
L10:	cmpq %rdi, %rax ; jb L15
L11:	movq %r14, %rax
L12:	addq %rdi, %r14
L13:	ret
L14:	
  
  	/* exit4 */
L15:	pushq %r15
L16:	movq $4, %rdi
L17:	call exit@PLT
L18:	
  
  	/* exit1 */
L19:	pushq %r15
L20:	movq $1, %rdi
L21:	call exit@PLT
L22:	
  
  	/* main */
L23:	subq $0, %rsp
L24:	pushq %rax
L25:	movq $75, %rax
L26:	movq %rax, %rdi
L27:	movq stdout(%rip), %rsi ; call _IO_putc@PLT
L28:	popq %rax
L29:	pushq %rax
L30:	movq $97, %rax
L31:	movq %rax, %rdi
L32:	movq stdout(%rip), %rsi ; call _IO_putc@PLT
L33:	popq %rax
L34:	pushq %rax
L35:	movq $115, %rax
L36:	movq %rax, %rdi
L37:	movq stdout(%rip), %rsi ; call _IO_putc@PLT
L38:	popq %rax
L39:	pushq %rax
L40:	movq $105, %rax
L41:	movq %rax, %rdi
L42:	movq stdout(%rip), %rsi ; call _IO_putc@PLT
L43:	popq %rax
L44:	pushq %rax
L45:	movq $97, %rax
L46:	movq %rax, %rdi
L47:	movq stdout(%rip), %rsi ; call _IO_putc@PLT
L48:	popq %rax
L49:	pushq %rax
L50:	movq $10, %rax
L51:	movq %rax, %rdi
L52:	movq stdout(%rip), %rsi ; call _IO_putc@PLT
L53:	popq %rax
L54:	pushq %rax
L55:	movq $0, %rax
L56:	addq $8, %rsp
L57:	ret
L58:	ret
