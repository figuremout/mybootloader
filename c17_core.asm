         ;�����嵥17-2
         ;�ļ�����c17_core.asm
         ;�ļ�˵��������ģʽ΢�ͺ��ĳ��� 
         ;�������ڣ�2012-07-12 23:15
;-------------------------------------------------------------------------------
         ;���¶��峣��
         flat_4gb_code_seg_sel  equ  0x0008      ;ƽ̹ģ���µ�4GB�����ѡ���� 
                                                 ; ����������=0000 0000 0000 1 TI=0 RPL=00
         flat_4gb_data_seg_sel  equ  0x0018      ;ƽ̹ģ���µ�4GB���ݶ�ѡ���� 
                                                 ; ����������=0000 0000 0001 1 TI=0 RPL=00
         idt_linear_address     equ  0x8001f000  ;�ж�������������Ի���ַ 
;-------------------------------------------------------------------------------          
         ;���¶����
         %macro alloc_core_linear 0              ; ���ں˿ռ��з��������ڴ�
                                                 ; ����һ�����Ե�ַ �����úø����Ե�ַ����Ӧ��ҳĿ¼��ҳ������ҳ
                                                 ; ����: ebx �˴η�����ں˵�ַ�ռ����Ե�ַ
               mov ebx,[core_tcb+0x06]           ; ebx=�ں�TCB�еĳ�����ػ���ַ(��һ���ɷ�������Ե�ַ)
               add dword [core_tcb+0x06],0x1000  ; Ϊ����� ÿ�����ں˿ռ��з����ڴ�ʱ ���̶�����һ��ҳ4KB
                                                 ; �������Ϊ�ں�TCB�еĳ�����ػ���ַ��4096
               call flat_4gb_code_seg_sel:alloc_inst_a_page
         %endmacro 
;-------------------------------------------------------------------------------
         %macro alloc_user_linear 0              ;������ռ��з��������ڴ� 
                                                 ; ���� esi �û������tcb���Ե�ַ
                                                 ; ��� ebx �����ҳ�����Ե�ַ
               mov ebx,[esi+0x06]
               add dword [esi+0x06],0x1000
               call flat_4gb_code_seg_sel:alloc_inst_a_page
         %endmacro
         
;===============================================================================
SECTION  core  vstart=0x80040000                 ; �ں�������ռ����Ǵ�0x00040000��ʼ���ص� (������mbr�ĳ���) 
                                                 ; ӳ�䵽�� 2GB ���� 0x80040000
 
         ;������ϵͳ���ĵ�ͷ�������ڼ��غ��ĳ��� 
         core_length      dd core_end       ; ���ĳ����ܳ��� �ֽ���#00

         core_entry       dd start          ; ���Ĵ������ڵ�#04 code_entry=0x80040004

;-------------------------------------------------------------------------------
         [bits 32]
;-------------------------------------------------------------------------------
         ;�ַ�����ʾ���̣�������ƽ̹�ڴ�ģ�ͣ� 
put_string:                                 ; ��ʾ0��ֹ���ַ������ƶ���� 
                                            ; ���룺EBX=�ַ��������Ե�ַ
                                            ; ����������̽���ʱ��sti �����������ж�ϵͳû����ɳ�ʼ��֮ǰ���ܵ����������

         push ebx
         push ecx

         cli                                ;Ӳ�������ڼ䣬���ж�

  .getc:
         mov cl,[ebx]                       ; ��ȡ�ַ�����8λ(һ���ַ�)
         or cl,cl                           ; ��⴮������־��0�� 
         jz .exit                           ; ��ʾ��ϣ����� 
         call put_char
         inc ebx
         jmp .getc

  .exit:

         sti                                ;Ӳ��������ϣ������ж�

         pop ecx
         pop ebx

         retf                               ;�μ䷵��

;-------------------------------------------------------------------------------
put_char:                                   ;�ڵ�ǰ��괦��ʾһ���ַ�,���ƽ�
                                            ;��ꡣ�����ڶ��ڵ��� 
                                            ;���룺CL=�ַ�ASCII�� 
         pushad

         ;����ȡ��ǰ���λ��
         mov dx,0x03d4                      ; 0x03d4 �Կ��������Ĵ����˿�
         mov al,0x0e                        ; 8λ���Ĵ��������� �ṩ���λ�õĸ�8λ
         out dx,al
         inc dx                             ; 0x03d5 �Կ������ݶ˿�
         in al,dx                           ; ������λ�õĸ�8λ��al
         mov ah,al                          ; �Ƶ�ah

         dec dx                             ; 0x03d4
         mov al,0x0f                        ; 8λ���Ĵ��������� �ṩ���λ�õĵ�8λ
         out dx,al
         inc dx                             ; 0x3d5
         in al,dx                           ; ������λ�õĵ�8λ��al
         mov bx,ax                          ; BX=������λ�õ�16λ��
         and ebx,0x0000ffff                 ; ׼��ʹ��32λѰַ��ʽ�����Դ� 
         
         cmp cl,0x0d                        ; �س�����
         jnz .put_0a                         
         
         mov ax,bx                          ;���°��س������� 
         mov bl,80
         div bl                             ; ����AL=���� ������AH=����
         mul bl                             ; AX=AL*80=���׵Ĺ��λ��
         mov bx,ax
         jmp .set_cursor

  .put_0a:
         cmp cl,0x0a                        ; ���з���
         jnz .put_other
         add bx,80                          ; ���λ������һ�� 
         jmp .roll_screen

  .put_other:                               ;������ʾ�ַ�
         shl bx,1                           ; ��2 �����λ��ת��Ϊ�ֽ�ƫ��
         mov [0x800b8000+ebx],cl            ; �ڹ��λ�ô���ʾ�ַ� 
         mov byte [0x800b8000+ebx+1],0x07   ; �����ַ����� û�����Ҳ���� ��ΪĬ��ȫ��0x0720

         ;���½����λ���ƽ�һ���ַ�
         shr bx,1
         inc bx

  .roll_screen:
         cmp bx,2000                        ;��곬����Ļ������
         jl .set_cursor

         cld                                ; ����DF=0 ����
         ; С�ģ�32λģʽ��movsb/w/d ʹ�õ���DS:esi => ES:edi ������ecxָ�� 
         mov esi,0x800b80a0                 ; ��Ӧ�Դ��еڶ�������
         mov edi,0x800b8000                 ; �����Դ��е�һ������
         mov ecx,1920                       ; ����24�� 1920���ַ�(ÿ��2�ֽ� ����һ�ֽ���ʾ����)
         rep movsw                          ; ���˾�������Ӧ����movsw  ��������movsd ��������������
         mov bx,3840                        ; 1920*2=���һ�е��׸��ַ����Դ��е�ƫ�� �����Ļ���һ��
         mov ecx,80                         ; 32λ����Ӧ��ʹ��ECX
  .cls:
         mov word [0x800b8000+ebx],0x0720   ; 0x0720 �ڵװ��ֵĿհ��ַ�
         add bx,2
         loop .cls

         mov bx,1920

  .set_cursor:
         mov dx,0x03d4                      ; �Կ������˿�
         mov al,0x0e                        ; 8λ���Ĵ��� ���λ�ø�8λ
         out dx,al
         inc dx                             ; 0x3d5 �Կ����ݶ˿�
         mov al,bh
         out dx,al                          ; ������λ�ø�8λ
         dec dx                             ; 0x3d4 �Կ������˿�
         mov al,0x0f                        ; 8λ���Ĵ��� ���λ�õ�8λ
         out dx,al
         inc dx                             ; 0x3d5 �Կ����ݶ˿�
         mov al,bl
         out dx,al                          ; ������λ�ø�8λ
         
         popad
         
         ret                              

