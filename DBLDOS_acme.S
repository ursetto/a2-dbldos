; Target assembler: acme v0.96.4 []
; DBLDOS -- a program by Jason Coleman (1986) which adds 3 commands,
; DCAT/DLOAD/DSAVE, to BASIC.SYSTEM. Originally published in machine language
; format in COMPUTE! Magazine, Oct 1987, page 90.
; 
; DCAT is experimentally confirmed to CATALOG DOS 3.3 disks, and DLOAD to load
; BASIC and binary programs from a DOS 3.3 disk.
; 
; See Beneath Apple ProDOS, A-30 (TYPE Command), for an example program that
; adds commands to the Basic Interpreter. Also see A.3.2, ProDOS 8 Technical
; Reference Manual.
            !cpu  65c02
P8_READ_BLOCK =   $80                   ;(3:Unit/1,Buff,BlkNum)
P8_WRITE_BLOCK =  $81                   ;(3:Unit/1,Buff,BlkNum)

rwtsptr     =     $00
temp06      =     $06
MON_A1L     =     $3c                   ;general purpose
MON_A1H     =     $3d                   ;general purpose
MON_A2L     =     $3e                   ;general purpose
MON_A2H     =     $3f                   ;general purpose
MON_A4L     =     $42                   ;general purpose
MON_A4H     =     $43                   ;general purpose
BAS_TEXTTAB =     $67                   ;pointer to start of Applesoft program (2b)
BAS_VARTAB  =     $69                   ;pointer to start of Applesoft variables (2b)
BAS_MEMSIZE =     $73                   ;HIMEM (2b)
BAS_PRGEND  =     $af                   ;pointer to end of program (2b)
BI_EXTRNCMD =     $be06                 ;Called for added CMD syntaxing
BI_ERROUT   =     $be09                 ;Handles ONERR or prints error
BI_DEFSLT   =     $be3c                 ;Default slot, set by 'S' parm
BI_DEFDRV   =     $be3d                 ;Default drive, set by 'D' parm
BI_XTRNADDR =     $be50                 ;Execution address of external cmd (0)
BI_XLEN     =     $be52                 ;Length of command string-1, ('HELP'=3)
BI_XCNUM    =     $be53                 ;BASIC cmd number (external cmd if =0)
BI_PBITS    =     $be54                 ;Allowed parameter bits
BI_FBITS    =     $be56                 ;Found parameter bits
BI_VADDR    =     $be58                 ;Parameter value for 'A' parm
BI_VLNTH    =     $be5f                 ;Parameter value for 'L' parm
BI_VSLOT    =     $be61                 ;Parameter value for 'S' parm
BI_VDRIV    =     $be62                 ;Parameter value for 'D' parm
BI_GETBUFR  =     $bef5                 ;Allocate buffers, number in A
P8_MLI      =     $bf00                 ;ProDOS MLI call entry point
KBD         =     $c000                 ;R last key pressed + 128
KBDSTRB     =     $c010                 ;RW keyboard strobe
MON_CR      =     $fc62                 ;perform a carriage return
MON_COUT    =     $fded                 ;print Acc to output device via $36-37
MON_MOVE    =     $fe2c                 ;move bytes from A1 to A4 until A1=A2

*           =     $3000
            lda   #$0a                  ;Allocate $0A buffers to copy our code into
            jsr   BI_GETBUFR
            bcc   start
            lda   #$0e
            jmp   BI_ERROUT

; Relocate code into the buffer space.
start       tax
            ldy   #$00
@L300F      txa
            sta   relocate_to,y
            inx
            iny
            cpy   #$07
            bcc   @L300F
            stx   L38D9+2
            stx   L38EE+2
            inx
            txa
            sta   relocate_to,y
            inx
            iny
            txa
            sta   relocate_to,y
            ldy   #$00
lda_src     lda   handler_entry,y
            ldx   #$00
@L3031      cmp   relocate_from,x
            beq   L304D
            inx
            cpx   #$09
            bcc   @L3031
L303B       iny
            bne   lda_src
            inc   lda_src+2
            inc   sta_dst+2
            lda   lda_src+2
            cmp   #$3b
            bcc   lda_src
            bcs   copy_code             ;always

L304D       lda   relocate_to,x
sta_dst     sta   handler_entry,y
            bne   L303B
relocate_from
            !hex  31323334353637393a    ;pages (high bytes) to relocate
