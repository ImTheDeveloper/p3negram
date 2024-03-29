srcdir=.

CFLAGS=-g -O2
LDFLAGS= -L/usr/local/lib -L/usr/lib -L/usr/lib  
CPPFLAGS= -I/usr/local/include -I/usr/include -I/usr/include -I/usr/include/lua5.2  
DEFS=-DHAVE_CONFIG_H
COMPILE_FLAGS=${CFLAGS} ${CPFLAGS} ${CPPFLAGS} ${DEFS} -Wall -Wextra -Werror -Wno-deprecated-declarations -fno-strict-aliasing -fno-omit-frame-pointer -ggdb -Wno-unused-parameter -fPIC

EXTRA_LIBS=-lconfig -lz -levent -lm   -lreadline -llua5.2  -ldl -lssl -lcrypto  
LOCAL_LDFLAGS=-rdynamic -ggdb -levent ${EXTRA_LIBS}
LINK_FLAGS=${LDFLAGS} ${LOCAL_LDFLAGS}

DEP=${srcdir}/dep
AUTO=${srcdir}/auto
EXE=${srcdir}/bin
OBJ=${srcdir}/objs
LIB=${srcdir}/libs
DIR_LIST=${DEP} ${AUTO} ${EXE} ${OBJ} ${LIB} ${DEP}/auto ${OBJ}/auto

EXE_LIST=${EXE}/generate ${EXE}/tlc ${EXE}/telegram-cli
LIB_LIST=${LIB}/libtgl.a

TG_OBJECTS=${OBJ}/main.o ${OBJ}/loop.o ${OBJ}/interface.o ${OBJ}/lua-tg.o
TGL_OBJECTS=${OBJ}/net.o ${OBJ}/mtproto-common.o ${OBJ}/mtproto-client.o ${OBJ}/queries.o ${OBJ}/structures.o ${OBJ}/binlog.o ${OBJ}/auto/auto.o ${OBJ}/tgl.o ${OBJ}/updates.o ${OBJ}/tgl-timers.o
TLC_OBJECTS=${OBJ}/tlc.o ${OBJ}/tl-parser.o ${OBJ}/crc32.o
TLD_OBJECTS=${OBJ}/dump-tl-file.o
GENERATE_OBJECTS=${OBJ}/generate.o
COMMON_OBJECTS=${OBJ}/tools.o
OBJ_LIST=${TG_OBJECTS} ${TLC_OBJECTS} ${GENERATE_OBJECTS} ${COMMON_OBJECTS} ${TGL_OBJECTS} ${TLD_OBJECTS}
OBJ_C=${TLC_OBJECTS} ${GENERATE_OBJECTS} ${COMMON_OBJECTS} ${TGL_OBJECTS} ${TLD_OBJECTS}

DEPENDENCE=$(subst ${OBJ}/,${DEP}/,$(patsubst %.o,%.d,${OBJ_LIST}))
DEPENDENCE_LIST=${DEPENDENCE}

INCLUDE=-I. -I${srcdir}
CC=gcc

.SUFFIXES:

.SUFFIXES: .c .h .o

all: ${EXE_LIST} ${DIR_LIST} ${LIB_LIST}
create_dirs_and_headers: ${DIR_LIST} ${AUTO}/auto.c ${AUTO}/auto-header.h ${AUTO}/constants.h
create_dirs: ${DIR_LIST}
dump-tl: ${EXE}/dump-tl-file

${DIR_LIST}:
	@test -d $@ || mkdir -p $@

-include ${DEPENDENCE_LIST}

${TG_OBJECTS} ${TGL_OBJECTS}: ${AUTO}/constants.h ${AUTO}/auto-header.h

${TG_OBJECTS}: ${OBJ}/%.o: %.c | create_dirs_and_headers
	${CC} ${INCLUDE} ${COMPILE_FLAGS} -c -MP -MD -MF ${DEP}/$*.d -MQ ${OBJ}/$*.o -o $@ $<

${OBJ_C}: ${OBJ}/%.o: %.c | create_dirs
	${CC} ${INCLUDE} ${COMPILE_FLAGS} -c -MP -MD -MF ${DEP}/$*.d -MQ ${OBJ}/$*.o -o $@ $<

${EXE}/tlc: ${TLC_OBJECTS} ${COMMON_OBJECTS}
	${CC} ${TLC_OBJECTS} ${COMMON_OBJECTS} ${LINK_FLAGS} -o $@

${EXE}/telegram-cli: ${TG_OBJECTS} ${COMMON_OBJECTS} ${LIB}/libtgl.a
	${CC} ${TG_OBJECTS} ${COMMON_OBJECTS} ${LINK_FLAGS} -L${LIB} -l tgl -o $@

${LIB}/libtgl.a: ${TGL_OBJECTS} ${COMMON_OBJECTS}
	ar ruv $@ ${TGL_OBJECTS} ${COMMON_OBJECTS}

${EXE}/generate: ${GENERATE_OBJECTS} ${COMMON_OBJECTS}
	${CC} ${GENERATE_OBJECTS} ${COMMON_OBJECTS} ${LINK_FLAGS} -o $@

${AUTO}/scheme.tlo: ${AUTO}/scheme.tl ${EXE}/tlc
	${EXE}/tlc -e $@ ${AUTO}/scheme.tl

${AUTO}/scheme.tl: ${srcdir}/scheme.tl ${srcdir}/encrypted_scheme.tl ${srcdir}/binlog.tl ${srcdir}/append.tl | ${AUTO}
	cat $^ > $@

${AUTO}/scheme2.tl: ${AUTO}/scheme.tl ${EXE}/tlc
	${EXE}/tlc -E ${AUTO}/scheme.tl 2> $@  || ( cat $@ && rm $@ && false )

${AUTO}/auto.c: ${AUTO}/scheme.tlo ${EXE}/generate
	${EXE}/generate ${AUTO}/scheme.tlo > $@

${AUTO}/auto-header.h: ${AUTO}/scheme.tlo ${EXE}/generate
	${EXE}/generate -H ${AUTO}/scheme.tlo > $@

${AUTO}/constants.h: ${AUTO}/scheme2.tl ${srcdir}/gen_constants_h.awk
	awk -f ${srcdir}/gen_constants_h.awk < $< > $@

${EXE}/dump-tl-file: ${OBJ}/auto/auto.o ${TLD_OBJECTS}
	${CC} ${OBJ}/auto/auto.o ${TLD_OBJECTS} ${LINK_FLAGS} -o $@

clean:
	rm -rf ${DIR_LIST} config.log config.status > /dev/null || echo "all clean"

