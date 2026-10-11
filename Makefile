use_torc?=0

CC=gcc
CFLAGS=-O3 -std=c99 -D_XOPEN_SOURCE=700 -D_BSD_SOURCE
LDFLAGS=-lm

ifeq ($(use_torc),1)
CC = mpicc
CFLAGS += -D_USE_TORC_=1 `torc_cflags`
LDFLAGS += `torc_libs`
endif

TARGETS = evoshort evoboundary evorestarts

all: $(TARGETS)

evoshort: src/example_short.c src/cmaes.c
	$(CC) $(CFLAGS) -o evoshort src/example_short.c src/cmaes.c $(LDFLAGS)

evoboundary: src/example_boundary.c src/boundary_transformation.c src/cmaes.c
	$(CC) $(CFLAGS) -o evoboundary src/example_boundary.c src/boundary_transformation.c src/cmaes.c $(LDFLAGS)

evorestarts: src/example_restarts.c src/cmaes.c
	$(CC) $(CFLAGS) -o evorestarts src/example_restarts.c src/cmaes.c $(LDFLAGS)

.PHONY: clean
clean:
	rm -f evoshort evoboundary evorestarts *.o
	rm -rf *.dSYM

.PHONY: clear
clear:
	rm -rf *.dat curgen_db*.txt actparcmaes.par
