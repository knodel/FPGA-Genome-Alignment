# Next-generation massively parallel short-read mapping on FPGAs

# Background

# Architecture

# Scientific Abstract

The mapping of DNA sequences to huge genome databases is an essential analysis task in modern molecular biology. Having linearized reference genomes available, the alignment of short DNA reads obtained from the sequencing of an individual genome against such a database provides a powerful diagnostic and analysis tool. In essence, this task amounts to a simple string search tolerating a certain number of mismatches to account for the diversity of individuals. The complexity of this process arises from the sheer size of the reference genome. It is further amplified by current next- generation sequencing technologies, which produce a huge number of increasingly short reads. These short reads hurt established alignment heuristics like BLAST severely.

This project includes an FPGA-based custom computation on a Xilinx Virtex-6 FPGA ([ML605 develpment board](https://www.xilinx.com/products/boards-and-kits/ek-v6-ml605-g.html)), which performs the alignment of short DNA reads in a timely manner by the use of tremendous concurrency for reasonable costs. The special measures to achieve an extremely efficient and compact mapping of the computation to a Xilinx FPGA architecture are described. The presented approach also surpasses all software heuristics in the quality of its results. It guarantees to find all alignment locations of a read in the database while also allowing a freely adjustable character mismatch threshold. On the contrary, advanced fast alignment heuristics like Bowtie and Maq can only tolerate small mismatch maximums with a quick deterioration of the probability to detect existing valid alignments. The perfor- mance comparison with these widely used software tools also demonstrates that the proposed FPGA computation achieves its guaranteed exact results in very competitive time.

# References
