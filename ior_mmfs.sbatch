#!/bin/bash
#SBATCH --partition=defq
#SBATCH --job-name=ior_mmfs_quick
#SBATCH --nodes=24
#SBATCH --nodelist=ch3lahpccn[001-032]
#SBATCH --ntasks-per-node=1
#SBATCH --exclusive
#SBATCH --output=results/ior_mmfs_%j.out
#SBATCH --error=results/ior_mmfs_%j.out

set -euo pipefail

# ===== MODULE =====
module load openmpi/gcc/64/4.1.5

# ===== MPI / IB SETTINGS =====
export OMPI_MCA_pml=ob1
export OMPI_MCA_btl=openib,vader,self
export OMPI_MCA_btl_openib_allow_ib=1

# ===== PATHS =====
MMFS_MNT="/mmfs1"
TEST_DIR="${MMFS_MNT}/ior_test_${SLURM_JOB_ID}"
IOR_BIN="$(pwd)/bin/ior"          # absolute path — mpirun needs this

BLOCK_SIZE="16g"
TRANSFER_SIZE="4m"
SEGMENT_COUNT="1"

mkdir -p "${TEST_DIR}"

if command -v lfs >/dev/null 2>&1; then
    lfs setstripe -c -1 -S 16M "${TEST_DIR}"
    lfs getstripe "${TEST_DIR}"
fi

echo "Hostfile:"
scontrol show hostnames "${SLURM_JOB_NODELIST}" > "${SLURM_SUBMIT_DIR}/hostfile_${SLURM_JOB_ID}"
cat "${SLURM_SUBMIT_DIR}/hostfile_${SLURM_JOB_ID}"

echo "Running IOR over IB (ob1/openib via mpirun)..."

mpirun \
    --hostfile "${SLURM_SUBMIT_DIR}/hostfile_${SLURM_JOB_ID}" \
    -np "${SLURM_NNODES}" \
    --map-by node \
    --bind-to none \
    "${IOR_BIN}" \
        -a POSIX \
        -b "${BLOCK_SIZE}" \
        -t "${TRANSFER_SIZE}" \
        -s "${SEGMENT_COUNT}" \
        -F -C -e -k -E \
        -o "${TEST_DIR}/ior_file" \
        -w -r

rm -rf "${TEST_DIR}"
rm -f "${SLURM_SUBMIT_DIR}/hostfile_${SLURM_JOB_ID}"