;-------------------------------------------------------------------------------
read_hard_disk_0:                           ;��Ӳ�̶�ȡһ���߼�������ƽ̹ģ�ͣ� 
                                            ;EAX=�߼�������
                                            ;EBX=Ŀ�껺�������Ե�ַ
                                            ;���أ�EBX=EBX+512
         ; ������̺�mbr��Ĺ������ ֻ�п�ʼ���ж� �������ж� �Լ������Զ���� ��ͬ
         ; �ڶ�Ӳ��ʱ Ӧ������Ӳ���ж� �Է�ֹ��ͬһ��Ӳ�̿������˿ڵĽ����޸� �����������ص�����
         ; �ر��Ƕ����񻷾��� ��һ���������ڶ�Ӳ��ʱ �ᱻ��һ�������� �����һ������Ҳ����Ӳ�� ���ƻ�ǰһ�������Ӳ�̵Ĳ���״̬
         cli
         
         push eax 
         push ecx
         push edx
      
         push eax
         
         mov dx,0x1f2
         mov al,1
         out dx,al                          ;��ȡ��������

         inc dx                             ;0x1f3
         pop eax
         out dx,al                          ;LBA��ַ7~0

         inc dx                             ;0x1f4
         mov cl,8
         shr eax,cl
         out dx,al                          ;LBA��ַ15~8

         inc dx                             ;0x1f5
         shr eax,cl
         out dx,al                          ;LBA��ַ23~16

         inc dx                             ;0x1f6
         shr eax,cl
         or al,0xe0                         ;��һӲ��  LBA��ַ27~24
         out dx,al

         inc dx                             ;0x1f7
         mov al,0x20                        ;������
         out dx,al

  .waits:
         in al,dx
         and al,0x88
         cmp al,0x08
         jnz .waits                         ;��æ����Ӳ����׼�������ݴ��� 

         mov ecx,256                        ;�ܹ�Ҫ��ȡ������
         mov dx,0x1f0
  .readw:
         in ax,dx
         mov [ebx],ax
         add ebx,2
         loop .readw

         pop edx
         pop ecx
         pop eax
      
         sti
      
         retf                               ;Զ���� 

;-------------------------------------------------------------------------------
;������Գ����Ǽ���һ�γɹ������ҵ��Էǳ����ѡ�������̿����ṩ���� 
put_hex_dword:                              ;�ڵ�ǰ��괦��ʮ��������ʽ��ʾ
                                            ;һ��˫�ֲ��ƽ���� 
                                            ;���룺EDX=Ҫת������ʾ������
                                            ;�������
         pushad

         mov ebx,bin_hex                    ;ָ����ĵ�ַ�ռ��ڵ�ת����
         mov ecx,8                          ; �ܹ�����ʾһ��32λ�� ÿ����16������ʾ4λ Ҫ��ʾ8��
  .xlt:    
         rol edx,4                          ; ѭ������4λ ����λѭ��������λ
         mov eax,edx
         and eax,0x0000000f                 ; ȡ����λ
         xlat                               ; ��� DS:EBX ��AL��Ϊƫ����ȡһ���ֽڴ���AL
      
         push ecx
         mov cl,al                           
         call put_char
         pop ecx
       
         loop .xlt
      
         popad
         retf
      
;-------------------------------------------------------------------------------
set_up_gdt_descriptor:                      ;��GDT�ڰ�װһ���µ�������
                                            ;���룺EDX:EAX=������ 
                                            ;�����CX=��������ѡ����
         push eax
         push ebx
         push edx

         sgdt [pgdt]                        ; ȡ��GDTR�Ľ��޺����Ե�ַ 

         movzx ebx,word [pgdt]              ; movzx������չ�Ĵ��� GDT����
         inc bx                             ; GDT���ֽ�����Ҳ����һ��������ƫ��
         add ebx,[pgdt+2]                   ; GDT���Ե�ַ+GDT���ֽ���=��һ�������������Ե�ַ

         mov [ebx],eax
         mov [ebx+4],edx                    ; ����������װ����һ��������

         add word [pgdt],8                  ; ��GDT����ֵ����һ���������Ĵ�С

         lgdt [pgdt]                        ; ���ػ�GDTR ��GDT�ĸ�����Ч

         mov ax,[pgdt]                      ; �õ���GDT����ֵ
         xor dx,dx
         mov bx,8
         div bx                             ; ����ֵ����8�õ�����������������
         mov cx,ax
         shl cx,3                           ; ����������3λ����� TI=0 RPL=0��ѡ����

         pop edx
         pop ebx
         pop eax

         retf

;-------------------------------------------------------------------------------
make_seg_descriptor:                        ;����洢����ϵͳ�Ķ�������
                                            ;���룺EAX=���Ի���ַ
                                            ;      EBX=�ν���
                                            ;      ECX=���ԡ�������λ����ԭʼ
                                            ;          λ�ã��޹ص�λ���� 
                                            ;���أ�EDX:EAX=������
         mov edx,eax
         shl eax,16
         or ax,bx                           ; ������ǰ32λ(EAX)�������

         and edx,0xffff0000                 ; �������ַ���޹ص�λ
         rol edx,8
         bswap edx                          ; װ���ַ��31~24��23~16  (80486+)

         xor bx,bx
         or edx,ebx                         ; װ��ν��޵ĸ�4λ

         or edx,ecx                         ; װ������

         retf

;-------------------------------------------------------------------------------
make_gate_descriptor:                       ;�����ŵ��������������ŵȣ�
                                            ;���룺EAX=�Ŵ����ڶ���ƫ�Ƶ�ַ
                                            ;       BX=�Ŵ������ڶε�ѡ���� 
                                            ;       CX=�����ͼ����Եȣ�����
                                            ;          ��λ����ԭʼλ�ã�
                                            ;���أ�EDX:EAX=������������
         push ebx
         push ecx
      
         mov edx,eax
         and edx,0xffff0000                 ; �õ�ƫ�Ƶ�ַ��16λ 
         or dx,cx                           ; ��װ���Բ��ֵ�EDX
       
         and eax,0x0000ffff                 ; �õ�ƫ�Ƶ�ַ��16λ 
         shl ebx,16                          
         or eax,ebx                         ; ��װ��ѡ���Ӳ���
      
         pop ecx
         pop ebx
      
         retf                                   
                             
;-------------------------------------------------------------------------------
allocate_a_4k_page:                         ;����һ��4KB��ҳ
                                            ;���룺��
                                            ;�����EAX=ҳ�������ַ
         push ebx
         push ecx
         push edx

         xor eax,eax                        ; eax=0
  .b1:
         bts [page_bit_map],eax             ; �ӵ�0λ��ʼ����ֵΪ0��λ
         jnc .b2                            ; λΪ0 ��CF��Ϊ0 ����ת
         inc eax
         cmp eax,page_map_len*8
         jl .b1
         
         mov ebx,message_3
         call flat_4gb_code_seg_sel:put_string
         hlt                                ; û�п��Է����ҳ��ͣ��
                                            ; TODO �������еĲ���ϵͳ��˵���ǲ��Ե� ��ȷ�������ǿ���Щ�ѷ����ҳ����ʹ��
                                            ; (ҳĿ¼�ҳ��������һ��A����λ ָʾ�˱�����ָ���ҳ�Ƿ񱻷��ʹ������Ա�����ϵͳ��������ҳ��ʹ��Ƶ�ʣ����ڴ�ռ����ʱ���Խ�����ʹ�õ�ҳ���������̣�ͬʱ����Pλ���㣬Ȼ���ͷŵ�ҳ���������Ҫ���еĳ�����ʵ�������ڴ������)
         
  .b2:
         shl eax,12                         ; eax��λ�����׸�δ�����ҳ������ ����ÿ��ҳ4KB ����4096����ҳ�������ַ��0x1000�� 
         
         pop edx
         pop ecx
         pop ebx
         
         ret
         