relocate_to !hex  000000000000000000    ;relocate to these pages
; Copy $3100-$3AFF to the allocated buffers and install ourselves at the head of
; the handler chain.
copy_code   lda   #$31                  ;start copy from page $31
            sta   MON_A1H
            lda   #$37
            sta   L36B6+1
            lda   BI_EXTRNCMD+1         ;save old external command handler
            sta   chain_to_original+1   ;to call at end of our handler
            lda   BI_EXTRNCMD+2
            sta   chain_to_original+2
            lda   #$3a                  ;end copy at $3AFF
            sta   MON_A2H
            ldy   #$ff
            sty   MON_A2L
            iny
            sty   MON_A1L               ;0
            sty   MON_A4L
            sty   BI_EXTRNCMD+1
            lda   relocate_to           ;where we relocated handler_entry (page $31) to
            sta   MON_A4H
            sta   BI_EXTRNCMD+2
            jsr   MON_MOVE
            ldy   #$00
write_start_msg
            lda   startup_msg,y
            beq   @exit
            jsr   MON_COUT
            iny
            bne   write_start_msg
@exit       rts

            !xor  $80 {
startup_msg !text "DCAT, DSAVE, AND DLOAD NOW INSTALLED"
            }
            !byte $8d
            !xor  $80 {
            !text "WRITTEN BY JASON COLEMAN, JULY, 1986"
            }
            !byte $8d
            !byte $8d
            !fill 16,$00

handler_entry
            cld
            ldy   #$00
            ldx   #$00
dcat_char   lda   $0200,y
            iny
            cmp   #$a0
            beq   dcat_char
            and   #$df
            cmp   DCAT_str,x
            bne   check_dload
            inx
            cpx   #$04                  ;4 chars
            beq   dcat
            bne   dcat_char

            !xor  $80 {
DCAT_str    !text "DCAT"
            }

check_dload ldy   #$00
            ldx   #$00
dload_char  lda   $0200,y
            iny
            cmp   #$a0
            beq   dload_char
            and   #$df
            cmp   DLOAD_str,x
            bne   check_dsave
            inx
            cpx   #$05                  ;5 chars
            bne   dload_char
            jmp   dload

check_dsave ldy   #$00
            ldx   #$00
dsave_char  lda   $0200,y
            iny
            cmp   #$a0                  ;ignore spaces
            beq   dsave_char
            and   #$df
            cmp   DSAVE_str,x
            bne   next_handler
            inx
            cpx   #$05
            bne   dsave_char
            jmp   L3540

next_handler
            sec
chain_to_original
            jmp   $0000                 ;Chain to next command handler

            !xor  $80 {
DSAVE_str   !text "DSAVE"
            }
            !xor  $80 {
DLOAD_str   !text "DLOAD"
            }

; Inform BI of DCAT parsing params, and parse it.
;   DCAT [Sn,Dn]
; 
; Filename may be provided, but will be ignored (quirk of BASIC.SYSTEM). (Note:
; syntax error results if filename is provided along with slot/drive; unknown
; why.)
dcat        stx   BI_PBITS+1            ;#$04 = BI_SD (slot/drive)
            dex
            stx   BI_XLEN               ;cmd len-1
            lda   #>dcat_xtrn
            sta   BI_XTRNADDR+1
            lda   #<dcat_xtrn
            sta   BI_XTRNADDR
            lda   #$00                  ;0 = external command
            sta   BI_XCNUM
            lda   #$10                  ;At least one bit must be set in PBITS
            sta   BI_PBITS              ;so BI_FNOPT ($10) is typical and harmless
            clc
            rts                         ;Return to BASIC to parse command line

; Once the DCAT command line has been parsed successfully by BASIC, we resume
; here.
dcat_xtrn   lda   BI_VSLOT              ;update BASIC's default SLOT from params
            sta   BI_DEFSLT
            asl                         ;A=slot*16 (unit number)
            asl
            asl
            asl
            ldx   BI_VDRIV              ;update default DRIVE from params
            stx   BI_DEFDRV
            dex
            beq   @d1
            ora   #$80                  ;if drive 2, set high bit of unit number
@d1         sta   unit                  ;as per ProDOS requirements
            lda   #$80                  ;read
            sta   rwtscmd
            lda   #$11                  ;DOS VTOC
            ldy   #$00
            sta   track
            sty   sector
            lda   BAS_MEMSIZE+1
            sta   rwtsbuf+1
            lda   #$00
            sta   rwtsbuf
            ldy   #>rwtscmd
            lda   #<rwtscmd
            jsr   rwts
            bcc   catalog
            jmp   error

catalog     jsr   MON_CR
            ldy   #$06
            lda   (BAS_MEMSIZE),y       ;note we use $73 instead of $00
            sta   $02                   ;temp -- save vol #
            ldy   #$0a
