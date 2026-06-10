#!/bin/bash
#SBATCH --partition=defq
#SBATCH --job-name=mdtest_mmfs
#SBATCH --nodes=24
#SBATCH --nodelist=ch3lahpccn[008-031]
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
MDTEST_BIN="${MDTEST_BIN:-$(pwd)/bin/mdtest}"

# ===== TEST SETTINGS =====
ITEMS=10000
DEPTH=2
BRANCHING=2

# ===== SETUP =====
mkdir -p "${TEST_DIR}" results

if command -v lfs >/dev/null 2>&1; then
    lfs setstripe -c 1 "${TEST_DIR}"
fi

HOSTFILE="${SLURM_SUBMIT_DIR}/hostfile_${SLURM_JOB_ID}"
scontrol show hostnames "${SLURM_JOB_NODELIST}" > "${HOSTFILE}"

# ===== INFO =====
echo "=============================="
echo " MDTest over GPFS"
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
    echo "--- GPFS info ---"
    lfs df -h "${MMFS_MNT}" || true
    lfs getstripe "${TEST_DIR}" || true
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
        -i 3 \
        -n "${ITEMS}" \
        -u \
        -z "${DEPTH}" \
        -b "${BRANCHING}" \
        -l \
        -F

# NOTE: -C -T -r are omitted as standalone flags;
# mdtest runs create/stat/remove by default when none of -C/-T/-E/-r are given.
# Add them back one at a time if you want phase-specific runs.

echo
echo "=============================="
echo " MDTest finished."
echo "=============================="

# ===== CLEANUP =====
rm -rf "${TEST_DIR}"
rm -f  "${HOSTFILE}"
