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
  
  L0:   movq $0, %rax
L1:     movq $16, %r12
L2:     movq $9223372036854775807, %r13
L3:     call L23
L4:     movq $0, %rdi
L5:     call exit@PLT
L6:
  
        /* malloc */
L7:     movq %r15, %rax
L8:     subq %r14, %rax
L9:     cmpq %r14, %r15 ; jb L15
L10:    cmpq %rdi, %rax ; jb L15
L11:    movq %r14, %rax
L12:    addq %rdi, %r14
L13:    ret
L14:
  
        /* exit4 */
L15:    pushq %r15
L16:    movq $4, %rdi
L17:    call exit@PLT
L18:
  
        /* exit1 */
L19:    pushq %r15
L20:    movq $1, %rdi
L21:    call exit@PLT
L22:
  
        /* 1835100526 */
L23:    subq $0, %rsp
L24:    pushq %rax
L25:    movq $65, %rax
L26:    movq %rax, %rdi
L27:    movq stdout(%rip), %rsi ; call _IO_putc@PLT
L28:    popq %rax
L29:    pushq %rax
L30:    movq $0, %rax
L31:    addq $8, %rsp
L32:    ret