print_volume
            lda   disk_volume_str,y
            jsr   MON_COUT
            dey
            bpl   print_volume
            lda   #$a0
            jsr   MON_COUT
            lda   $02                   ;restore temp -- why not move the vol # lookup here?
            jsr   print_3_digits
            jsr   MON_CR
            jsr   MON_CR
            ldy   #$0f
            sty   sector
L31E6       ldy   #>rwtscmd
            lda   #<rwtscmd
            jsr   rwts
            bcc   file_entry
            jmp   error

file_entry  lda   BAS_MEMSIZE+1
            sta   rwtsptr+1
            lda   BAS_MEMSIZE
            sta   rwtsptr
            ldy   #$0b
L31FC       sty   $03
            lda   (rwtsptr),y
            bne   @L3205
            jmp   L3292

@L3205      cmp   #$ff
            beq   L327F
            iny
            iny
            lda   (rwtsptr),y
            bmi   @L3217
            lda   #' ' | $80
            jsr   MON_COUT
            jmp   @L321C

@L3217      lda   #'*' | $80            ;locked
            jsr   MON_COUT
@L321C      lda   (rwtsptr),y
            and   #$7f
            beq   @L3230
            cmp   #$01
            beq   @L3234
            cmp   #$02
            beq   @L3238
            cmp   #$04
            beq   @L323C
            bne   L327F

@L3230      lda   #'T' | $80            ;text
            bne   cout

@L3234      lda   #'I' | $80            ;int basic
            bne   cout

@L3238      lda   #'A' | $80            ;applesoft
            bne   cout

@L323C      lda   #'B' | $80            ;binary
cout        jsr   MON_COUT
            lda   #' ' | $80
            jsr   MON_COUT
            lda   $03
            clc
            adc   #$21
            tay
            lda   (rwtsptr),y
            jsr   print_3_digits
            lda   #$a0
            jsr   MON_COUT
            ldy   $03
            iny
            iny
            iny
            ldx   #$00
@L325D      lda   (rwtsptr),y
            jsr   MON_COUT
            iny
            inx
            cpx   #$1d
            bne   @L325D
            jsr   MON_CR
            lda   KBD
            bpl   L327F
            lda   #$00
            sta   KBDSTRB
@L3275      lda   KBD
            bpl   @L3275
            lda   #$00
            sta   KBDSTRB
L327F       lda   $03
            clc
            adc   #$23
            tay
            bcs   @L328A
            jmp   L31FC

@L328A      dec   sector
            beq   L3292
            jmp   L31E6

L3292       jsr   MON_CR
            jsr   MON_CR
            clc
            lda   #$00
            rts

            !xor  $80 {
disk_volume_str
            !text "EMULOV KSID"
            }

print_3_digits
            sta   num_tmp               ;yet another temp stored outside zp
            ldy   #$02
start1      lda   #$00
            pha
@loop       lda   num_tmp
            cmp   places,y
            bcc   print_place
            sbc   places,y
            sta   num_tmp
            pla
            clc
            adc   #$01
            pha
            jmp   @loop

print_place pla
            ora   #$b0
            jsr   MON_COUT
            dey                         ;go to next place
            bpl   start1
            rts

num_tmp     !byte $00
            !byte $00                   ;unused
places      !byte 1                     ;ones
            !byte 10                    ;tens
            !byte 100                   ;hundreds place

dload       ldx   #$00
@L32D6      lda   $0200,y
            iny
            cmp   #$8d
            beq   @L32FA
            cmp   #$a0
            beq   @L32D6
@L32E2      cmp   #$8d
            beq   @L32FC
            cmp   #$ac
            beq   @L32FC
            cmp   #$e0
            bcc   @L32F0
            and   #$df
@L32F0      sta   $0201,x
            inx
            lda   $0200,y
            iny
            bne   @L32E2
@L32FA      sec
            rts

@L32FC      cpx   #$1f
            bcc   @L3302
            ldx   #$1e
@L3302      stx   $0200
            dey
            sty   BI_XLEN
            lda   #$24
            sta   BI_XTRNADDR
            lda   #$33
            sta   BI_XTRNADDR+1
            lda   #$00
            sta   BI_XCNUM
            lda   #$10
            sta   BI_PBITS
            lda   #$84
            sta   BI_PBITS+1
            clc
            rts

            lda   BI_VSLOT
            sta   BI_DEFSLT
            asl
            asl
            asl
            asl
            ldx   BI_VDRIV
            stx   BI_DEFDRV
            dex
            beq   @L3339
            ora   #$80
@L3339      sta   unit
            lda   BAS_MEMSIZE+1
            sta   rwtsbuf+1
            lda   #$00
            sta   rwtsbuf
            lda   #$11
            sta   track
            lda   #$0f
            sta   sector
