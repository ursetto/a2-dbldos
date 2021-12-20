# a2-dbldos

DBLDOS is a program by Jason Coleman (1986) which adds 3 commands, DCAT/DLOAD/DSAVE, to
BASIC.SYSTEM. I found this on an old disk of mine, and I don't know where it came from,
nor can I find any references to it.

DCAT is experimentally confirmed to CATALOG DOS 3.3 disks, and DLOAD to load BASIC and
binary programs from a DOS 3.3 disk.

It's possible DBLDOS isn't the original name of the program.

## Disassembly

[SourceGen](https://6502bench.com) project [DBLDOS.dis65](./DBLDOS.dis65) is barely started, but
I got far enough to figure out what DBLDOS did.

[DBLDOS.txt](./DBLDOS.txt) is disassembly output in "common" expression format exported to a text file.

[BI.sym65](./BI.sym65) is a SourceGen symbol file for the ProDOS 8 Basic Interpreter that I
created based on the ProDOS 8 Technical Reference Manual. This might actually be useful.

## References

- Beneath Apple ProDOS, A-30, for an example program (TYPE) that adds commands to the Basic Interpreter
- A.3.2, ProDOS 8 Technical Reference Manual
