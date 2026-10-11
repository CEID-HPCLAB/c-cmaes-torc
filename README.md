# c-cmaes-torc

**CMA-ES optimization with TORC-parallel objective-function evaluation.**

This repository extends [Nikolaus Hansen's c-cmaes](https://github.com/CMA-ES/c-cmaes) with examples that evaluate candidate solutions concurrently using [TORC](https://github.com/CEID-HPCLAB/torc_lite). It provides serial and parallel builds from the same example sources, with support for multicore machines and MPI clusters.

The CMA-ES optimization library is retained from upstream. The TORC integration is in the examples, Makefile, and build/run workflow.

## How it works

The Covariance Matrix Adaptation Evolution Strategy (CMA-ES) is a derivative-free method for minimizing nonlinear functions of continuous variables. It samples a population of candidate solutions and adapts its search distribution using their objective values.

In the parallel examples, each generation follows four steps:

1. Sample a population with `cmaes_SamplePopulation()`.
2. Submit one TORC task per candidate solution.
3. Wait for all objective evaluations with `torc_waitall()`.
4. Update the search distribution with `cmaes_UpdateDistribution()`.

Population evaluation is parallel; the optimizer advances synchronously between generations. TORC distributes tasks across MPI processes and local worker threads. The restart example performs successive optimization runs; it does not run independent restarts concurrently.

Parallel execution is most useful for expensive objective functions, such as numerical simulations. The supplied inexpensive test functions primarily demonstrate usage; task scheduling and communication can cost more than their evaluation.

## Examples

| Executable | Source | Purpose |
| --- | --- | --- |
| `evoshort` | [example_short.c](src/example_short.c) | Minimal optimization loop; best starting point for a custom objective. |
| `evoboundary` | [example_boundary.c](src/example_boundary.c) | Optimization with a transformation into prescribed bounds. |
| `evorestarts` | [example_restarts.c](src/example_restarts.c) | Benchmark objectives and restarts with increasing population size. |

See [Parallel implementation notes](#parallel-implementation-notes) for task argument types and benchmark initialization.

## Requirements

For a serial build:

- A C compiler and GNU Make.
- The standard C math library.

For a TORC build, additionally:

- An MPI implementation, such as MPICH or Open MPI, with `mpicc`, an MPI Fortran wrapper for configuring TORC, and `mpirun` or `mpiexec`.
- POSIX threads.
- A separately installed copy of TORC_LITE.

Use the same MPI installation to build TORC, compile these examples, and launch the application. TORC requires `MPI_THREAD_SERIALIZED` or `MPI_THREAD_MULTIPLE` for standards-compliant execution. Its current portability notes primarily cover Linux; consult the [TORC documentation](https://github.com/CEID-HPCLAB/torc_lite#readme) for other systems.

## Install TORC_LITE

TORC_LITE is an external dependency and is not bundled with this repository. The following installs it under your home directory without administrator privileges:

```bash
git clone https://github.com/CEID-HPCLAB/torc_lite.git
cd torc_lite

./configure --prefix="$HOME/.local/torc" \
    CC=mpicc F77=mpif90 CFLAGS="-O2 -std=gnu17"
make
make install

export PATH="$HOME/.local/torc/bin:$PATH"
cd ..
```

If your MPI installation provides `mpifort` instead of `mpif90`, use `F77=mpifort`. The explicit C dialect above is suitable for GCC/Clang and avoids C23 interpretation changes affecting legacy function declarations.

The repository includes `configure`. Run `autoreconf -fi` before configuring only if generated build files are missing or you have modified the Autotools inputs; this requires Autoconf and Automake.

Check that the installed helper scripts are available:

```bash
command -v mpicc
command -v mpirun
command -v torc_cflags
command -v torc_libs
torc_cflags
torc_libs
```

`torc_cflags` supplies include flags, and `torc_libs` supplies linker flags. The application Makefile invokes both automatically. Add the `PATH` export to your shell startup file if you want it available in future sessions. On a cluster, make the installation and runtime environment available on every participating node.

## Build

Clone this repository and work from its root directory:

```bash
git clone https://github.com/CEID-HPCLAB/c-cmaes-torc.git
cd c-cmaes-torc
```

### TORC-parallel build

```bash
make clean
make use_torc=1
```

This uses `mpicc`, defines `_USE_TORC_`, and obtains TORC compiler/linker flags from the installed helper scripts. It builds all three executables.

### Serial build

```bash
make clean
make use_torc=0
```

Serial mode is the default, so plain `make` also selects it. TORC and MPI are not required in this mode. To select another C compiler, for example:

```bash
make use_torc=0 CC=clang
```

Always run `make clean` when switching build modes: the executable names are shared, and changing `use_torc` alone does not force Make to rebuild them. The commands here use the root Makefile, which contains the TORC build switch.

## Run

Run from the repository root so that `cmaes_initials.par` and `cmaes_signals.par` are found in the working directory.

With a serial build:

```bash
./evoshort
```

With a TORC build, use one MPI process and four local workers:

```bash
export TORC_WORKERS=4
mpirun -np 1 ./evoshort
```

Or use four MPI processes, each with two workers:

```bash
export TORC_WORKERS=2
mpirun -np 4 ./evoshort
```

`TORC_WORKERS` controls workers per MPI process; `-np` controls the process count. Cluster placement and resource allocation depend on your MPI launcher and scheduler. Ensure the environment variable reaches every process, and allow resources for TORC's communication thread as well as evaluation workers.

For a population of size `lambda`, at most `lambda` candidate evaluations are available concurrently in a generation. Adding workers beyond that does not increase evaluation concurrency. If your objective itself uses threaded libraries, coordinate their thread counts with the TORC worker count.

## Configuration and output

[cmaes_initials.par](cmaes_initials.par) controls the problem dimension, initial point, initial standard deviations, random seed, population size, and stopping criteria. The supplied file sets `N 22`. In the short and boundary examples, the supplied objective accesses the first two coordinates, so use a dimension of at least two.

The restart example additionally reads the first two lines for its objective-function number, restart count, and optional population-growth factor. Choose only objective numbers actually assigned in `rgpFun` in its source. For example:

```text
function number 1
restarts 3 2
```

This selects `f_elli` and requests up to three restarts, doubling the population between runs; stopping criteria can end the sequence earlier.

[cmaes_signals.par](cmaes_signals.par) is reread during optimization and controls progress output, data files, and stopping conditions. The examples do not interpret command-line arguments as optimization settings.

Typical output includes:

| File | Contents |
| --- | --- |
| `actparcmaes.par` | Actual parameter settings used by the optimizer. |
| `allcmaes.dat` | Final optimizer state and results. |
| `outcmaesfit.dat` | Fitness and convergence information. |
| `outcmaesaxlen.dat` | Search-distribution axis lengths. |
| `outcmaesstddev.dat` | Coordinate standard deviations. |
| `outcmaesxmean.dat` | Mean of the search distribution. |
| `outcmaesxrecentbest.dat` | Best candidate of recent generations. |

The `outcmaes*.dat` files depend on the write directives in `cmaes_signals.par`. Plot them using [src/plotcmaesdat.m](src/plotcmaesdat.m) for MATLAB/Octave or [src/plotcmaesdat.sci](src/plotcmaesdat.sci) for Scilab. For MATLAB/Octave, from the run directory:

```matlab
addpath('src');
plotcmaesdat;
```

Use separate working directories, each containing the parameter files, for independent runs to avoid output-file collisions. `make clean` removes executables and object files. `make clear` deletes generated data, including all `*.dat` files in the current directory.

## Use your own objective

Start with `src/example_short.c` and replace `fitfun()` with a function returning the scalar value to minimize:

```c
double fitfun(const double *x, int n)
{
    double value = 0.0;
    for (int i = 0; i < n; ++i)
        value += x[i] * x[i];
    return value;
}
```

Set the corresponding dimension and initial distribution in `cmaes_initials.par`, then rebuild. The existing `taskfun()` wrapper calls this objective and returns its value to the optimizer.

Objective evaluations must be safe to run concurrently: avoid shared mutable state and shared output filenames. Initialize any required model data on every MPI process. Keep task inputs and output storage valid until `torc_waitall()` completes; copy input buffers at task creation when they will be reused for subsequent candidates.

## Parallel implementation notes

The restart task accepts three arguments, matching its task submission. Its input array includes the dimension before the candidate coordinates; the wrapper passes `x + 1` to benchmark functions that access the dimension as `x[-1]`.

In the boundary example, the dimension uses `unsigned long` consistently in the task wrapper and is transferred with `MPI_UNSIGNED_LONG`. The transformed candidate vector is copied when the task is created because the transformation buffer is reused for the next candidate.

Some restart benchmark functions also initialize static state lazily. Initialize that state before concurrent evaluation on each process, or make initialization thread-safe, before using those objectives with multiple workers.

## Documentation and credits

- [Upstream c-cmaes README](https://github.com/CMA-ES/c-cmaes/blob/master/README.md): original implementation and usage information.
- [doc.txt](doc.txt) and [docfunctions.txt](docfunctions.txt): included library documentation.
- [src/cmaes_interface.h](src/cmaes_interface.h): public C interface.
- [TORC_LITE](https://github.com/CEID-HPCLAB/torc_lite): runtime source, API, installation, and portability notes.

The original CMA-ES implementation is by **Nikolaus Hansen**. The TORC integration is maintained by **CEID-HPCLAB**, with contributions by **Panagiotis E. Hadjidoukas**. Please retain the original author and copyright notices when redistributing or extending this code.

## License

See [LICENSE](LICENSE) for the original c-cmaes licensing terms, which offer Apache License 2.0 or GNU LGPL 2.1 or later. TORC_LITE is distributed separately; consult its own license files and source notices for the applicable terms.