@L3350      ldy   #$39
            lda   #$83
            jsr   rwts
            bcc   @L335C
            jmp   error

@L335C      lda   #$0e
@L335E      tay
            ldx   #$00
            sty   $02
@L3363      lda   (BAS_MEMSIZE),y
            beq   @L3387
            cmp   $0201,x
            bne   @L3375
            inx
            cpx   $0200
            beq   @L338B
            iny
            bne   @L3363
@L3375      lda   $02
            clc
            adc   #$23
            bcc   @L335E
            ldy   sector
            dey
            beq   @L3387
            sty   sector
            bne   @L3350

@L3387      lda   #$06
            sec
            rts

@L338B      cpx   #$1e
            beq   @L3399
            iny
            lda   (BAS_MEMSIZE),y
            cmp   #$a0
            bne   @L3375
            inx
            bne   @L338B
@L3399      ldy   $02
            dey
            dey
            dey
            lda   (BAS_MEMSIZE),y
            bmi   @L3387
            sta   track
            iny
            lda   (BAS_MEMSIZE),y
            sta   sector
            ldx   rwtsbuf+1
            inx
            inx
            stx   rwtsbuf+1
            stx   temp06+1
            ldx   #$00
            stx   temp06
            iny
            lda   (BAS_MEMSIZE),y
            and   #$7f
            cmp   #$02
            beq   @L33CD
            cmp   #$04
            bne   @L33C9
            jmp   @L3490

@L33C9      sec
            lda   #$0d
            rts

@L33CD      lda   #$83
            ldy   #$39
            jsr   rwts
            bcc   @L33D9
            jmp   error

@L33D9      lda   BAS_TEXTTAB
            ldy   BAS_TEXTTAB+1
            sec
            sbc   #$02
            bcs   @L33E3
            dey
@L33E3      sta   rwtsbuf
            sty   rwtsbuf+1
            ldy   #$00
            sty   @L348B
            iny
            lda   (temp06),y
            sta   @L348F
            iny
            lda   (temp06),y
            sta   @L348E
            ldy   #$0c
@L33FC      lda   (temp06),y
            beq   @L3429
            sta   track
            iny
            lda   (temp06),y
            iny
            sta   sector
            sty   $02
            lda   #$83
            ldy   #$39
            jsr   rwts
            bcc   @L3418
            jmp   error

@L3418      ldy   $02
            beq   @L3442
            inc   rwtsbuf+1
            lda   rwtsbuf+1
            cmp   BAS_MEMSIZE+1
            bcc   @L33FC
            lda   #$0e
            rts

@L3429      lda   rwtsbuf
            sta   BAS_VARTAB
            sta   BAS_PRGEND
            lda   rwtsbuf+1
            sta   BAS_VARTAB+1
            sta   BAS_PRGEND+1
            ldy   #$00
            tya
            dec   BAS_TEXTTAB
            sta   (BAS_TEXTTAB),y
            inc   BAS_TEXTTAB
            clc
            rts

@L3442      lda   rwtsbuf
            sta   @L348C
            lda   rwtsbuf+1
            sta   @L348D
            lda   temp06
            sta   rwtsbuf
            lda   temp06+1
            sta   rwtsbuf+1
            lda   @L348F
            sta   track
            lda   @L348E
            sta   sector
            lda   #<rwtscmd
            ldy   #>rwtscmd
            jsr   rwts
            bcc   @L3470
            jmp   error

@L3470      lda   @L348C
            sta   rwtsbuf
            lda   @L348D
            sta   rwtsbuf+1
            ldy   #$0c
            lda   @L348B
            bne   @L3486
            jmp   @L33FC

@L3486      sty   $02
            jmp   @L350E

@L348B      !byte $00
@L348C      !byte $00
@L348D      !byte $00
@L348E      !byte $00
@L348F      !byte $00

@L3490      lda   #<rwtscmd
            ldy   #>rwtscmd
            jsr   rwts
            bcc   @L349C
            jmp   error

@L349C      ldy   #$01
            lda   (temp06),y
            sta   @L348F
            iny
            lda   (temp06),y
            sta   @L348E
            ldy   #$0c
            sty   @L348B
            lda   (temp06),y
            sta   track
            iny
            lda   (temp06),y
            iny
            sty   $02
            sta   sector
            lda   BAS_MEMSIZE+1
            sta   rwtsbuf+1
            ldy   #$00
            sty   rwtsbuf
            lda   #$83
            ldy   #$39
            jsr   rwts
            bcc   @L34D2
            jmp   error