;-------------------------------------------------------------------------------
alloc_inst_a_page:                          ; ����һ������ҳ������ҳ�������ַ��������Ӧ�����Ե�ַȥ�޸ĵ�ǰ�ں������ҳĿ¼���ҳ��(����װ�ڵ�ǰ��Ĳ㼶��ҳ�ṹ��)
                                            ;���룺EBX=ҳ�����Ե�ַ
         push eax
         push ebx
         push esi
         
         ;�������Ե�ַ����Ӧ��ҳ���Ƿ����
         mov esi,ebx
         and esi,0xffc00000                 ; ���Ե�ַ�ĸ�10λ ��ҳĿ¼����
         shr esi,20                         ; ��12λ=ҳĿ¼��������4  ��ҳĿ¼����ҳĿ¼�ڵ�ƫ��
         or esi,0xfffff000                  ; ���Ե�ַ0xfffff000��10λ1111 1111 11��ҳĿ¼���� ָ��ҳĿ¼���һ�� �洢��ҳĿ¼�Լ��������ַ ��ʱ��ҳĿ¼�����ַ��ҳ�������ַ
                                            ; �м�10λ��1111 1111 11��ҳ������ ָ��ҳ������һ�� �洢��ҳĿ¼�Լ��������ַ ��ʱ��ҳĿ¼�����ַ��ҳ�����ַ
                                            ; ����0xfffff000+ƫ��(ֻ�е�12λ) ��ɵ����Ե�ַ ����ҳ����ת�������������ַ�Ǵ������ҳ��ҳĿ¼��������ַ
                                            ; ���Դ�ʱ��esi���Ƕ�Ӧ�������ҳ��ҳĿ¼��������ַ�����Ե�ַ

         test dword [esi],0x00000001        ; ����ҳ��ҳĿ¼���Pλ�Ƿ�Ϊ1 Ϊ1���ҳ��ҳ�������ڴ���
         jnz .b1                            ; PλΪ1����ת
          
         ;��ҳ��ҳ�����ڴ��� �򴴽������Ե�ַ����Ӧ��ҳ�� 
         call allocate_a_4k_page            ; ����һ��ҳ��Ϊҳ�� 
                                            ; ���� eax=�����ҳ�������ַ
         or eax,0x00000007                  ; ����ҳ�����ַ��12λ�϶�Ϊ0 �ⲽ���Ǹ�����12λ���ó�ҳĿ¼�������
                                            ; AVL=00 G=0 D=0 A=0 PCD=0 PWT=0 US=1 RW=1 P=1
                                            ; ����������Ȩ����ĳ������ �ɶ���д ҳ�����ڴ���
         mov [esi],eax                      ; ��ҳĿ¼�еǼǸ�ҳ��
          
  .b1:
         ;��ʼ���ʸ����Ե�ַ����Ӧ��ҳ�� 
         mov esi,ebx
         shr esi,10
         and esi,0x003ff000                 ; esi�м�10λ�ǲ���ҳ��ҳĿ¼���� ����Ϊ0
         or esi,0xffc00000                  ; ��10Ϊ��Ϊȫ1 ��������ҳĿ¼���һ��Ļػ����� �õ���Ӧ����ҳ��ҳ�������ַ�����Ե�ַ
         
         ;�õ������Ե�ַ��ҳ���ڵĶ�Ӧ��Ŀ��ҳ��� 
         and ebx,0x003ff000                 ; ����ҳ���Ե�ַ���м�10λ�Ǹ�ҳ��ҳ������
         shr ebx,10                         ; �൱������12λ���ٳ���4
         or esi,ebx                         ; �õ���Ӧ��ҳ��ҳ���������ַ�����Ե�ַ
         call allocate_a_4k_page            ;����һ��ҳ�������Ҫ��װ��ҳ
         or eax,0x00000007                  ; eax=ҳ����
         mov [esi],eax                      ; ��ҳ�����������ҳ��ҳ���������ַ��
          
         pop esi
         pop ebx
         pop eax
         
         retf  

;-------------------------------------------------------------------------------
create_copy_cur_pdir:                       ;������ҳĿ¼�������Ƶ�ǰҳĿ¼����
                                            ;���룺��
                                            ;�����EAX=��ҳĿ¼�������ַ 
         push esi
         push edi
         push ebx
         push ecx
         
         call allocate_a_4k_page            ; ����eax=ҳ�������ַ
         mov ebx,eax
         or ebx,0x00000007                  ; ҳ�����ַ��12λ��Ϊ����0x007 G=0 PAT=0 D=0 A=0 PCD=0 PWT=0 US=1 RW=1 P=1
                                            ; ����������Ȩ����ĳ������ �ɶ���д ҳ�����ڴ���
         mov [0xfffffff8],ebx               ; Ϊ�˷��ʸ�ҳ�������������ַ�Ǽǵ���ǰҳĿ¼��(�ں�ҳĿ¼��)�ĵ����ڶ���Ŀ¼��
                                            ; ���һ�� 0xffffe000�������ҳ�����Ե�ַ(������ں�ҳĿ¼��)

         invlpg [0xfffffff8]                ; invalidate TLB Entry invlpg����ˢ��TLB�еĵ�����Ŀ �������ø��������Ե�ַ����TLB�ҵ��Ǹ���Ŀ Ȼ����ڴ������¼�����
                                            ; 0xfffffff8���ں�ҳĿ¼��ĵ����ڶ���Ŀ¼��������ַ ÿ�ζ�������ָ���������ҳĿ¼��

         mov esi,0xfffff000                 ; ESI->��ǰҳĿ¼�����Ե�ַ
         mov edi,0xffffe000                 ; EDI->��ҳĿ¼�����Ե�ַ
         mov ecx,1024                       ; ECX=Ҫ���Ƶ�Ŀ¼����
         cld
         repe movsd                         ; ÿ��Ŀ¼��4�ֽ�
         
         pop ecx
         pop ebx
         pop edi
         pop esi
         
         retf
         
;-------------------------------------------------------------------------------
general_interrupt_handler:                  ;ͨ�õ��жϴ������
         push eax
          
         mov al,0x20                        ; ��8259AоƬ�����жϽ�������EOI 
         out 0xa0,al                        ; ���Ƭ����
         out 0x20,al                        ; ����Ƭ����
         
         pop eax
          
         iretd

;-------------------------------------------------------------------------------
general_exception_handler:                  ;ͨ�õ��쳣�������
         mov ebx,excep_msg
         call flat_4gb_code_seg_sel:put_string ; ��ʾ�쳣��Ϣ
         
         hlt                                ; ͣ��

;-------------------------------------------------------------------------------
rtm_0x70_interrupt_handle:                  ;ʵʱʱ���жϴ������
                                            ; ����ǰæ����ŵ�����β����Ϊ���� ����������һ������������Ϊæ ����תִ��
        ; RTCоƬ�жϺ�Ĭ����0x70

         pushad                             ; push ����32λͨ�üĴ���

         ; ������Ӳ���ж� ��Ҫ��8259A�����жϽ�������EOI ������������������������һ���ж�֪ͨ TODO ?
         mov al,0x20                        ; �жϽ�������EOI
         out 0xa0,al                        ; ��8259A��Ƭ����
         out 0x20,al                        ; ��8259A��Ƭ����

         ; ����RTC�Ĵ���B
         mov al,0x0b
         or al,0x80                         ; ����RTC�ڼ� ������NMI TODO why
         out 0x70,al
         mov al,0x12                        ; ���üĴ���B ����������� ��ֹ�������ж� ��ֹ�����ж� ������½����ж� BCD��ʾ 24Сʱ��
         out 0x71,al

         mov al,0x0c                        ; RTC�Ĵ���C���������ҿ���NMI
         out 0x70,al                        ; CMOS RAM �������˿�
         in al,0x71                         ; CMOS RAM ���ݶ˿� ��һ��RTC�ļĴ���C������ֻ����һ���ж�
                                            ; ÿ���������ڽ����жϷ���ʱ ���������Ĵ���C�ĵ�4λ��λ ��ȡ������ ���������ͬ�����жϲ����ٲ���
                                            ; �˴����������Ӻ��������жϵ����

         ; ��������� 8259�ǲ�������RTC�жϵģ������޸����ڲ����ж����μĴ���IMR
         in al, 0xa1                        ; ��8259��Ƭ��IMR�Ĵ���
         and al,0xfe                        ; ���bit 0(��ӦRTC���ж���������IR0)
         out 0xa1,al                        ; д��IMR�Ĵ���

         ;�ҵ�ǰ����״̬Ϊæ�������������е�λ��
         mov eax,tcb_chain                  
  .b0:                                      ; EAX=����ͷ��ǰTCB���Ե�ַ
         ; TODO ������bug����æ�������������һ������ʱ �ж���������β��ֱ�Ӿʹ��жϷ�����
         mov ebx,[eax]                      ; EBX=��һ��TCB���Ե�ַ
         or ebx,ebx                         ; �ж�ebx�Ƿ�Ϊ0 ���Ƿ�������β
         jz .irtn                           ; ����Ϊ�գ����ѵ�ĩβ�����жϷ���
         cmp word [ebx+0x04],0xffff         ; �鿴��TCB������״̬�� 0x0000 ��ʾ���л��߹��� 0xffff��ʾ��æ���񣨵�ǰ���񣩣� ������ֻ������һ��æ����(��TSS�е�Bλ��ͬ)
         je .b1
         mov eax,ebx                        ;��λ����һ��TCB�������Ե�ַ��
         jmp .b0         

         ;����ǰΪæ�������Ƶ���β
  .b1:
         ; ��ʱ eax��æ������һ��TCB�����Ե�ַ ebx��æ����TCB�����Ե�ַ
         mov ecx,[ebx]                      ; ecx��æ������һ��TCB�����Ե�ַ
         mov [eax],ecx                      ; ��æ������һ��TCBָ��æ������һ��TCB ����ǰ��������в��

  .b2:                                      ; ��ʱ��EBX=æ��������Ե�ַ
         mov edx,[eax]
         or edx,edx                         ; �ѵ�����β�ˣ�
         jz .b3
         mov eax,edx
         jmp .b2

  .b3:                                      ; ��ʱ eax���������һ��TCB�����Ե�ַ
         mov [eax],ebx                      ; ���������һ��TCBָ��æ���� ��æ�����TCB��������β��
         mov dword [ebx],0x00000000         ; ��æ�����TCB���Ϊ��β

         ;������������һ����������
         mov eax,tcb_chain
  .b4:
         mov eax,[eax]
         or eax,eax                         ; �ѵ���β��δ���ֿ�������
         jz .irtn                           ; δ���ֿ������񣬴��жϷ���
         cmp word [eax+0x04],0x0000         ; �ǿ�������
         jnz .b4

         ;����������͵�ǰ�����״̬��ȡ��
         ; ��ʱ eax ���������ҵ��ĵ�һ����������TCB
         not word [eax+0x04]                ; ���ÿ��������״̬Ϊæ
         not word [ebx+0x04]                ; ���õ�ǰ����æ����״̬Ϊ����

         jmp far [eax+0x14]                 ; ����ת�� ע�⣺�жϴ�����̺������Ƿ���� �����Ǿ������һ���� ֻ�������������ȫ�ֿռ���� �����л�ʱ�������״̬ͣ��������жϴ��������
                                            ; TCBƫ��0x14�����ĸ��ֽڵ�TSS����ַ����EIP(��������) ���ֽڵ�TSSѡ���Ӹ���CS
                                            ; �����������ѡ���ӷ���GDT��ͨ����������������һ��TSS����������֪��Ӧ��ִ�������л�����
                                            ; ��ǰTRָ��ǰ�����TSS���ѵ�ǰ��ÿ���Ĵ������մ浽���TSS�У�Bλ����
                                            ; Ȼ����Ϊ��TSS��������TSS�Ļ���ַ���������Ӹ�TSS�лָ������Ĵ��������ݣ�����ͨ�üĴ�����EFLAGS���μĴ�����EIP��ESP��LDTR�ȣ�Bλ��һ
                                            ; ��TRָ���������TSS����ʼִ��������

         ; ����һ�δ����������л������������ʱ �ص��������ִ��
  .irtn:
         popad

         iretd                              ; TODO �о�Ƕ������

