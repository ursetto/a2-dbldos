# a2-dbldos

DBLDOS is a program written by Jason Coleman in July 1986 which adds 3 commands, DCAT/DLOAD/DSAVE, to
BASIC.SYSTEM in ProDOS. I found this on an old disk of mine, and originally couldn't find the source,
so I set out to disassemble it. I did find the [source](#original-source) later, but it came as
raw machine language code to type in, not assembler source.

DCAT is experimentally confirmed to CATALOG DOS 3.3 disks, and DLOAD to load BASIC and
binary programs from a DOS 3.3 disk. I didn't try DSAVE.

## Disassembly

[SourceGen](https://6502bench.com) project [DBLDOS.dis65](./DBLDOS.dis65) is barely started, but
I got far enough to figure out what DBLDOS did.

[DBLDOS.txt](./DBLDOS.txt) is disassembly output in "common" expression format exported to a text file.

[BI.sym65](./BI.sym65) is a SourceGen symbol file for the ProDOS 8 Basic Interpreter that I
created based on the ProDOS 8 Technical Reference Manual. This might actually be useful.

## Original source

Eventually, I found the source to *Double-Duty DOS* in [Compute! Magazine Oct 1987 pg 90](https://archive.org/details/1987-10-compute-magazine/page/n91/mode/2up?view=theater).
(Alternate sources: [Atari Magazines](https://www.atarimagazines.com/compute/issue89/Double_Duty_DOS.php) or [Color Computer Archive](https://colorcomputerarchive.com/repo/Documents/Magazines/Compute%20(Clean)/Compute_Issue_089_1987_Oct.pdf).)

There was no assembler source provided in the article, only machine language (hex) code.

I'm not sure if I typed this in myself. It seems likely, but there were a few other programs in that
issue I'd have been more likely to spend the effort on. I was a weird kid though, you never know.

## References

- Beneath Apple ProDOS, A-30, for an example program (TYPE) that adds commands to the Basic Interpreter
- A.3.2, ProDOS 8 Technical Reference Manual