@L34D2      ldx   BI_VADDR+1
            lda   BI_VADDR
            ldy   BI_FBITS+1
            bmi   @L34E9
            ldy   #$01
            lda   (BAS_MEMSIZE),y
            sta   $04
            dey
            tax
            lda   (BAS_MEMSIZE),y
            sta   $03
@L34E9      cpx   BAS_MEMSIZE+1
            bcc   @L34F0
            lda   #$0e
            rts

@L34F0      sec
            sbc   #$04
            bcs   @L34F6
            dex
@L34F6      sta   $08
            stx   $09
            ldy   #$00
@L34FC      lda   (BAS_MEMSIZE),y
            sta   ($08),y
            iny
            bne   @L34FC
            lda   $08
            sta   rwtsbuf
            ldy   $09
            iny
            sty   rwtsbuf+1
@L350E      ldy   $02
            bne   @L3515
            jmp   @L3442

@L3515      lda   (temp06),y
            beq   @L353E
            sta   track
            iny
            lda   (temp06),y
            sta   sector
            iny
            sty   $02
            lda   #$83
            ldy   #$39
            jsr   rwts
            bcc   @L3531
            jmp   error

@L3531      inc   rwtsbuf+1
            lda   rwtsbuf+1
            cmp   BAS_MEMSIZE+1
            bcc   @L350E
            lda   #$0e
            rts

@L353E      clc
            rts

L3540       ldx   #$00
@L3542      lda   $0200,y
            iny
            cmp   #$a0
            beq   @L3542
@L354A      cmp   #$8d
            beq   @L355C
            cmp   #$ac
            beq   @L355C
            sta   $0201,x
            inx
            lda   $0200,y
            iny
            bne   @L354A
@L355C      stx   $0200
            dey
            sty   BI_XLEN
            lda   #$7e
            sta   BI_XTRNADDR
            lda   #$35
            sta   BI_XTRNADDR+1
            lda   #$00
            sta   BI_XCNUM
            lda   #$10
            sta   BI_PBITS
            lda   #$94
            sta   BI_PBITS+1
            clc
            rts

            ldx   $0200
            bne   @L3587
            lda   #$10
            sec
            rts

@L3587      cpx   #$1f
            bcc   @L3590
            lda   #$1e
            sta   $0200
@L3590      lda   BI_VSLOT
            sta   BI_DEFSLT
            asl
            asl
            asl
            asl
            ldx   BI_VDRIV
            stx   BI_DEFDRV
            dex
            beq   @L35A5
            ora   #$80
@L35A5      sta   unit
            lda   #$80
            sta   rwtscmd
            lda   BI_FBITS+1
            bpl   @L35BF
            ldx   BI_VLNTH+1
            lda   BI_VLNTH
            clc
            adc   #$04
            bcc   @L35D9
            bcs   @L35D8

@L35BF      lda   BAS_PRGEND+1
            sec
            sbc   BAS_TEXTTAB+1
            tax
            lda   BAS_PRGEND
            sec
            sbc   BAS_TEXTTAB
            bcs   @L35CD
            dex
@L35CD      stx   BI_VLNTH+1
            sta   BI_VLNTH
            clc
            adc   #$02
            bcc   @L35D9
@L35D8      inx
@L35D9      inx
            cmp   #$00
            beq   @L35DF
            inx
@L35DF      stx   L37FB
            cpx   #$7b
            bcc   @L35EA
            lda   #$0e
            sec
            rts

@L35EA      ldy   BAS_MEMSIZE+1
            iny
            iny
            iny
            sty   rwtsbuf+1
            sty   temp06+1
            lda   #$00
            sta   L36C2
            sta   temp06
            sta   rwtsbuf
            sta   sector
            lda   #$11
            sta   track
            ldy   #$39
            lda   #$83
            jsr   rwts
            bcc   @L3612
            jmp   error

@L3612      ldy   #$01
            lda   (temp06),y
            cmp   #$11
            beq   @L361D
@L361A      jmp   error

@L361D      iny
            lda   (temp06),y
            cmp   #$0f
            bne   @L361A
            jsr   L37FC
            bcc   @L362A
            rts

@L362A      inc   BAS_MEMSIZE+1
            inc   BAS_MEMSIZE+1
            ldx   L37FB
            ldy   #$00
            tya
@L3634      sta   (BAS_MEMSIZE),y
            iny
            bne   @L3634
            ldy   #$0c
            sty   $08
            ldy   #$c1
L363F       lda   (temp06),y
            beq   @L36B5
            tya
            and   #$01
            beq   @L364F
            lda   #$00
            sta   L36C6
            beq   @L3654

@L364F      lda   #$08
            sta   L36C6