;-------------------------------------------------------------------------------
terminate_current_task:                     ;��ֹ��ǰ����
                                            ;ע�⣬ִ�д�����ʱ����ǰ��������
                                            ;�����С���������ʵҲ�ǵ�ǰ�����
                                            ;һ���� 
         ; �ҵ�ǰ����״̬Ϊæ�������������е�λ��
         mov eax,tcb_chain
  .b0:                                      ; EAX=����ͷ��ǰTCB���Ե�ַ
         mov ebx,[eax]                      ; EBX=��һ��TCB���Ե�ַ
         cmp word [ebx+0x04],0xffff         ; ��æ���񣨵�ǰ���񣩣�
         je .b1
         mov eax,ebx                        ; ��λ����һ��TCB�������Ե�ַ��
         jmp .b0
         
  .b1:
         mov word [ebx+0x04],0x3333         ; �޸ĵ�ǰ�����״̬Ϊ�˳� TODO �˳�Ϊ0x3333Ӧ�ÿ�����㶨�� ֻҪ��0x0000���� 0xffffæ���־���
         
  .b2:
         hlt                                ; ͣ�����ȴ�����������ָ�����ʱ��
                                            ; ������� Ŀǰ��û�л��մ���
         jmp .b2 

;------------------------------------------------------------------------------- 
         pgdt             dw  0             ;�������ú��޸�GDT 
                          dd  0

         pidt             dw  0             ; ���ڴ洢IDT�Ľ���ֵ
                          dd  0
                          
         ;������ƿ���
         tcb_chain        dd  0             ; ���˫�־���tcb����ͷ���洢��һ��tcb�����Ե�ַ

         core_tcb   times  32  db 0         ;�ںˣ��������������TCB ʵ���ò�����ô��

         ; ҳӳ��λ�� ����ָʾ����ҳ�ķ������
         ; Ŀǰû�м��ʵ�ʿ����ڴ�Ĵ��� ���Լٶ�����ֻ��2MB�����ڴ���� 2MB�ɷ�Ϊ512��4KBҳ ����������512bit��λ��
         ; λ0��Ӧ�����ַ0x00000000��ҳ λ1��Ӧ�����ַ0x00001000��ҳ...
         ; ǰ256λ��඼��1 ��Ӧ�˵Ͷ�1MB�ڴ��ҳ �����Ѿ������ϻ����ں�ʹ���� û�б��ں�ռ�õĲ��ֶ���Ҳ����ΧӲ��ռ���� ��ROM-BIOS
         ; ������һЩ0x55 => 01010101 ��������ķ�����ҳ Ϊ��˵��������������Ե�ַ�ռ䲻�ض�Ӧ������ҳ
         ; �����ַ0x30000-0x40000���ں˵��ڴ�ռ䣬���ں˲����õ�������Ҳ���������ʵ���� TODO ��ֻ�Ǹ�ʵ�� �����õ�ʱ������û�õ���Щҳ�������Ǳ��Ϊ�ѷ�����˷���
         page_bit_map     db  0xff,0xff,0xff,0xff,0xff,0xff,0x55,0x55
                          db  0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff
                          db  0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff
                          db  0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff
                          db  0x55,0x55,0x55,0x55,0x55,0x55,0x55,0x55
                          db  0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
                          db  0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
                          db  0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
         page_map_len     equ $-page_bit_map
                          
         ;���ŵ�ַ������
         salt:
         salt_1           db  '@PrintString'
                     times 256-($-salt_1) db 0
                          dd  put_string
                          dw  flat_4gb_code_seg_sel

         salt_2           db  '@ReadDiskData'
                     times 256-($-salt_2) db 0
                          dd  read_hard_disk_0
                          dw  flat_4gb_code_seg_sel

         salt_3           db  '@PrintDwordAsHexString'
                     times 256-($-salt_3) db 0
                          dd  put_hex_dword
                          dw  flat_4gb_code_seg_sel

         salt_4           db  '@TerminateProgram'
                     times 256-($-salt_4) db 0
                          dd  terminate_current_task
                          dw  flat_4gb_code_seg_sel

         salt_item_len   equ $-salt_4
         salt_items      equ ($-salt)/salt_item_len

         excep_msg        db  '********Exception encounted********',0

         message_0        db  'Working in system core with protection '
                          db  'and paging are all enabled.System core is mapped '
                          db  'to address 0x80000000.',0x0d,0x0a,0

         message_1        db  'System wide CALL-GATE mounted.',0x0d,0x0a,0
         
         message_3        db  '********No available pages********',0
         
         core_msg0        db  'System core task running!',0x0d,0x0a,0
         
         bin_hex          db '0123456789ABCDEF'
                                            ;put_hex_dword�ӹ����õĲ��ұ� 

         core_buf   times 512 db 0          ;�ں��õĻ�����

         cpu_vendorHead        db 'Processor Vendor: ',0
         cpu_vendor  times 52 db 0
         cpu_vendorTail        db 0x0d,0x0a,0

         cpu_brandHead        db 'Processor Brand: ',0
         cpu_brand  times 52 db 0
         cpu_brandTail        db 0x0d,0x0a,0

;-------------------------------------------------------------------------------
fill_descriptor_in_ldt:                     ;��LDT�ڰ�װһ���µ�������
                                            ;���룺EDX:EAX=������
                                            ;          EBX=TCB����ַ
                                            ;�����CX=��������ѡ����
         push eax
         push edx
         push edi

         mov edi,[ebx+0x0c]                 ; ���LDT����ַ
         
         xor ecx,ecx
         mov cx,[ebx+0x0a]                  ; ���LDT����
         inc cx                             ; LDT�����ֽ���������������ƫ�Ƶ�ַ
         
         mov [edi+ecx+0x00],eax
         mov [edi+ecx+0x04],edx             ; ��װ������

         add cx,8                           
         dec cx                             ; �õ��µ�LDT����ֵ 

         mov [ebx+0x0a],cx                  ; ����LDT����ֵ��TCB

         mov ax,cx
         xor dx,dx
         mov cx,8
         div cx                             ; LDT����ֵ����8 ����ax ������dx
         
         mov cx,ax
         shl cx,3                           ; ����3λ�õ�����������
         or cx,0000_0000_0000_0100B         ; ʹTIλ=1��ָ��LDT�����ʹRPL=00 

         pop edi
         pop edx
         pop eax
     
         ret
      
