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
L25:	movq $65, %rax
L26:	movq %rax, %rdi
L27:	movq stdout(%rip), %rsi ; call _IO_putc@PLT
L28:	popq %rax
L29:	pushq %rax
L30:	movq $0, %rax
L31:	addq $8, %rsp
L32:	ret
L33:	
  
  	/* string_append */
L34:	subq $40, %rsp
L35:	pushq %rdi
L36:	jmp L39
L37:	jmp L48
L38:	jmp L52
L39:	pushq %rax
L40:	movq 8(%rsp), %rax
L41:	pushq %rax
L42:	movq $0, %rax
L43:	movq %rax, %rbx
L44:	popq %rdi
L45:	popq %rax
L46:	cmpq %rbx, %rdi ; je L37
L47:	jmp L38
L48:	pushq %rax
L49:	addq $56, %rsp
L50:	ret
L51:	jmp L90
L52:	pushq %rax
L53:	movq 8(%rsp), %rax
L54:	pushq %rax
L55:	movq $0, %rax
L56:	popq %rdi
L57:	addq %rax, %rdi
L58:	movq 0(%rdi), %rax
L59:	movq %rax, 40(%rsp) 
L60:	popq %rax
L61:	pushq %rax
L62:	movq 8(%rsp), %rax
L63:	pushq %rax
L64:	movq $8, %rax
L65:	popq %rdi
L66:	addq %rax, %rdi
L67:	movq 0(%rdi), %rax
L68:	movq %rax, 32(%rsp) 
L69:	popq %rax
L70:	pushq %rax
L71:	movq 32(%rsp), %rax
L72:	pushq %rax
L73:	movq 8(%rsp), %rax
L74:	popq %rdi
L75:	call L34
L76:	movq %rax, 24(%rsp) 
L77:	popq %rax
L78:	pushq %rax
L79:	movq 40(%rsp), %rax
L80:	pushq %rax
L81:	movq 32(%rsp), %rax
L82:	popq %rdi
L83:	call L0
L84:	movq %rax, 16(%rsp) 
L85:	popq %rax
L86:	pushq %rax
L87:	movq 16(%rsp), %rax
L88:	addq $56, %rsp
L89:	ret