@L3654      tya
            sec
            sbc   #$38
            and   #$fe
            lsr
            lsr
            sta   L36C4
            lda   (temp06),y
            pha
            sty   $09
            ldy   #$07
@L3666      rol
            bcs   @L366C
            dey
            bpl   @L3666
@L366C      tya
            clc
            adc   L36C6
            sta   L36C6
            ldy   $08
            lda   L36C2
            bne   @L368A
            lda   L36C4
            sta   L36C2
            lda   L36C6
            sta   L36C3
            pla
            bne   @L3699
@L368A      lda   L36C4
            sta   (BAS_MEMSIZE),y
            iny
            lda   L36C6
            sta   (BAS_MEMSIZE),y
            iny
            sty   $08
            pla
@L3699      ldy   #$08
@L369B      rol
            bcs   @L36A1
            dey
            bne   @L369B
@L36A1      clc
@L36A2      ror
            cpy   #$08
            beq   @L36AA
            iny
            bne   @L36A2
@L36AA      ldy   $09
            sta   (temp06),y
            dex
            beq   L36C7
            cmp   #$00
            bne   L363F
@L36B5      dey
L36B6       cpy   #$37
            bne   L363F
            dec   BAS_MEMSIZE+1
            dec   BAS_MEMSIZE+1
            lda   #$09
            sec
            rts

L36C2       !byte $00
L36C3       !byte $00
L36C4       !byte $00
L36C5       !byte $00
L36C6       !byte $00

L36C7       dec   BAS_MEMSIZE+1
            dec   BAS_MEMSIZE+1
            lda   #$81
            sta   rwtscmd
            lda   #$11
            sta   track
            lda   #$00
            sta   sector
            lda   temp06+1
            sta   rwtsbuf+1
            lda   #$83
            ldy   #$39
            jsr   rwts
            bcc   @L36EB
@L36E8      jmp   error

@L36EB      lda   L36C2
            sta   track
            lda   L36C3
            sta   sector
            dec   rwtsbuf+1
            lda   #$83
            ldy   #$39
            jsr   rwts
            bcs   @L36E8
            dec   rwtscmd               ;was write ($81), now read ($80)
            lda   temp06+1
            sta   rwtsbuf+1
            lda   #$11
            sta   track
            lda   #$0f
            sta   sector
@L3715      ldy   #>rwtscmd
            lda   #<rwtscmd
            jsr   rwts
            bcc   @L3721
            jmp   error

@L3721      lda   #$0b
@L3723      tay
            lda   (temp06),y
            beq   @L3739
            bmi   @L3739
            tya
            clc
            adc   #$23
            bcc   @L3723
            dec   sector
            bne   @L3715
            lda   #$11
            sec
            rts

@L3739      lda   L36C2
            sta   (temp06),y
            iny
            lda   L36C3
            sta   (temp06),y
            iny
            ldx   BI_FBITS+1
            bpl   @L374E
            lda   #$04
            bne   @L3750

@L374E      lda   #$02
@L3750      sta   (temp06),y
            iny
            ldx   #$00
@L3755      lda   $0201,x
            sta   (temp06),y
            iny
            inx
            cpx   $0200
            bne   @L3755
@L3761      cpx   #$1e
            beq   @L376D
            lda   #$a0
            sta   (temp06),y
            inx
            iny
            bne   @L3761
@L376D      lda   L37FB
            sta   (temp06),y
            iny
            lda   #$00
            sta   (temp06),y
            lda   #$81
            sta   rwtscmd
            lda   #$83
            ldy   #$39
            jsr   rwts
            bcc   @L3788
            jmp   error

@L3788      dec   temp06+1
            ldx   BI_FBITS+1
            bpl   @L37AF
            ldx   BI_VADDR+1
            lda   BI_VADDR
            sec
            sbc   #$04
            bcs   @L379B
            dex
@L379B      sta   $08
            stx   $09
            ldy   #$00
            lda   BI_VADDR
            sta   ($08),y
            iny
            lda   BI_VADDR+1
            sta   ($08),y
            iny
            bne   @L37B9
@L37AF      lda   #$ff
            sta   $08
            lda   #$07
            sta   $09
            ldy   #$00
@L37B9      lda   BI_VLNTH
            sta   ($08),y
            iny
            lda   BI_VLNTH+1
            sta   ($08),y
            ldy   #$0c
@L37C6      lda   $08
            sta   rwtsbuf
            lda   $09
            sta   rwtsbuf+1
            lda   (temp06),y
            beq   @L37F4
            iny
            sta   track
            lda   (temp06),y
            sta   sector
            iny
            sty   L37FB
            lda   #$83
            ldy   #$39
            jsr   rwts
            bcc   @L37ED
            jmp   error

