version 1.0

task qc {
    input {
        File coord_sorted_bam
        File chromosome_sizes_file
        Int fragment_minimum_size_cutoff
        String prefix = "qc_output"

        String qc_docker_image = "polumechanos/cutnrun_qc:v2"
        Int qc_cpus=1
        Int qc_memory_gb=16

    }

    Float input_file_size_gb = size(coord_sorted_bam, "G")
    Int mem_gb = qc_memory_gb
    Int disk_gb = round(20.0 + 4 * input_file_size_gb)
    # Determining disk type base on the size of disk.
    String disk_type = if disk_gb > 375 then "SSD" else "LOCAL"

    command <<<

    samtools view -h -F 1548 -f 2 ~{coord_sorted_bam} | samtools sort -n -o ~{prefix}_namesorted.bam -

    bedtools bamtobed -i ~{prefix}_namesorted.bam -tag NH > ~{prefix}_namesorted.bedpe

    
    >>>

    output {
        File namesorted_bedpe = "~{prefix}_namesorted.bedpe"
    }

    runtime {
        cpu: "${qc_cpus}"
        docker: "${qc_docker_image}"
        disks: "local-disk ${disk_gb} ${disk_type}"
        memory: "${mem_gb} GB"
    }

    parameter_meta {
        coord_sorted_bam: {
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