;-------------------------------------------------------------------------------
load_relocate_program:                      ;���ز��ض�λ�û�����
                                            ;����: PUSH �߼�������
                                            ;      PUSH ������ƿ���ʼ���Ե�ַ
                                            ;������� 
         pushad
      
         mov ebp,esp                        ;Ϊ����ͨ����ջ���ݵĲ�����׼��
      
         ;��յ�ǰҳĿ¼��ǰ�벿�֣���Ӧ��2GB�ľֲ���ַ�ռ䣩 
         ; ����ÿ��������˵ ҳĿ¼���ǰ�벿�ֶ�Ӧ���ľֲ��ռ� �ں��õ���ҳĿ¼��ĺ�벿�� ǰ�벿������ʱ��������ֻ���������Լ���ҳĿ¼��
         mov ebx,0xfffff000                 ; ��ӦҳĿ¼������һ�� ���ڻػ������Ե�ַָ��ҳĿ¼���Լ�
         xor esi,esi
  .b1:
         mov dword [ebx+esi*4],0x00000000
         inc esi
         cmp esi,512                        ; ҳĿ¼��1024�� ǰ�벿512��
         jl .b1

         mov eax,cr3
         mov cr3,eax                        ; ˢ��TLB 
                                            ; �ղ��޸���ҳĿ¼�� ��ʽˢ��TLB
         
         ;���¿�ʼ�����ڴ沢�����û�����
         mov eax,[ebp+40]                   ; �Ӷ�ջ��ȡ���û�������ʼ������
                                            ; ��ַ�Ĵ���ebpĬ��ʹ��SS
         mov ebx,core_buf                   ; 512�ֽڵ��ں˻����� ���ڶ�ȡ����ͷ������
         call flat_4gb_code_seg_sel:read_hard_disk_0  ; ��һ���������ص����ں˻�����

         ;�����ж����������ж��
         mov eax,[core_buf]                 ; ����ߴ�
         mov ebx,eax
         and ebx,0xfffff000                 ; ʹ֮4KB���� 
         add ebx,0x1000                     ; �൱�������4KB����ȡ����   
         test eax,0x00000fff                ; ����Ĵ�С������4KB�ı�����? 
         cmovnz eax,ebx                     ; ���ǡ�ʹ�ô����Ľ��

         mov ecx,eax
         shr ecx,12                         ; ����ռ�õ���4KBҳ�� 
         
         mov eax,[ebp+40]                   ; ��ʼ������
         mov esi,[ebp+36]                   ; �Ӷ�ջ��ȡ��TCB�Ļ���ַ
  .b2:
         alloc_user_linear                  ; �꣺���û������ַ�ռ��Ϸ����ڴ� 
                                            ; ���� ebx �˴η����ҳ�����Ե�ַ
         
         push ecx
         mov ecx,8
  .b3:
         call flat_4gb_code_seg_sel:read_hard_disk_0               
         inc eax
         loop .b3                           ; ÿ����4KB��ҳ ������8��512B����

         pop ecx
         loop .b2

         ; ���ں˵�ַ�ռ��ڴ����û������TSS
         alloc_core_linear                  ;�꣺���ں˵ĵ�ַ�ռ��Ϸ����ڴ�
                                            ;�û������TSS������ȫ�ֿռ��Ϸ��� 
         
         mov [esi+0x14],ebx                 ; ��TCB����дTSS�����Ե�ַ 
         mov word [esi+0x12],103            ; ��TCB����дTSS�Ľ���ֵ 
          
         ;���û�����ľֲ���ַ�ռ��ڴ���LDT 
         alloc_user_linear                  ;�꣺���û������ַ�ռ��Ϸ����ڴ�

         mov [esi+0x0c],ebx                 ; ��дLDT���Ե�ַ��TCB�� 

         ;������������������
         mov eax,0x00000000                 ; �����Ի���ַ
         mov ebx,0x000fffff                 ; �ν���       
         mov ecx,0x00c0f800                ; ���� G=1 D/B=1 P=1 DPL=11 S=1 TYPE=1000
                                            ; 4KB���ȵĴ����������(��ζ��Ѱַ�ռ䵽4GB��ƽ̹ģ��)����Ȩ��3
                                            ; ע�� ���ǰ�װ��LDT�еĶ�������(��GDT�еĸ�ʽһ��) ������LDT������(��װ��GDT�е�ָʾLDT��������)
         call flat_4gb_code_seg_sel:make_seg_descriptor
         mov ebx,esi                        ; TCB�Ļ���ַ
         call fill_descriptor_in_ldt
         or cx,0000_0000_0000_0011B         ; ����ѡ���ӵ�RPLΪ3
         
         mov ebx,[esi+0x14]                 ; ��TCB�л�ȡTSS�����Ե�ַ
         mov [ebx+76],cx                    ; ��дTSS��CS�� �����������������

         ;�����������ݶ�������
         mov eax,0x00000000                 ; �����Ի���ַ
         mov ebx,0x000fffff                 ; �ν���
         mov ecx,0x00c0f200                ; ���� G=1 D/B=1 P=1 DPL=11 S=1 TYPE=0010
                                            ; 4KB���ȵ����ݶ�����������Ȩ��3
         call flat_4gb_code_seg_sel:make_seg_descriptor
         mov ebx,esi                        ; TCB�Ļ���ַ
         call fill_descriptor_in_ldt
         or cx,0000_0000_0000_0011B         ; ����ѡ���ӵ�RPLΪ3
         
         mov ebx,[esi+0x14]                 ; ��TCB�л�ȡTSS�����Ե�ַ
         mov [ebx+84],cx                    ; ��дTSS��DS�� ����������ݶ�������
         mov [ebx+72],cx                    ; ��дTSS��ES�� ����������ݶ�������
         mov [ebx+88],cx                    ; ��дTSS��FS�� ����������ݶ�������
         mov [ebx+92],cx                    ; ��дTSS��GS�� ����������ݶ�������
         
         ;�����ݶ���Ϊ�û������3��Ȩ�����ж�ջ 
         mov [ebx+80],cx                    ; ��дTSS��SS�� ����������ݶ�������
         alloc_user_linear                  ;�꣺���û������ַ�ռ��Ϸ����ڴ�
                                            ; ���� ebx �ղŷ����ҳ�����Ե�ַ
                                            ; �����������ҳ����ջ ��������չ�� ��Ҫ�������ҳ�ĸ߶����Ե�ַ
         
         mov ebx,[esi+0x14]                 ; ��TCB�л�ȡTSS�����Ե�ַ
         mov edx,[esi+0x06]                 ; TCB�еĳ�����ػ���ַ ���ղŷ���Ķ�ջ�ĸ߶����Ե�ַ+1
         mov [ebx+56],edx                   ; ��дTSS��ESP�� �����ջ�ĸ߶����Ե�ַ+1

         ;���û�����ľֲ���ַ�ռ��ڴ���0��Ȩ����ջ
         alloc_user_linear                  ;�꣺���û������ַ�ռ��Ϸ����ڴ�
                                            ; ��ʱTCB�ĳ�����ػ���ַ�д洢�����ջ�ĸ߶����Ե�ַ+1 ��ջ��

         mov eax,0x00000000                 ; �����Ի���ַ
         mov ebx,0x000fffff                 ; �ν���
         mov ecx,0x00c09200                 ; 4KB���ȵĶ�ջ������������Ȩ��0
         call flat_4gb_code_seg_sel:make_seg_descriptor
         mov ebx,esi                        ; TCB�Ļ���ַ
         call fill_descriptor_in_ldt
         or cx,0000_0000_0000_0000B         ; ����ѡ���ӵ�RPLΪ0

         mov ebx,[esi+0x14]                 ; ��TCB�л�ȡTSS�����Ե�ַ
         mov [ebx+8],cx                     ; ��дTSS��SS0�� ����������ݶ�������
         mov edx,[esi+0x06]                 ; TCB�еĳ�����ػ���ַ ��ջ�ĸ߶����Ե�ַ
         mov [ebx+4],edx                    ; ��дTSS��ESP0�� 

         ;���û�����ľֲ���ַ�ռ��ڴ���1��Ȩ����ջ
         alloc_user_linear                  ; �꣺���û������ַ�ռ��Ϸ����ڴ�

         mov eax,0x00000000
         mov ebx,0x000fffff
         mov ecx,0x00c0b200                 ; 4KB���ȵĶ�ջ������������Ȩ��1
         call flat_4gb_code_seg_sel:make_seg_descriptor
         mov ebx,esi                        ; TCB�Ļ���ַ
         call fill_descriptor_in_ldt
         or cx,0000_0000_0000_0001B         ; ����ѡ���ӵ���Ȩ��Ϊ1

         mov ebx,[esi+0x14]                 ; ��TCB�л�ȡTSS�����Ե�ַ
         mov [ebx+16],cx                    ; ��дTSS��SS1��
         mov edx,[esi+0x06]                 ; ��ջ�ĸ߶����Ե�ַ
         mov [ebx+12],edx                   ; ��дTSS��ESP1�� 

         ;���û�����ľֲ���ַ�ռ��ڴ���2��Ȩ����ջ
         alloc_user_linear                  ; �꣺���û������ַ�ռ��Ϸ����ڴ�

         mov eax,0x00000000
         mov ebx,0x000fffff
         mov ecx,0x00c0d200                 ; 4KB���ȵĶ�ջ������������Ȩ��2
         call flat_4gb_code_seg_sel:make_seg_descriptor
         mov ebx,esi                        ; TCB�Ļ���ַ
         call fill_descriptor_in_ldt
         or cx,0000_0000_0000_0010B         ; ����ѡ���ӵ���Ȩ��Ϊ2

         mov ebx,[esi+0x14]                 ; ��TCB�л�ȡTSS�����Ե�ַ
         mov [ebx+24],cx                    ; ��дTSS��SS2��
         mov edx,[esi+0x06]                 ; ��ջ�ĸ߶����Ե�ַ
         mov [ebx+20],edx                   ; ��дTSS��ESP2�� 

         ;�ض�λU-SALT 
         cld                                ; DF=0 ����

         ; �û������Ǵ��������ַ�ռ�Ŀ�ʼ��0x00000000���ص�
         ; ƫ����Ϊ0x0000000c��0x00000008�ĵط��ֱ�ʱU-SALT�����Ŀ���������Ե�ַ
         mov ecx,[0x0c]                     ; U-SALT��Ŀ�� ���ѭ����
         mov edi,[0x08]                     ; U-SALT��4GB�ռ��ڵ�ƫ�� 
  .b4:
         push ecx
         push edi
      
         mov ecx,salt_items                 ; C-SALT��Ŀ�� �ڲ�ѭ������
         mov esi,salt                       ; C-SALT���Ե�ַ
  .b5:
         push edi
         push esi
         push ecx

         mov ecx,64                         ; ÿ��Ŀ�ıȽϴ��� ÿ�αȽ�4�ֽ� �ܹ�Ҳ���ǱȽ�256�ֽ� ������������
         repe cmpsd                         ; cmpsd �Ƚ�DS:ESI��ES:EDI��˫��
                                            ; repe ֱ��ECX=0 �� ZF=0
                                            ; ����DS ES���Ǵ�0x00000000��ʼ��4GB��
         jnz .b6                            ; ZF=0 ��ƥ������ת
         mov eax,[esi]                      ; ��ƥ�䣬��esiǡ��ָ��C-SALT���ƫ�Ƶ�ַ ediָ��U-SALT��÷��ź�һλ
         mov [edi-256],eax                  ; ��U-SALT�е��ַ�����д��ƫ�Ƶ�ַ 
         mov ax,[esi+4]                     ; esi+4ָ��C-SALT��Ĵ����ѡ����
         or ax,0000000000000011B            ; ���û������Լ�����Ȩ��ʹ�õ�����
                                            ; ��RPL=3 
         mov [edi-252],ax                   ; ���������ѡ���� ����ƫ�Ƶ�ַ֮��
  .b6:
         pop ecx
         pop esi
         add esi,salt_item_len              ; esi������Ŀ����ָ��C-SALT��һ����Ŀ
         pop edi                            ; ��ͷ�Ƚ� 
         loop .b5                           ; ѭ��C-SALT��Ŀ����
      
         pop edi
         add edi,256
         pop ecx
         loop .b4                           ; ѭ��U-SALT��Ŀ����

         ;��GDT�еǼ�LDT������
         mov esi,[ebp+36]                   ; esi=�Ӷ�ջ��ȡ��TCB�Ļ���ַ
         mov eax,[esi+0x0c]                 ; TCB��ȡ��LDT����ʼ���Ե�ַ
         movzx ebx,word [esi+0x0a]          ; TCB��ȡ��LDT�ν���
         mov ecx,0x00008200                 ; LDT���������� G=0 P=1 DPL=00 TYPE=0010
                                            ; ������0x00408200 D=1 ��LDT������DӦ��Ϊ0 TODO
         call flat_4gb_code_seg_sel:make_seg_descriptor
         call flat_4gb_code_seg_sel:set_up_gdt_descriptor  ; ����cx=������ѡ����
         mov [esi+0x10],cx                  ; �Ǽ�LDT������ѡ���ӵ�TCB��

         mov ebx,[esi+0x14]                 ; ebx=��TCB�л�ȡTSS�����Ե�ַ
         mov [ebx+96],cx                    ; ��дTSS��LDT�� 

         mov word [ebx+0],0                 ; TSS��ǰһ������ָ��=0 ����ָ��Ƕ�׵�ǰһ�������TSS������ѡ����
      
         mov dx,[esi+0x12]                  ; TCB�е�TSS����ֵ
         mov [ebx+102],dx                   ; ��TSS����ֵ����TSS��IO���λ�� �Ա�ʾû��IO���λ��
      
         mov word [ebx+100],0               ; ��дTSS�е�T=0
      
         mov eax,[0x04]                     ; �������4GB��ַ�ռ��ȡ��ڵ� 
         mov [ebx+32],eax                   ; ��дTSS��EIP�� 

         pushfd                             ; ��EFLAGSѹջ
         pop edx                            ; ��EFLAGS��ֵ��ջ��edx
         mov [ebx+36],edx                   ; ��дTSS��EFLAGS�� 

         ;��GDT�еǼ�TSS������
         mov eax,[esi+0x14]                 ; ��TCB�л�ȡTSS����ʼ���Ե�ַ
         movzx ebx,word [esi+0x12]          ; TCB�е�TSS����ֵ
         mov ecx,0x00008900                 ; TSS���������� G=0 P=1 DPL=00 TYPE=1001(B=0)����Ȩ��0
                                            ; ������0x00408900 D=1����TSS������Ӧ��D=0
         call flat_4gb_code_seg_sel:make_seg_descriptor
         call flat_4gb_code_seg_sel:set_up_gdt_descriptor
         mov [esi+0x18],cx                  ; �Ǽ�TSSѡ���ӵ�TCB

         ;�����û������ҳĿ¼
         ; ��ǰ��ҳĿ¼���ǽ��õ��ں�ҳĿ¼�� �û�����������Լ���ҳĿ¼�� Ϊ������һ������ҳ��Ϊ�û������ҳĿ¼�� ������ǰҳĿ¼������ݸ��ƹ�ȥ
         ; ע�⣡ҳ�ķ����ʹ������ҳλͼ�����ģ����Բ�ռ�����Ե�ַ�ռ� 
         call flat_4gb_code_seg_sel:create_copy_cur_pdir    ; ���� eax=��ҳĿ¼�������ַ
         mov ebx,[esi+0x14]                 ; ��TCB�л�ȡTSS�����Ե�ַ
         mov dword [ebx+28],eax             ; ��дTSS��CR3(PDBR)�� ������ҳĿ¼��������ַ

         popad
      
         ret 8                              ;�������ñ�����ǰѹ��Ĳ��� 
                                            ; ����ʱ����8�ֽ�����
      
