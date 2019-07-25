# Next-generation massively parallel short-read mapping on FPGAs

## Background

The mapping of DNA sequences to huge genome databases is an essential analysis task in modern molecular biology. Having linearized reference genomes available, the alignment of short DNA reads obtained from the sequencing of an individual genome against such a database provides a powerful diagnostic and analysis tool. In essence, this task amounts to a simple string search tolerating a certain number of mismatches to account for the diversity of individuals. The complexity of this process arises from the sheer size of the reference genome. It is further amplified by current next- generation sequencing technologies, which produce a huge number of increasingly short reads. These short reads hurt established alignment heuristics like BLAST severely.

This project includes an FPGA-based custom computation on a Xilinx Virtex-6 FPGA, which performs the alignment of short DNA reads in a timely manner by the use of tremendous concurrency for reasonable costs.

On the contrary, advanced fast alignment heuristics like Bowtie and Maq can only tolerate small mismatch maximums with a quick deterioration of the probability to detect existing valid alignments. The performance comparison with these widely used software tools also demonstrates that the proposed FPGA computation achieves its guaranteed exact results in very competitive time.

## Architectur 

The overall architecture is based on a host system and an over Gigabit Ethernet directly connected FPGA board ([ML605 develpment board](https://www.xilinx.com/products/boards-and-kits/ek-v6-ml605-g.html)) for the alignment of the sequences. The FPGA design guarantees to find all alignment locations of a read in the database while also allowing a freely adjustable character mismatch threshold. 

## Usage

## Documentation and References

The [Diploma Thesis](https://nbn-resolving.org/urn:nbn:de:bsz:14-qucosa-136773) (German) gives the overall background,  implementation insights and performance results. The results are also published in an international conference: 

* [Next-generation massively parallel short-read mapping on FPGAs](https://github.com/knodel/FPGA-Genome-Alignment/blob/master/documentation/Next-Generation_Massively_Parallel_Short-Read_Mapping_on_FPGAs.pdf);
*O Knodel, TB Preußer, RG Spallek* - ASAP 2011-22nd IEEE International Conference on Application-specific Systems, Architectures and Processors, Santa Monica, USA, September 2011.