@L37ED      inc   $09
            ldy   L37FB
            bne   @L37C6
@L37F4      lda   #$00
            sta   $0800
            clc
            rts

L37FB       !byte $00

L37FC       ldy   BAS_MEMSIZE+1
            iny
            iny
            sty   rwtsbuf+1
            sty   $1a
            lda   #$00
            sta   rwtsbuf
            sta   $19
            lda   #$11
            sta   track
            lda   #$0f
            sta   sector
@L3816      lda   #$83
            ldy   #$39
            jsr   rwts
            bcc   @L3822
            jmp   error

@L3822      ldy   #$01
            lda   ($19),y
            cmp   #$11
            beq   @L382D
            jmp   error

@L382D      lda   #$0e
@L382F      pha
            tay
            ldx   #$00
@L3833      lda   ($19),y
            bne   @L383A
            pla
            clc
            rts

@L383A      cmp   $0201,x
            bne   @L3852
            inx
            iny
            cpx   $0200
            bne   @L3833
@L3846      cpx   #$1e
            beq   @L385F
            lda   ($19),y
            inx
            iny
            cmp   #$a0
            beq   @L3846
@L3852      pla
            clc
            adc   #$23
            bcc   @L382F
            dec   sector
            bne   @L3816
            clc
            rts

@L385F      pla
            tay
            dey
            lda   ($19),y
            bmi   @L3877
            cmp   #$04
            beq   @L3882
            cmp   #$02
            bne   @L3873
            lda   BI_FBITS+1
            bpl   @L3887
@L3873      lda   #$0d
            sec
            rts

@L3877      lda   #$0a
            sec
            rts

@L387B      iny
            iny
            iny
            tya
            pha
            bne   @L3852
@L3882      lda   BI_FBITS+1
            bpl   @L3873
@L3887      dey
            dey
            tya
            pha
            clc
            adc   #$21
            tay
            lda   ($19),y
            cmp   #$7b
            bcc   @L389A
            pla
            lda   #$0e
            sec
            rts

@L389A      pla
            tay
            lda   ($19),y
            bmi   @L387B
            sta   L36C4
            lda   #$ff
            sta   ($19),y
            iny
            lda   ($19),y
            sta   L36C5
            lda   #$81
            sta   rwtscmd
            lda   #$83
            ldy   #$39
            jsr   rwts
            bcc   @L38BE
            jmp   error

@L38BE      dec   rwtscmd
            lda   L36C4
            sta   track
            lda   L36C5
            sta   sector
            lda   #$83
            ldy   #$39
            jsr   rwts
            bcc   L38D9
            jmp   error

L38D9       jsr   L38F7
            ldy   #$0c
L38DE       lda   ($19),y
            beq   L38F5
            sta   L36C4
            iny
            lda   ($19),y
            sta   L36C5
            iny
            sty   $08
L38EE       jsr   L38F7
            ldy   $08
            bne   L38DE
L38F5       clc
            rts

L38F7       lda   L36C4
            asl
            asl
            clc
            adc   #$38
            tay
            lda   L36C5
            cmp   #$08
            bcs   @L3908
            iny
@L3908      and   #$07
            tax
            lda   #$01
@L390D      dex
            bmi   @L3913
            asl
            bne   @L390D
@L3913      ora   (temp06),y
            sta   (temp06),y
            rts

; Input Y,A is a pointer to a table containing command, unit, memsize, track and
; sector. Copy these into memory locations or registers to operate on, then read
; or write a track and sector.
; 
; Note that the table pointer is constant -- there's only one in this program --
; so the indirection and copying is superfluous.
rwts        sta   rwtsptr               ;always #$83
            sty   rwtsptr+1             ;always #$39
            ldy   #$01                  ;unit
            lda   (rwtsptr),y
            sta   block_params+1
            iny
            lda   (rwtsptr),y           ;memsize
            sta   rwtsbuf_tmp
            iny
            lda   (rwtsptr),y           ;memsize+1
            sta   rwtsbuf_tmp+1
            iny
            lda   (rwtsptr),y           ;track (A)
            pha
            iny
            lda   (rwtsptr),y           ;sector (Y)
            tay
            pla
            jsr   ts_to_block
            sta   block_params+4        ;block number lo
            sty   block_params+5        ;block number hi
            stx   rwtsbuf_tmp-1
            lda   BAS_MEMSIZE+1
            sta   block_params+3        ;block buffer msb
            jsr   P8_MLI
            !byte P8_READ_BLOCK
            !word block_params
            bcs   error
            ldy   #$00
            lda   (rwtsptr),y
            cmp   #$81                  ;MLI write_block?
            beq   write
            lda   BAS_MEMSIZE+1
            clc
            adc   rwtsbuf_tmp-1
            sta   src+2
            lda   #$00
            sta   src+1
            lda   rwtsbuf_tmp
            sta   dst+1
            lda   rwtsbuf_tmp+1
            sta   dst+2
