version 1.0

task generate_tracks {
    input {
        File bam
        File chromosome_sizes_file
        Int library_size
        String prefix = "tracks"

        String generate_tracks_docker_image = "us.gcr.io/buenrostro-share-seq/task_make_track:dev"
        Int generate_tracks_cpus=1
        Int generate_tracks_memory_gb=16
    }

    Float input_file_size_gb = size(bam, "G")
    Int mem_gb = generate_tracks_memory_gb
    Int disk_gb = round(20.0 + 4 * input_file_size_gb)
    # Determining disk type base on the size of disk.
    String disk_type = if disk_gb > 375 then "SSD" else "LOCAL"

    command <<<

    scale_factor=$(bc <<< "scale=6;1000000/~{library_size}")

    bedtools genomecov  -ibam ~{bam} -bg -pc > ~{prefix}.bedgraph
    bedtools genomecov  -ibam ~{bam} -bg -pc -scale $scale_factor > ~{prefix}_CPM.bedgraph

    bedGraphToBigWig ~{prefix}.bedgraph ~{chromosome_sizes_file} ~{prefix}.bw
    bedGraphToBigWig ~{prefix}_CPM.bedgraph ~{chromosome_sizes_file} ~{prefix}_CPM.bw

    >>>

    output {
        File bedgraph = "~{prefix}.bedgraph"
        File bedgraph_cpm = "~{prefix}_CPM.bedgraph"
        File bigwig = "~{prefix}.bw"
        File bigwig_cpm = "~{prefix}_CPM.bw"

    }

    runtime {
        cpu: "${generate_tracks_cpus}"
        docker: "${generate_tracks_docker_image}"
        disks: "local-disk ${disk_gb} ${disk_type}"
        memory: "${mem_gb} GB"
    }

    parameter_meta {
        bam: "Input BAM file"
        chromosome_sizes_file: "File containing chromosome sizes"
        library_size: "Library size for scaling"
        prefix: "Prefix for output files"
        generate_tracks_docker_image: "Docker image for generating tracks"
        generate_tracks_cpus: "Number of CPUs for the task"
        generate_tracks_memory_gb: "Memory in GB for the task"
    }



}