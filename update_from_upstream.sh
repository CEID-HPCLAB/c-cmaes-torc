git fetch upstream

git restore --source=upstream/master -- \
    src/cmaes.c \
    src/cmaes.h \
    src/cmaes_interface.h \
    cmaes_initials.par \
    cmaes_signals.par