copy_sect_buf
            ldy   #$00
src         lda   $9600,y               ;updated in code
dst         sta   $2000,y               ;updated in code
            iny
            bne   src
            rts

error       sec
            lda   #$08
            rts

; Params for virtual RWTS command. This will be translated into a ProDOS MLI
; READ_BLOCK or WRITE_BLOCK. The internal RWTS call takes a pointer to this
; table, although there is only one table.
rwtscmd     !byte $80
unit        !byte $60                   ;(slot 6 on startup)
rwtsbuf     !word $0000
track       !byte $00
sector      !byte $00
; Params for MLI READ_BLOCK and WRITE_BLOCK.
block_params
            !byte 3
            !byte $00                   ;unit number
            !word $0000                 ;block buffer
            !word $0000                 ;block number
            !byte $00
rwtsbuf_tmp !word $0000
blocklo     !byte $00
sector_tmp  !byte $00                   ;temp copy of 'sector' used by ts_to_block

write       lda   BAS_MEMSIZE+1
            clc
            adc   rwtsbuf_tmp-1
            sta   dst+2
            lda   #$00
            sta   dst+1
            lda   rwtsbuf_tmp
            sta   src+1
            lda   rwtsbuf_tmp+1
            sta   src+2
            jsr   copy_sect_buf
            jsr   P8_MLI
            !byte P8_WRITE_BLOCK
            !word block_params
            rts

; On entry, track in A, sector in Y. Returns ProDOS block hi,lo in Y,A. Returns
; which half of block in X (0 first, 1 second) as one 512-byte block corresponds
; to two 256-byte sectors.
; 
; sector_tmp is a copy of 'sector'. There is some (unnecessary?) indirection
; where the track,sector is passed in registers instead of using the table they
; are already stored in, meaning a temp has to be used to save this register.
; And these registers are loaded via an indirect pointer to the table. But there
; is only one table, so all the indirection and copies are for no purpose.
; 
; TS to block algorithm can be found in B.5 - DOS 3.3 Disk Organization.
; 
;       Block = (8 * Track) + Sector Offset
; 
;         Sector : 0 1 2 3 4 5 6 7 8 9 A B C D E F
;  Sector Offset : 0 7 6 6 5 5 4 4 3 3 2 2 1 1 0 7
;   Half of Block: 1 1 2 1 2 1 2 1 2 1 2 1 2 1 2 2
; 
; This section is 95 bytes long. I think it could be made shorter and faster
; with a 16-byte table lookup of sector offsets, with the block half flag in bit
; 0 or bit 7 of each offset.
ts_to_block sty   sector_tmp            ;save sector
            tax                         ;track in X
            ldy   #$00
            tya
@add8       dex                         ;multiply track X*8 -> block Y,A
            bmi   @sector
            clc
            adc   #$08
            bcc   @add8
            iny
            bne   @add8                 ;always
@sector     sta   blocklo               ;save A
            ldx   #$00                  ;equiv. to inx, since X=$FF
            lda   sector_tmp            ;was this sector 0?
            bne   @sector01
            lda   blocklo               ;restore A
            rts

@sector01   cmp   #$01                  ;sector 1?
            bne   @sector0e
            lda   blocklo
            clc
            adc   #$07                  ;increase block num by 7
            bcc   @rts
            iny
@rts        rts

@sector0e   cmp   #$0e                  ;sector E?
            bne   @sector0f
            lda   blocklo
            inx                         ;just increase X by 1
            rts

@sector0f   cmp   #$0f                  ;sector F?
            bne   @sector_other
            lda   blocklo
            clc
            adc   #$07                  ;increase block num by 7
            bcc   @ret
            iny
@ret        inx                         ;and increase X by 1
            rts

@sector_other
            lda   sector_tmp            ;redundant, sector_tmp already in A
            lsr                         ;test even/odd
            bcs   @odd
            lda   #$0e                  ;even sector, subtract $0E
            inx                         ;bump X when even
            bne   @sub                  ;always
@odd        lda   #$0f                  ;odd sector, subtract $0E+1
@sub        sec
            sbc   sector_tmp
            lsr
            clc
            adc   blocklo               ;add A/2 to block num
            bcc   @rts1
            iny                         ;(bump blockhi if wrapped)
@rts1       rts

            !fill 1,$c6                 ;maybe type-in artifact
