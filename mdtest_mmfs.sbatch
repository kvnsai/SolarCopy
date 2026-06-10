#!/bin/bash
#SBATCH --partition=defq
#SBATCH --job-name=mdtest_mmfs
#SBATCH --nodes=24
#SBATCH --nodelist=ch3lahpccn[001-032]
#SBATCH --ntasks-per-node=1
#SBATCH --exclusive
#SBATCH --output=results/mdtest_%j.out
#SBATCH --error=results/mdtest_%j.out

set -euo pipefail

# ===== MODULE =====
module load openmpi/gcc/64/4.1.5

# ===== MPI / IB SETTINGS =====
export OMPI_MCA_pml=ob1
export OMPI_MCA_btl=openib,vader,self
export OMPI_MCA_btl_openib_allow_ib=1

# ===== PATHS =====
MMFS_MNT="/mmfs1"
TEST_DIR="${MMFS_MNT}/mdtest_${SLURM_JOB_ID}"
MDTEST_BIN="${MDTEST_BIN:-$(pwd)/bin/mdtest}"   # absolute path for mpirun

# ===== TEST SETTINGS =====
ITEMS=10000      # files per rank
DEPTH=2          # tree depth
BRANCHING=2      # branching factor

# ===== SETUP =====
mkdir -p "${TEST_DIR}" results

if command -v lfs >/dev/null 2>&1; then
    lfs setstripe -c 1 "${TEST_DIR}"    # mdtest creates many small files; stripe=1 is faster
fi

# Build hostfile from SLURM allocation
HOSTFILE="${SLURM_SUBMIT_DIR}/hostfile_${SLURM_JOB_ID}"
scontrol show hostnames "${SLURM_JOB_NODELIST}" > "${HOSTFILE}"

# ===== INFO =====
echo "=============================="
echo " MDTest over Lustre (GPFS)"
echo "=============================="
echo "Job ID       : ${SLURM_JOB_ID}"
echo "Node list    : ${SLURM_JOB_NODELIST}"
echo "Tasks        : ${SLURM_NNODES}"
echo "Test dir     : ${TEST_DIR}"
echo "Items/rank   : ${ITEMS}"
echo "Depth        : ${DEPTH}"
echo "Branching    : ${BRANCHING}"
echo "MPI launcher : mpirun (no-PMI build)"
echo "=============================="
echo

if command -v lfs >/dev/null 2>&1; then
    echo "--- Lustre info ---"
    lfs df -h "${MMFS_MNT}" || true
    lfs getstripe "${TEST_DIR}"  || true
    echo
fi

# ===== RUN =====
echo "Running MDTest..."

mpirun \
    --hostfile "${HOSTFILE}" \
    -np "${SLURM_NNODES}" \
    --map-by node \
    --bind-to none \
    "${MDTEST_BIN}" \
        -d "${TEST_DIR}" \
        -i 3 \              # 3 iterations for stable averages (was 1)
        -n "${ITEMS}" \
        -u \                # unique dir per task
        -z "${DEPTH}" \
        -b "${BRANCHING}" \
        -L \                # files only at leaves
        -F \                # files only (no dirs in operations)
        -C \                # create
        -T \                # stat
        -r                  # remove

echo
echo "=============================="
echo " MDTest finished."
echo "=============================="

# ===== CLEANUP =====
rm -rf "${TEST_DIR}"
rm -f  "${HOSTFILE}"
