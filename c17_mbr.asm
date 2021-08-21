         ;代码清单17-1
         ;文件名：c17_mbr.asm
         ;文件说明：硬盘主引导扇区代码 
         ;创建日期：2012-07-13 11:20
         
         core_base_address equ 0x00040000   ;常数，内核加载的起始内存地址 
         core_start_sector equ 0x00000001   ;常数，内核的起始逻辑扇区号 

;===============================================================================
SECTION  mbr  vstart=0x00007c00         

         ; --------------------------------------------------
         ; BIOS to MBR interface
         ; --------------------------------------------------
         ; cs:ip = 0x0000:0x7c00
         ; dl = boot drive unit
         ;  (fixed disks / removable drives: 0x80=first, 0x81=second, ..., 0xfe;
         ;  floppies / superfloppies: 0x00=first, 0x01=second, ..., 0x7e;
         ;  0xff, 0x7f are reserved for ROM / remote drives and must not be used on disk)
         ; dh bit 5 = 0

         ;设置堆栈段和栈指针 
         mov ax, cs
         mov ds, ax
         mov es, ax
         mov ss, ax
         mov sp, 0x7c00 ; sp = 0x7c00

         ;计算GDT所在的逻辑段地址
         mov eax,[cs:pgdt+0x02]             ; 取到存在标号 pgdt 处的 GDT 32位线性地址
         xor edx,edx                        ; 清空edx
         ; TODO 为什么要用 64/32，不用 32/16
         mov ebx,16
         div ebx                            ; 分解成16位逻辑地址 段地址在 EAX 段内偏移在 EDX

         mov ds,eax                         ; 令DS指向该段以进行操作
         mov ebx,edx                        ; 段内起始偏移地址 

         ;跳过0#号描述符的槽位
         ;创建1#描述符，保护模式下的代码段描述符
         ; ds:ebx -> GDT
         mov dword [ebx+0x08],0x0000ffff    ; 段基地址15-0位=0x0000 段界限15-0位=0xffff
         mov dword [ebx+0x0c],0x00cf9800    ; 段基地址31-24位=0x00 G=1 D/B=1 L=0 AVL=0 段界限19-16位=0xf P=1 DPL=00 S=1 TYPE=0x8 段基地址23-16位=0x00
         ; 总结: 段基地址=0x00000000 段界限=0xfffff 4KB粒度 默认操作数32位 代码段描述符，向上扩展

         ;创建2#描述符，保护模式下的数据段和堆栈段描述符 
         mov dword [ebx+0x10],0x0000ffff    ; 段基地址15-0位=0x0000 段界限15-0位=0xffff
         mov dword [ebx+0x14],0x00cf9200    ; 段基地址31-24位=0x00 G=1 D/B=1 L=0 AVL=0 段界限19-16位=0xf P=1 DPL=00 S=1 TYPE=0x2 段基地址23-16位=0x00
         ; 总结: 段基地址=0x00000000 段界限=0xfffff 4KB粒度 默认操作数32位 数据段描述符，向上扩展

         ;初始化描述符表寄存器GDTR
         mov word [cs:pgdt],23              ; 描述符表的界限 TODO 为什么是 23 自己定义的吗
 
         lgdt [cs: pgdt]                    ; 加载 GDT 的界限值和线性基地址到 GDTR
      
         in al,0x92                         ; 南桥芯片内的端口 读入原数据
         or al,000000_10B                   ; 7-2 位保留未用 第 0 位INIT_NOW，置一使处理器复位重新启动；第 1 位ALT_A20_GATE，置一开启A20
         out 0x92,al                        ; 打开A20

         cli                                ; 中断机制尚未工作 关中断
                                            ; 为什么要关: 下面将要进入保护模式，而保护模式下的BIOS中断都不能用，
                                            ; 因为它们都是实模式下的代码，而保护模式下的中断环境还没设置，所以要关中断

         mov eax,cr0                  
         or eax,1                           ; PE 位是 CR0 的 0 位
         mov cr0,eax                        ; 设置CR0 的 PE 位，处理器进入保护模式
      
         ;以下进入保护模式... ...
         jmp dword 0x0008:flush             ; 此时已经开始将操作数视为16位的描述符选择子 (描述符索引=0000000000001 TI=0 RPL=00)和32位偏移
                                            ; 清空流水线并串行化处理器 通过 GDT 跳转到代码段继续执行
         [bits 32]               
  flush:                                  
         mov eax,0x00010                    ; 加载数据段(4GB)选择子 描述符索引=0000000000010 TI=0 RPL=00
                                            ; DS ES FS GS SS 都初始化为数据段选择子
         mov ds,eax
         mov es,eax
         mov fs,eax
         mov gs,eax
         mov ss,eax                         ; 加载堆栈段(4GB)选择子 和数据段一样，但向下拓展 TODO 但是这个数据段段描述符里定义了它是向上拓展的？
         mov esp,0x7000                     ; 栈顶0x00007000 TODO 为什么定义在这个位置
         
         ;以下加载系统核心程序
         mov edi,core_base_address          ; 核心程序要放到的段内偏移 备份一份
         mov eax,core_start_sector          ; 核心程序在硬盘上的LBA
         mov ebx,edi                        ; 传入过程的参数 会被改变为核心程序段内偏移+512
         call read_hard_disk_0              ; eax=LBA, ds:ebx=核心程序在内存中的物理地址 以下读取程序的起始部分（一个扇区）

         ;以下判断整个程序有多大
         mov eax,[edi]                      ; 读取核心程序第一个扇区的头部一字 核心程序尺寸
         xor edx,edx
         mov ecx,512                        ; 512字节每扇区
         div ecx                            ; 计算核心程序扇区数

         or edx,edx                         ; 看 edx 是否为0，若为0则 ZF=1
         jnz @1                             ; 未除尽，直接用商作没读的扇区数，余数所在扇区和已经读的一个扇区抵消
         dec eax                            ; 余数为0，除尽，商减一作没读的扇区数，因为已经读了一个扇区

   @1:
         or eax,eax                         ; 看eax是否为0 考虑实际长度≤5512个字节的情况
         jz pge                             ; eax为0跳转

         ;读取剩余的扇区
         mov ecx,eax                        ; 32位模式下的LOOP使用ECX TODO 用cx不行吗
         mov eax,core_start_sector
         inc eax                            ; 从下一个逻辑扇区接着读
   @2:
         call read_hard_disk_0              ; eax=LBA, ds:ebx=核心程序在内存中的物理地址
         inc eax                            ; LBA++
         loop @2                            ; 循环读，直到读完整个内核

   pge:
         ;准备打开分页机制。从此，再也不用在段之间转来转去，实在晕乎~ 
         
         ;=======================================
         ; 将物理地址低端1MB映射到高端
         ; 所谓映射，就是将线性地址加0x80000000，但保证用这个线性地址能取到真正的物理地址
         ;=======================================
         ;创建系统内核的页目录表PDT 0x00020000 - 0x00021000
         ; 页目录表含有1024个页目录项，每个4字节，填写的是页表的物理地址
         mov ebx,0x00020000                 ; 页目录表PDT的物理地址 TODO 作常量定义更好？
         
         mov dword [ebx+4092],0x00020003    ;在页目录表尾部创建指向页目录表自己的目录项 页表物理基地址31-12=0x00020 AVL=000 G=0 D=0 A=0 PCD=0 PWT=0 US=0 RW=1 P=1

         ; 创建两个目录项 指向同一个页表
         ; MBR空间有限，后面尽量不使用立即数
         mov edx,0x00021003                 ; 页目录项: 页表物理基地址31-12=0x00021 AVL=000 G=0 D=0 A=0 PCD=0 PWT=0 US=0 RW=1 P=1
         mov [ebx+0x000],edx                ; 创建在页目录内创建与线性地址0x00000000对应的目录项
                                            ; 此目录项只在开启页功能时使用 仅用于过渡 TODO ?
         mov [ebx+0x800],edx                ; 创建在页目录内创建与线性地址0x80000000对应的目录项
                                            ; 0x80000000高10位10 0000 0000是页目录索引，每项4B，所以偏移=10 0000 0000*4=0x800

         ; 创建与上面那个目录项相对应的页表，初始化页表项
         mov ebx,0x00021000                 ; 页表的物理地址
         xor eax,eax                        ; eax 装的是页的物理地址 起始为0x00000000
         xor esi,esi
  .b1:       
         mov edx,eax
         or edx,0x00000003                  ; 页表项: 页物理基地址31-12=0x00000 AVL=000 G=0 PAT=0 D=0 A=0 PCD=0 PWT=0 US=0 RW=1 P=1                                  
         mov [ebx+esi*4],edx                ; 登记页的物理地址
         add eax,0x1000                     ; 下一个相邻页的物理地址 每个页4KB 物理地址相差0x1000
         inc esi
         cmp esi,256                        ; 登记从0x00000000开始的256个页面，即低端1MB空间，这是内核正常工作的基本要求
         jl .b1
         
         ; 将页目录表的物理基地址传送到CR3(页目录表基地址寄存器PDBR)
         mov eax,0x00020000                 ; 页目录物理基地址31-12=0x00020 PCD=0 PWT=0
         mov cr3,eax

         ; 将GDT的线性地址映射到从0x80000000开始的相同位置 
         sgdt [pgdt]                        ; 将 GDTR 中的 GDT 界限值和基地址读到该内存
         mov ebx,[pgdt+2]                   ; 将基地址读到ebx
         add dword [pgdt+2],0x80000000      ; 将pgdt中的基地址映射到高2GB端 
         lgdt [pgdt]                        ; 将pgdt加载回 GDTR

         ; CR0 31位是PG位 当它清零时，页功能被关闭，从段部件来的线性地址就是物理地址 当它置位时，页功能开启
         mov eax,cr0
         or eax,0x80000000                  ; 置位PG
         mov cr0,eax                        ; 开启分页机制

         ;将堆栈映射到高端，这是非常容易被忽略的一件事。应当把内核的所有东西
         ;都移到高端，否则，一定会和正在加载的用户任务局部空间里的内容冲突，
         ;而且很难想到问题会出在这里。 
         add esp,0x80000000                 ; 将内核栈映射到虚拟内存高端
                                             
         jmp [0x80040004]                   ; 从DS描述符缓存器中取出段线性基地址，加上偏移量0x80040004等于线性地址0x80040004 => 
                                            ; 高10位页目录索引=10 0000 0000  中间10位页表索引=00 0100 0000 低12位页内偏移=0000 0000 0100
                                            ; 页目录索引*4=0x800 => 找到页目录项 => 指向页表 => 页表索引*4=0x100 => 找到页的物理地址0x40000 + 页内偏移0x4 => jmp操作数所在的物理地址0x40004
                                            ; 而之前从硬盘读取的内核代码正是加载到0x40000处，而内核代码头部4字节是内核代码长度，跳过后是4个字节的内核代码入口点
                                            ; 注意！！！这里jmp是32位段内绝对相对近转移，CS不变！32位操作数直接赋给EIP
                                            ; EIP=start标号 比如0x80040005 取址时线性地址=CS描述符缓存+EIP=0x80040005 可见是一个映射到高端的线性地址
                                            ; 同上通过页部件将线性地址转化为物理地址0x40005 从而实现控制转移到内核