;-------------------------------------------------------------------------------
append_to_tcb_link:                         ;��TCB����׷��������ƿ�
                                            ;���룺ECX=TCB���Ի���ַ
         cli                                ; ʱ���ж���ʱ���ܷ��� ҲҪ����TCB�� ����Ҫ���ж�
         
         push eax
         push ebx

         mov eax,tcb_chain                  ; tcb_chain ����ͷ
  .b0:                                      ; EAX=����ͷ��ǰTCB���Ե�ַ
         mov ebx,[eax]                      ; EBX=��һ��TCB���Ե�ַ
         or ebx,ebx
         jz .b1                             ; ����Ϊ�գ����ѵ�ĩβ
         mov eax,ebx                        ; ��λ����һ��TCB�������Ե�ַ��
         jmp .b0

  .b1:
         mov [eax],ecx                      ; eax �����һ��TCB�����Ե�ַ�������һ��TCBָ����TCB
         mov dword [ecx],0x00000000         ; ��ǰTCBָ�������㣬��ָʾ�������һ��TCB
         pop ebx
         pop eax
         
         sti
         
         ret
         
;-------------------------------------------------------------------------------
start:
         ;�����ж���������IDT
         ;�ڴ�֮ǰ����ֹ����put_string���̣��Լ��κκ���stiָ��Ĺ��̡�
          
         ; ǰ20�������Ǵ������쳣ʹ�õ�
         ; intel �����˱���ģʽ�µ��жϺ��쳣�������� 0-19�����Ѷ�����ж����� 20-31 �������� 32-255 �û��Զ����ж�
         ; ��ͨ���쳣�������ע�ᵽ�ж���������
         mov eax,general_exception_handler  ; ���� �Ŵ����ڶ���ƫ�Ƶ�ַ
         mov bx,flat_4gb_code_seg_sel       ; ���� �Ŵ������ڶε�ѡ����
         mov cx,0x8e00                      ; ���� �����ͺ����Ե� P=1 DPL=00 D=1(32λ��)
         call flat_4gb_code_seg_sel:make_gate_descriptor ;���� EDX:EAX=������������

         mov ebx,idt_linear_address         ; �ж�������������Ե�ַ
         xor esi,esi
         ; IDT ��һ������������Ч��
  .idt0:
         mov [ebx+esi*8],eax
         mov [ebx+esi*8+4],edx
         inc esi
         cmp esi,19                         ; ��װǰ20���쳣�жϴ�����̣�����װ��һ����ͨ���쳣�������
         jle .idt0

         ;����Ϊ�������ⲿӲ���ж�
         ; ע�����ﰲװ����ͨ���жϴ������ ������ͨ���쳣�������
         mov eax,general_interrupt_handler  ; �Ŵ����ڶ���ƫ�Ƶ�ַ
         mov bx,flat_4gb_code_seg_sel       ; �Ŵ������ڶε�ѡ����
         mov cx,0x8e00                      ; 32λ�ж��ţ�0��Ȩ��
         call flat_4gb_code_seg_sel:make_gate_descriptor

         mov ebx,idt_linear_address         ; �ж�������������Ե�ַ
  .idt1:
         mov [ebx+esi*8],eax
         mov [ebx+esi*8+4],edx
         inc esi
         cmp esi,255                        ; ��װ��ͨ���жϴ������
         jle .idt1

         ;����ʵʱʱ���жϴ������
         mov eax,rtm_0x70_interrupt_handle  ; �Ŵ����ڶ���ƫ�Ƶ�ַ
         mov bx,flat_4gb_code_seg_sel       ; �Ŵ������ڶε�ѡ����
         mov cx,0x8e00                      ; 32λ�ж��ţ�0��Ȩ��
         call flat_4gb_code_seg_sel:make_gate_descriptor

         mov ebx,idt_linear_address         ; �ж�������������Ե�ַ
         mov [ebx+0x70*8],eax               ; ��ʵʱʱ���жϰ�װΪ0x70���ж�
         mov [ebx+0x70*8+4],edx

         ;׼�������ж�
         mov word [pidt],256*8-1            ; ��IDT�Ľ���д��pidt�����ֵ�Ԫ
         mov dword [pidt+2],idt_linear_address  ; д��IDT�����Ի���ַ
         lidt [pidt]                        ; ��IDT�Ľ��޺ͻ���ַ���ص��ж���������Ĵ���IDTR
                                            ; һ��������IDTR ���������жϻ��ƾͿ�ʼ��������

         ; ��Ҫ���³�ʼ�� 8259A����Ϊ����Ƭ���ж������ʹ��������쳣������ͻ���������������Ƭ���ж�����Ϊ0x08-0x0F ��Ƭ���ж�������0x70-0x77
         ; ��32λ�������� 0x08-0x0F �Ѿ��������������쳣����(ǰ��ע���ǰ20���ж�����)
         ; ���� 8259A�ǿɱ�̵ģ����԰������ж������ĳ�0x20-0x27(32-255���û��Զ����ж�����)
         ; ����8259A�жϿ�������Ƭ
         ; ICW Initialize Command Word
         mov al,0x11                        ; ICW1 �����ж����󴥷���ʽ�ͼ�����оƬ���������ش��� �ж������(��ҪICW3) ���γ�ʼ����ҪICW4
         out 0x20,al                        ; ��Ƭ�˿ں�
                                            ; 8259A�ӵ�ICW1ʱ����ζ��һ���µĳ�ʼ�����̿�ʼ�� �ڴ���0x21�˿ڽ���ICW2
         mov al,0x20                        ; ICW2 ����ÿ��оƬ���ж�����: ��ʼ�ж�����Ϊ0x20 8�����Ŷ�Ӧ��0x20-0x27
         out 0x21,al                        ; ��Ƭ�˿ں�
         mov al,0x04                        ; ICW3 ָ�����ĸ�����ʵ��оƬ����: ��Ƭ��IR2(����������)�ʹ�Ƭ����
         out 0x21,al                        
         mov al,0x01                        ; ICW4 ����оƬ������ʽ: ���Զ�������ʽ Ҫ�����жϴ����������ȷ����8259Aд�жϽ�������EOI �����߻��壬ȫǶ�ף�����EOI
         out 0x21,al                        

         ; ����8259A��Ƭ ͬ��
         mov al,0x11
         out 0xa0,al                        ;ICW1�����ش���/������ʽ
         mov al,0x70
         out 0xa1,al                        ;ICW2:��ʼ�ж����� 0x70-0x7F
         mov al,0x04
         out 0xa1,al                        ;ICW3:��Ƭ������IR2
         mov al,0x01
         out 0xa1,al                        ;ICW4:�����߻��壬ȫǶ�ף�����EOI

         ;���ú�ʱ���ж���ص�Ӳ�� 
         mov al,0x0b                        ; RTC�Ĵ���B
         or al,0x80                         ; ���NMI
         out 0x70,al
         mov al,0x12                        ; ���üĴ���B����ֹ�������жϣ����Ÿ�
         out 0x71,al                        ; �½������жϣ�BCD�룬24Сʱ��

         in al,0xa1                         ; ��8259��Ƭ��IMR�Ĵ���
         and al,0xfe                        ; ���bit 0(��λ����RTC)
         out 0xa1,al                        ; д�ش˼Ĵ���

         mov al,0x0c
         out 0x70,al
         in al,0x71                         ; ��RTC�Ĵ���C����λδ�����ж�״̬

         sti                                ; ����Ӳ���ж�
                                            ; Ŀǰ�Ѿ����ܷ���ʱ�������ж� ����ΪTCB��Ϊ�� ����ֻ���8259A����EOI ��һ��RTC�ļĴ���C Ȼ�󷵻�

         mov ebx,message_0
         call flat_4gb_code_seg_sel:put_string

         ; һ������� ��������֧��cpuidָ�� ������������ȫ���Բ�Ҫ ѧϰ����Ҳû��ϵ
         ; ͨ����IDλ�Ƿ�ɸ����ж��Ƿ�֧��cpuidָ��
         pushfd                             ; push eflags
         pop eax                            ; ��eflags���eax
         mov ebx,eax
         xor eax,0x00200000                 ; ��IDλ��1
         push eax
         popfd                              ; д��eflags
         pushfd                             ; �ٴζ�ȡ
         pop eax
         cmp eax,ebx
         jz .skip_cpuid                     ; �޸ĺ���޸�ǰһ�� �޷��޸���֧��cpuidָ��

         ; 0�Ź��� ��ʾ��������Ӧ����Ϣ GenuineIntel
         mov eax,0
         cpuid
         mov [cpu_vendor + 0x00],ebx
         mov [cpu_vendor + 0x04],edx
         mov [cpu_vendor + 0x08],ecx
         mov ebx,cpu_vendorHead
         call flat_4gb_code_seg_sel:put_string
         mov ebx,cpu_vendor
         call flat_4gb_code_seg_sel:put_string
         mov ebx,cpu_vendorTail
         call flat_4gb_code_seg_sel:put_string

        ; 80000000�Ź��� ̽�⴦���������֧�ֵĹ��ܺ�
         mov eax,0x80000000
         cpuid
         ; �жϴ������Ƿ�֧�ֵ�80000004�Ź���
         cmp eax,0x80000004                          ; eax�з��ص�������֧�ֵĹ��ܺ� 0x80000008
         jl .skip_cpuid                              ; ��֧�� ���������ܵ���

         ;80000002-4 �Ź��� ��ʾ������Ʒ����Ϣ
         ; Intel(R) Core(TM)  i5-8300H CPU @ 2.30GHZ
         mov eax,0x80000002
         cpuid
         mov [cpu_brand + 0x00],eax
         mov [cpu_brand + 0x04],ebx
         mov [cpu_brand + 0x08],ecx
         mov [cpu_brand + 0x0c],edx

         mov eax,0x80000003
         cpuid
         mov [cpu_brand + 0x10],eax
         mov [cpu_brand + 0x14],ebx
         mov [cpu_brand + 0x18],ecx
         mov [cpu_brand + 0x1c],edx

         mov eax,0x80000004
         cpuid
         mov [cpu_brand + 0x20],eax
         mov [cpu_brand + 0x24],ebx
         mov [cpu_brand + 0x28],ecx
         mov [cpu_brand + 0x2c],edx

         mov ebx,cpu_brandHead                  ;��ʾ������Ʒ����Ϣ 
         call flat_4gb_code_seg_sel:put_string
         mov ebx,cpu_brand
         call flat_4gb_code_seg_sel:put_string
         mov ebx,cpu_brandTail
         call flat_4gb_code_seg_sel:put_string

         ;jmp $                             ; �������ʾ��Ϣ�ᱻ���ǵ� ��Ҫ�鿴����ȡ��ע����������
  .skip_cpuid:

         ;���¿�ʼ��װΪ����ϵͳ����ĵ����š���Ȩ��֮��Ŀ���ת�Ʊ���ʹ����
         ; ��ΪC-SALT���ÿ�������������������װ��GDT��Ȼ��������ѡ���ӻ���C-SALT
         mov edi,salt                       ; C-SALT�����ʼλ�� 
         mov ecx,salt_items                 ;C-SALT�����Ŀ���� 
  .b4:
         push ecx   
         mov eax,[edi+256]                  ; ����Ŀ��ڵ��32λƫ�Ƶ�ַ 
         mov bx,[edi+260]                   ; ����Ŀ��ڵ�Ķ�ѡ���� 
         mov cx,1_11_0_1100_000_00000B      ; ����������: P=1 DPL=11 TYPE=1100 ��������0
                                            ; ��Ȩ��3�ĵ�����(3���ϵ���Ȩ�����������)��0������(��Ϊ�üĴ������ݲ�������û����ջ) 
                                            ; һ��Ҫ��ջ TODO ѧϰ�����
         call flat_4gb_code_seg_sel:make_gate_descriptor ;���أ�EDX:EAX=������������
         call flat_4gb_code_seg_sel:set_up_gdt_descriptor
         mov [edi+260],cx                   ; �����ص���������ѡ���ӻ���
         add edi,salt_item_len              ; ָ����һ��C-SALT��Ŀ 
         pop ecx
         loop .b4

         ; ���Ž��в��� 
         mov ebx,message_1
         call far [salt_1+256]              ; ͨ������ʾ��Ϣ(ƫ������������) 
                                            ; �������ø�ѡ���ӷ���GDT ������������ �������ǵ����������� �����32λƫ����
                                            ; ����ת�Ƶ���������ָ���Ķ�ѡ���ӺͶ���ƫ�ƴ�

         ;jmp $

         ; ��ʼ�������ں�����(�������������)��������ƿ�TCB core_tcb�г������ַ��洢������һ���ɷ���������ڴ�ռ����Ե�ַ
         ; ���TCB�ڴ治�Ƕ�̬����� TODO ���Զ�̬������
         mov word [core_tcb+0x04],0xffff    ;����״̬��æµ
         mov dword [core_tcb+0x06],0x80100000  ; ������ػ���ַ  
                                               ; �ں��Լ�ռ����1MB 0x80000000-0x800FFFFF���ɼ�������Ŀռ��0x80100000��ʼ
                                               ; �ں�����ռ�ķ�������￪ʼ��
         mov word [core_tcb+0x0a],0xffff    ; �Ǽ�LDT��ʼ�Ľ��޵�TCB�� ���ֵ�ò�����Ϊ�ں�����û��LDT
         mov ecx,core_tcb
         call append_to_tcb_link            ; ����TCB��ӵ�TCB����

         ; Ϊ�ں������TSS�����ڴ�ռ�
         alloc_core_linear                  ; �꣺���ں˵������ַ�ռ����һ��ҳ���ڴ�
                                            ; ����ebx�д洢���Ƿ�������Ե�ַ

         ;���ں������TSS�����ñ�Ҫ����Ŀ
         mov word [ebx+0],0                 ; ������=0 ǰһ�������ָ��=0 ��������Ψһ������
         mov eax,cr3
         mov dword [ebx+28],eax             ; �Ǽ�CR3(PDBR)
         ; ƫ��32-92�Ǹ����Ĵ����Ŀ��� ���ﲻ���� ���������Ϊ�Դӽ��뱣��ģʽ�Ϳ�ʼ������
         mov word [ebx+96],0                ; LDT��ѡ����=0 û��LDT������������û��LDT������
         mov word [ebx+100],0               ; T=0 ����������� ��T=1ÿ���л���������ʱ������һ�������쳣�ж� ���Գ�����Խӹ��ж�����ʾ����״̬
         mov word [ebx+102],103             ; IOӳ�����ַ=103 �����ֵ���ڵ���TSS�Ķν��ޣ���TSS�������У����氲װ�������û��IO���λ��
                                            ; û��I/Oλͼ��0��Ȩ����ʵ�ϲ���Ҫ 262 287
         
         ;�����ں������TSS������������װ��GDT��
         mov eax,ebx                        ; TSS����ʼ���Ե�ַ
         mov ebx,103                        ; �γ��ȣ����ޣ� ����ֵ����������103(��Ϊǰ103�ֽڶ����Ѷ���ģ�����ӿ��п��޵�IO���λ��)
         mov ecx,0x00008900                 ; TSS���������� G=0 D=0 L=0 AVL=0 P=1 DPL=00 S=0 TYPE=1001(B=0)
                                            ; �ֽ�����
                                            ; ������0x00408900 D=1 ���ҿ�TSS������DλӦ�ù̶�Ϊ0 TODO ��֪���ǲ��������� ���ǹ��ܲ�Ӱ��
         call flat_4gb_code_seg_sel:make_seg_descriptor ; ����EDX:EAX������
         call flat_4gb_code_seg_sel:set_up_gdt_descriptor ; ����CX������ѡ����
         mov [core_tcb+0x18],cx             ; �Ǽ��ں������TSSѡ���ӵ���TCB

         ; ����Ĵ���TR�е�������������ڵı�־��������Ҳ�����˵�ǰ������˭��
         ; ��TSSѡ���Ӽ��ص�TR�� �������ø�ѡ���ӷ���GDT�ж�Ӧ��TSS������ ���ν��ޡ��λ���ַ�������Լ��ص�TR�����������ٻ����� ͬʱ����������TSS�������е�Bλ��1 Ҳ���Ǳ�־Ϊæ
         ; �����ָ��Ϊ��ǰ����ִ�е�0��Ȩ������ �ں������������TSS��
         ltr cx

         ;���ڿ���Ϊ�ں�������ִ���� �����ں������������˳�س�Ϊһ���Ϸ�������

         ;�����û�����A��������ƿ�TCB
         ; Ϊ���ܹ����ʺͿ������е�����ÿ�������TCB���봴�����ں˵ĵ�ַ�ռ���
         alloc_core_linear                  ; �꣺���ں˵������ַ�ռ�����ڴ�
         
         mov word [ebx+0x04],0              ; ����״̬������ 
         mov dword [ebx+0x06],0             ; ������ػ���ַ=0 �û�����ֲ��ռ�ķ����0��ʼ��
         mov word [ebx+0x0a],0xffff         ; LDT��ǰ����ֵ �Ǽ�LDT��ʼ�Ľ��޵�TCB��
                                            ; LDT����Ҳ��16λ ֻ����8192�������� ��LDT�����ֽ���Ϊ0 ���Խ���ֵӦ����0xffff(0-1)
      
         push dword 50                      ; �û�����λ���߼�50���� TODO �û�����Ӧ���Ƕ�̬�� ��Ӧ��д�����ں���
         push ebx                           ; ѹ��������ƿ���ʼ���Ե�ַ 
         call load_relocate_program         ; ���ز��ض�λ�û�����
         mov ecx,ebx         
         call append_to_tcb_link            ; ����TCB��ӵ�TCB����


         ;�����û�����B��������ƿ�TCB
         alloc_core_linear                  ; �꣺���ں˵������ַ�ռ�����ڴ�

         mov word [ebx+0x04],0              ; ����״̬������
         mov dword [ebx+0x06],0             ; �û�����ֲ��ռ�ķ����0��ʼ��
         mov word [ebx+0x0a],0xffff         ; �Ǽ�LDT��ʼ�Ľ��޵�TCB��

         push dword 100                     ; �û�����λ���߼�100���� TODO ��̬����
         push ebx                           ; ѹ��������ƿ���ʼ���Ե�ַ
         call load_relocate_program         ; ���ز��ض�λ�û�����
         mov ecx,ebx
         call append_to_tcb_link            ; ����TCB��ӵ�TCB����

  .core:
         mov ebx,core_msg0
         call flat_4gb_code_seg_sel:put_string
         
         ;������Ա�д��������ֹ�����ڴ�Ĵ���
          
         jmp .core
            
core_code_end:

;-------------------------------------------------------------------------------
SECTION core_trail
;-------------------------------------------------------------------------------
core_end:
