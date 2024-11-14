version 1.0

task qc {
    input {
        File coordinate_sorted_bam
        File chromosome_sizes_file
        Int fragment_minimum_size_cutoff
        String prefix = "qc_output"

        String qc_docker_image = "polumechanos/cutnrun_qc:v2"
        Int qc_cpus=1
        Int qc_memory_gb=16

    }

    Float input_file_size_gb = size(coordinate_sorted_bam, "G")
    Int mem_gb = qc_memory_gb
    Int disk_gb = round(20.0 + 4 * input_file_size_gb)
    # Determining disk type base on the size of disk.
    String disk_type = if disk_gb > 375 then "SSD" else "LOCAL"

    command <<<

    samtools index ~{coordinate_sorted_bam}

    # Read the chromosome sizes file, remove all the chromosomes that are not major contigs.
    grep -v random ~{chromosome_sizes_file} | grep -v chrUn | grep -v chrM | grep -v alt | grep -v random | grep -v fix | grep -v chrMT | cut -f1> major_contigs.txt
    major_contigs_list=$(tr '\n' ' ' < major_contigs.txt)

    # Filter the bam and keep only the chromosomes in the major_contigs.txt file.
    # Extract the header of the bam file
    samtools view -H ~{coordinate_sorted_bam} > header.sam
    # Filter the bam file
    samtools view -o temp.bam -b ~{coordinate_sorted_bam} $major_contigs_list 
    # Reheader the bam file
    grep -f major_contigs.txt header.sam | samtools reheader - temp.bam > filtered.output.bam
    samtools index filtered.output.bam
    rm temp.bam header.sam

    samtools view -F 1548 -f 2 filtered.output.bam | awk '{ if ($9 > 0) { print $9 }}' | \
    sort -n | \
    uniq -c > ~{prefix}_fragment_size_distribution_uniq_multi.txt

    samtools view -q 30 -F 3852 -f 2 filtered.output.bam | awk '{ if ($9 > 0) { print $9 }}' | \
    sort -n | \
    uniq -c > ~{prefix}_fragment_size_distribution_uniq.txt
    
    # Compute number of fragments in bam file
    # Remove read unmapped, mate unmapped, read fails platform/vendor quality checks, supplementary alignment, and PCR or optical duplicate reads.
    # Keep only properly paired reads unique and multi.
    samtools view -h -F 1548 -f 2 filtered.output.bam | awk -v cutoff="~{fragment_minimum_size_cutoff}" 'substr($0,1,1)=="@" || ($9>= cutoff) || ($9<=cutoff)' | samtools view -b - > ~{prefix}_major_contigs_no_nfr_unique_and_multi_mappings.bam
    samtools view -c ~{prefix}_major_contigs_no_nfr_unique_and_multi_mappings.bam > number_usable_reads_uniq_and_multi.txt

    # Remove read unmapped, mate unmapped, read fails platform/vendor quality checks, not primary alignment, supplementary alignment, and PCR or optical duplicate reads.
    # Keep only unique properly paired reads.
    samtools view -h -q 30 -F 3852 -f 2 filtered.output.bam | awk -v cutoff="~{fragment_minimum_size_cutoff}" 'substr($0,1,1)=="@" || ($9>= cutoff) || ($9<=cutoff)' | samtools view -b - > ~{prefix}_major_contigs_no_nfr_unique_mappings.bam
    samtools view -c ~{prefix}_major_contigs_no_nfr_unique_mappings.bam > number_usable_reads_uniq.txt

    # Plot histogram of fragment size distribution
    python3 /usr/local/bin/plot_fragment_size_distribution.py ~{prefix}_fragment_size_distribution_uniq.txt ~{prefix}_fragment_size_distribution_unique_mapping_fragments
    python3 /usr/local/bin/plot_fragment_size_distribution.py ~{prefix}_fragment_size_distribution_uniq_multi.txt ~{prefix}_fragment_size_distribution_unique_and_multi_mapping_fragments

    # Extract summary counts. These should match the one found abobe.
    grep 'Total number of fragments:' ~{prefix}_fragment_size_distribution_unique_mapping_fragments_summary_counts.txt | awk '{print $5}' > number_total_fragments_unique.txt
    grep 'Usable fragments:' ~{prefix}_fragment_size_distribution_unique_mapping_fragments_summary_counts.txt | awk '{print $3}' > number_usable_fragments_unique.txt

    grep 'Total number of fragments:' ~{prefix}_fragment_size_distribution_unique_and_multi_mapping_fragments_summary_counts.txt | awk '{print $5}' > number_total_fragments_unique_and_multi.txt
    grep 'Usable fragments:' ~{prefix}_fragment_size_distribution_unique_and_multi_mapping_fragments_summary_counts.txt | awk '{print $3}' > number_usable_fragments_unique_and_multi.txt

    >>>

    output {
        File final_bam_unique = "~{prefix}_major_contigs_no_nfr_unique_mappings.bam"
        File final_bam_unique_and_multi = "~{prefix}_major_contigs_no_nfr_unique_and_multi_mappings.bam"
        
        Int number_usable_reads_unique = read_int("number_usable_reads_uniq.txt")
        Int number_usable_reads_unique_and_multi = read_int("number_usable_reads_uniq_and_multi.txt")

        File fragment_size_distribution_unique_txt = "~{prefix}_fragment_size_distribution_uniq.txt"
        File fragment_size_distribution_unique_and_multi_txt = "~{prefix}_fragment_size_distribution_uniq_multi.txt"
        File fragment_size_distribution_unique_plot_pdf = "~{prefix}_fragment_size_distribution_unique_mapping_fragments.pdf"
        File fragment_size_distribution_unique_plot_png = "~{prefix}_fragment_size_distribution_unique_mapping_fragments.png"
        File fragment_size_distribution_unique_and_multi_plot_pdf = "~{prefix}_fragment_size_distribution_unique_and_multi_mapping_fragments.pdf"
        File fragment_size_distribution_unique_and_multi_plot_png = "~{prefix}_fragment_size_distribution_unique_and_multi_mapping_fragments.png"
        
        File summary_fragment_counts_unique = "~{prefix}_fragment_size_distribution_unique_mapping_fragments_summary_counts.txt"
        Int number_total_fragments_unique = read_int("number_total_fragments_unique.txt")
        Int number_usable_fragments_unique = read_int("number_usable_fragments_unique.txt")

        File summary_fragment_counts_unique_and_multi = "~{prefix}_fragment_size_distribution_unique_and_multi_mapping_fragments_summary_counts.txt"
        Int number_total_fragments_unique_and_multi = read_int("number_total_fragments_unique_and_multi.txt")
        Int number_usable_fragments_unique_and_multi = read_int("number_usable_fragments_unique_and_multi.txt")
    }

    runtime {
        cpu: "${qc_cpus}"
        docker: "${qc_docker_image}"
        disks: "local-disk ${disk_gb} ${disk_type}"
        memory: "${mem_gb} GB"
    }

    parameter_meta {
        coordinate_sorted_bam: {
            description: "Input BAM file"
        }
        fragment_minimum_size_cutoff: {
            description: "Minimum Fragment size cutoff for filtering"
        }
        prefix: {
            description: "Prefix for output files"
        }
        qc_docker_image: {
            description: "Docker image for running QC tasks"
        }
        qc_cpus: {
            description: "Number of CPUs to use"
        }
        qc_memory_gb: {
            description: "Amount of memory in GB"
        }
    }
}