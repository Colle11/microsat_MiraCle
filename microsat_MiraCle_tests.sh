#!/bin/bash

if test $# -gt 0; then
	echo "Usage: $0"
	exit 1
fi

make clean
make

for p in ./SAT_instances/*/*
do
    d=$(echo "${p}" | cut -d'/' -f 3-4)
    mkdir -p ./microsat_MiraCle_test_results/${d}
done

for i in ./SAT_instances/*/*/*.cnf
do
    n=$(echo "${i}" | cut -d'/' -f 3-)
    ### NO_MRC ###
    ./build/bin/microsat_NO_MRC_STATS ${i} > "./microsat_MiraCle_test_results/${n}_microsat_NO_MRC_STATS.txt"
    echo "./build/bin/microsat_NO_MRC_STATS ${i}"
    sleep 10s
    ### MRC ###
    ./build/bin/microsat_MRC_JW_OS_STATS ${i} > "./microsat_MiraCle_test_results/${n}_microsat_MRC_JW_OS_STATS.txt"
    echo "./build/bin/microsat_MRC_JW_OS_STATS ${i}"
    sleep 10s
    ./build/bin/microsat_MRC_JW_TS_STATS ${i} > "./microsat_MiraCle_test_results/${n}_microsat_MRC_JW_TS_STATS.txt"
    echo "./build/bin/microsat_MRC_JW_TS_STATS ${i}"
    sleep 10s
    ./build/bin/microsat_MRC_BOHM_STATS ${i} > "./microsat_MiraCle_test_results/${n}_microsat_MRC_BOHM_STATS.txt"
    echo "./build/bin/microsat_MRC_BOHM_STATS ${i}"
    sleep 10s
    ./build/bin/microsat_MRC_POSIT_STATS ${i} > "./microsat_MiraCle_test_results/${n}_microsat_MRC_POSIT_STATS.txt"
    echo "./build/bin/microsat_MRC_POSIT_STATS ${i}"
    sleep 10s
    ./build/bin/microsat_MRC_DLIS_STATS ${i} > "./microsat_MiraCle_test_results/${n}_microsat_MRC_DLIS_STATS.txt"
    echo "./build/bin/microsat_MRC_DLIS_STATS ${i}"
    sleep 10s
    ./build/bin/microsat_MRC_DLCS_STATS ${i} > "./microsat_MiraCle_test_results/${n}_microsat_MRC_DLCS_STATS.txt"
    echo "./build/bin/microsat_MRC_DLCS_STATS ${i}"
    sleep 10s
    ### MRC_DYN ###
    ./build/bin/microsat_MRC_DYN_JW_OS_STATS ${i} > "./microsat_MiraCle_test_results/${n}_microsat_MRC_DYN_JW_OS_STATS.txt"
    echo "./build/bin/microsat_MRC_DYN_JW_OS_STATS ${i}"
    sleep 10s
    ./build/bin/microsat_MRC_DYN_JW_TS_STATS ${i} > "./microsat_MiraCle_test_results/${n}_microsat_MRC_DYN_JW_TS_STATS.txt"
    echo "./build/bin/microsat_MRC_DYN_JW_TS_STATS ${i}"
    sleep 10s
    ./build/bin/microsat_MRC_DYN_BOHM_STATS ${i} > "./microsat_MiraCle_test_results/${n}_microsat_MRC_DYN_BOHM_STATS.txt"
    echo "./build/bin/microsat_MRC_DYN_BOHM_STATS ${i}"
    sleep 10s
    ./build/bin/microsat_MRC_DYN_POSIT_STATS ${i} > "./microsat_MiraCle_test_results/${n}_microsat_MRC_DYN_POSIT_STATS.txt"
    echo "./build/bin/microsat_MRC_DYN_POSIT_STATS ${i}"
    sleep 10s
    ./build/bin/microsat_MRC_DYN_DLIS_STATS ${i} > "./microsat_MiraCle_test_results/${n}_microsat_MRC_DYN_DLIS_STATS.txt"
    echo "./build/bin/microsat_MRC_DYN_DLIS_STATS ${i}"
    sleep 10s
    ./build/bin/microsat_MRC_DYN_DLCS_STATS ${i} > "./microsat_MiraCle_test_results/${n}_microsat_MRC_DYN_DLCS_STATS.txt"
    echo "./build/bin/microsat_MRC_DYN_DLCS_STATS ${i}"
    sleep 10s
    ### MRC_GPU ###
    ./build/bin/microsat_MRC_GPU_JW_OS_STATS ${i} > "./microsat_MiraCle_test_results/${n}_microsat_MRC_GPU_JW_OS_STATS.txt"
    echo "./build/bin/microsat_MRC_GPU_JW_OS_STATS ${i}"
    sleep 10s
    ./build/bin/microsat_MRC_GPU_JW_TS_STATS ${i} > "./microsat_MiraCle_test_results/${n}_microsat_MRC_GPU_JW_TS_STATS.txt"
    echo "./build/bin/microsat_MRC_GPU_JW_TS_STATS ${i}"
    sleep 10s
    ./build/bin/microsat_MRC_GPU_BOHM_STATS ${i} > "./microsat_MiraCle_test_results/${n}_microsat_MRC_GPU_BOHM_STATS.txt"
    echo "./build/bin/microsat_MRC_GPU_BOHM_STATS ${i}"
    sleep 10s
    ./build/bin/microsat_MRC_GPU_POSIT_STATS ${i} > "./microsat_MiraCle_test_results/${n}_microsat_MRC_GPU_POSIT_STATS.txt"
    echo "./build/bin/microsat_MRC_GPU_POSIT_STATS ${i}"
    sleep 10s
    ./build/bin/microsat_MRC_GPU_DLIS_STATS ${i} > "./microsat_MiraCle_test_results/${n}_microsat_MRC_GPU_DLIS_STATS.txt"
    echo "./build/bin/microsat_MRC_GPU_DLIS_STATS ${i}"
    sleep 10s
    ./build/bin/microsat_MRC_GPU_DLCS_STATS ${i} > "./microsat_MiraCle_test_results/${n}_microsat_MRC_GPU_DLCS_STATS.txt"
    echo "./build/bin/microsat_MRC_GPU_DLCS_STATS ${i}"
    sleep 10s
done
