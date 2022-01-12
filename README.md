# a2-dbldos

DBLDOS is a program written by Jason Coleman in July 1986 which adds 3 commands, DCAT/DLOAD/DSAVE, to
BASIC.SYSTEM in ProDOS. I found this on an old disk of mine, and originally couldn't find the source,
so I set out to disassemble it. I did find the [source](#original-source) later, but it came as
raw machine language code to type in, not assembler source.

DCAT is experimentally confirmed to CATALOG DOS 3.3 disks, and DLOAD to load BASIC and
binary programs from a DOS 3.3 disk. I didn't try DSAVE.

## Disassembly

[SourceGen](https://6502bench.com) project [DBLDOS.dis65](./DBLDOS.dis65) is barely started, but
I got far enough to figure out what DBLDOS did, and note some improvements.

[DBLDOS.txt](./DBLDOS.txt) is disassembly output in "common" expression format exported to a text file.

[BI.sym65](./BI.sym65) is a SourceGen symbol file for the ProDOS 8 Basic Interpreter that I
created based on the ProDOS 8 Technical Reference Manual. This might actually be useful.

## Original source

Eventually, I found the source to *Double-Duty DOS* in [Compute! Magazine Oct 1987 pg 90](https://archive.org/details/1987-10-compute-magazine/page/n91/mode/2up?view=theater).
(Alternate sources: [Atari Magazines](https://www.atarimagazines.com/compute/issue89/Double_Duty_DOS.php) or [Color Computer Archive](https://colorcomputerarchive.com/repo/Documents/Magazines/Compute%20(Clean)/Compute_Issue_089_1987_Oct.pdf).)

There was no assembler source provided in the article, only machine language (hex) code.

I think I may have typed my copy in myself from the magazine. There were a few other programs in that
issue I'd have been more likely to spend the effort on (graphics and games!), but I was a weird kid. It's evident that I copied
a bunch of DOS programs to ProDOS (such as https://github.com/ursetto/a2composer), and with little way to acquire programs
other than typing them in, I'm guessing I typed it in.

## Analysis

The code has some interesting idiosyncrasies; I would say the author was learning and trying out techniques.

It tends to share data between subroutines by copying it into data structures inside the code, rather than using zero page; sometimes data is stored redundantly in multiple places.

It repeatedly sets up a pointer (Y,A) to an RWTS table and then JSRs to a common RWTS subroutine, as if the author wanted to design an API call; however there is only one table, only used internally. This abstraction leads to a lot of unneeded copying and shuffling and temporaries, as the data is marshaled from registers into a table, in order to free up registers to point to the table, which is used by a subroutine, which copies the registers to zero page to allow indirect offset into the table, to unmarshal the data from the table back into registers again, which are copied to more temporaries or another data area. Much could be replaced with direct loads from a single well-defined table or zero page.

Some other findings:

### Relocation

The code allocates some high memory and relocates itself into that memory using a primitive (though clever!) relocation algorithm. Normally, you might scan the area for opcodes with 16-bit operands,
and rewrite their high bytes. (See [RBOOT](https://ursetto.github.io/a2-hrcg-teardown/RBOOT.html), or the `TYPE` program in Beneath Apple ProDOS page A-30, for possible implementations.) At the luxury
end you can have your assembler generate a relocation table, and relocate using that, which is safer in the presence of data. (See [RLOAD](https://ursetto.github.io/a2-hrcg-teardown/RLOAD.html).)

This code, however, resides at $3100-$3AFF at startup and the relocator rewrites any occurrence of bytes $31-$3A within to the new pages. No parsing of opcodes is done at all. This requires a few interesting code properties:

- It can't use any of these bytes as opcodes. Fortunately only $31, $35, $36, $38 and $39 are valid opcodes, and only $38 (SEC) is common. It does use $38 and handles it specially.
- It can't use any of them as immediate 8-bit data, like LDA #$39, except when they represent the high byte of an address.
- It can't use any ASCII numeric digits ($30-$39), although usually these have the high bit set ($B0-$B9) anyway.

`SEC` ($38) is the only problem. The code uses $38 often, but does not relocate it like everything else -- instead it hardcodes the locations of two $38's in 16-bit operands, and explicitly rewrites them.

This is kind of clever, but also hacky and fragile, the textbook definition of a kludge. It would have been more robust, and probably simpler, to use a standard method described earlier.

### Track/sector to ProDOS block

The heart of reading a DOS 3.3 disk from ProDOS is to convert DOS 3.3 track and sector numbers to
ProDOS blocks, then parse that data (VTOC, data blocks) as DOS would. This sector mapping is always
the same on a Disk ][ device. Note each block is made up of two sectors.

I found the track/sector to block code could easily be improved, and the `Makefile` will generate
a new version `ZDBLDOS` with this updated code.

Here's a description of what the T/S to block code is trying to do.

```
; On entry, track in A, sector in Y. Returns ProDOS block hi,lo in Y,A. Returns
; which half of block in X (0 first, 1 second) as one 512-byte block corresponds
; to two 256-byte sectors.
;
; TS to block algorithm can be found in B.5 - DOS 3.3 Disk Organization.
;          Block = (8 * Track) + Sector Offset
;         Sector : 0 1 2 3 4 5 6 7 8 9 A B C D E F
;  Sector Offset : 0 7 6 6 5 5 4 4 3 3 2 2 1 1 0 7
;   Half of Block: 1 1 2 1 2 1 2 1 2 1 2 1 2 1 2 2
```

The original code is 96 bytes and computes the sector offset completely in code. I didn't count
cycles but it's pretty slow (though not compared to disk access!)

```
ts_to_block sty   sector_tmp            ;save sector
            tax                         ;track in X
            ldy   #$00
            tya
@add8       dex                         ;mul track X*8 -> block Y,A
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
            lda   sector_tmp            ;redundant
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
```


This can easily be made shorter (50 bytes) and faster with a 16-byte table
lookup of sector offsets, with the block half flag in bit 0 or bit 7
of each offset. This is what I came up with; the T/S to block algorithm has
undoubtedly been implemented many many times, probably even more efficiently.

```
ts_to_block
@trk = $00                              ;16-bit block computation
            sta   @trk                  ;save track
            ldx   #0
            stx   @trk+1
            lda   sector_offsets,y
            bpl   +
            inx                         ;bump X if hi bit set, X has block half
+           and   #$7f                  ;mask off hi bit, A has sector offset
            asl   @trk                  ;multiply track by 8 to get block
            asl   @trk
            asl   @trk
            rol   @trk+1                ;track < 64, so only 3rd ASL can overflow
            ;clc                        ;carry cleared by ROL
            adc   @trk                  ;add sector offset to block
            sta   @trk
            lda   #0
            adc   @trk+1
            tay                         ;return >block in Y
            lda   @trk                  ;return <block in A
            rts

; The 16 sector offsets are here with the high bit $80 OR'ed in
; to indicate the second half of the ProDOS block.
sector_offsets
            !byte $00, $07, $86, $06, $85, $05, $84, $04
            !byte $83, $03, $82, $02, $81, $01, $80, $87
```

## References

- Beneath Apple ProDOS, A-30, for an example program (TYPE) that adds commands to the Basic Interpreter
- ProDOS 8 Technical Reference Manual, A.3.2
- ProDOS 8 TRM, B.5 - DOS 3.3 Disk Operation 

