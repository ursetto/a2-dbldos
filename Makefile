# cadius just doesn't behave well
AC=applecommander

all:
	acme -o ZDBLDOS DBLDOS_zb.S
	$(AC) -d prodos.dsk DBLDOS
	$(AC) -p prodos.dsk DBLDOS BIN 0x3000 < DBLDOS
	$(AC) -d prodos.dsk ZDBLDOS
	$(AC) -p prodos.dsk ZDBLDOS BIN 0x3000 < ZDBLDOS