;-------------------------------------------------------------------------------
read_hard_disk_0:                           ;从硬盘读取一个逻辑扇区
                                            ;EAX=逻辑扇区号
                                            ;DS:EBX=目标缓冲区地址
                                            ;返回：EBX=EBX+512 
         push eax 
         push ecx
         push edx
      
         push eax                           ; 注意！不多余！
         
         mov dx,0x01f2                      ; 端口0x01f2 8位端口 接收要读取的扇区数量
         mov al,1
         out dx,al                          ;读取的扇区数

         ; 端口0x01f3 - 0x01f6 都是8位端口 用于接收 28 位起始 LBA 号
         inc dx                             ; 端口0x01f3 
         pop eax                            ; 这里pop了一个eax
         out dx,al                          ; LBA地址7~0

         inc dx                             ; 端口0x01f4
         mov cl,8
         shr eax,cl                         ; 右移 8 位
         out dx,al                          ; LBA地址15~8

         inc dx                             ; 端口0x01f5
         shr eax,cl                         ; 右移 8 位
         out dx,al                          ; LBA地址23~16

         inc dx                             ; 端口0x01f6
         shr eax,cl                         ; 右移 8 位
         or al,0xe0                         ; 高三位是111，表示LBA模式 第四位指示硬盘号，0表示主盘，1表示从盘 低四位=LBA地址27~24
         out dx,al

         inc dx                             ; 端口0x01f7 既是命令端口又是状态端口
         mov al,0x20                        ; 读命令，发送后硬盘开始传输数据
         out dx,al

  .waits:
         in al,dx                           ; 从端口0x01f7读取硬盘状态信息
         and al,0x88
         cmp al,0x08
         jnz .waits                         ; 陷入忙等，直到硬盘不忙且硬盘已准备好和主机交换数据

         mov ecx,256                        ; 总共要读取的字数
         mov dx,0x01f0                      ; 硬盘的16位数据端口
  .readw:
         in ax,dx
         mov [ebx],ax
         add ebx,2
         loop .readw

         pop edx
         pop ecx
         pop eax
      
         ret

;-------------------------------------------------------------------------------
         pgdt             dw 0              ; 存放 GDT 的界限值 供 lgdt 命令取用
                          dd 0x00008000     ; 存放 GDT 的线性地址 供 lgdt 命令取用
;-------------------------------------------------------------------------------                             
         times 510-($-$$) db 0
                          db 0x55,0xaa
