version 1.0

# TASK
# cutnrun-dedup

task cutnrun_dedup {
    meta {
        version: 'v0.1'
        author: 'Eugenio Mattei (emattei@broadinstitute.org) at Broad Institute of MIT and Harvard'
        description: 'Broad Institute of MIT and Harvard Cut-and-Run pipeline: dedup task'
    }

    input {
        File coordinate_sorted_bam
        String prefix="cutnrun"

        Int? cpus = 2
        Int? memory_gb = 32
        Int? disk_gb = 200
        String docker_image = "4dndcic/cut-and-run-pipeline:v1"
    }

    # Determining disk type base on the size of disk.
    String disk_type = if disk_gb > 375 then "SSD" else "LOCAL"

    command <<<
        # mark duplicates
        java -Xmx2G -jar /usr/local/bin/picard.jar MarkDuplicates \
            INPUT=~{coordinate_sorted_bam} \
            OUTPUT=~{prefix}.markdup.tmp.bam \
            METRICS_FILE=~{prefix}.dup.qc.txt \
            VALIDATION_STRINGENCY=LENIENT

        # remove duplicates and clean up
        /usr/local/bin/samtools/samtools view -F 1024 -b ~{prefix}.markdup.tmp.bam > ~{prefix}.dedup.sorted.bam
        rm ~{prefix}.markdup.tmp.bam

        samtools index ~{prefix}.dedup.sorted.bam
    >>>

    output {
        File sorted_dedup_bam = "~{prefix}.dedup.sorted.bam"
        File sorted_dedup_bai = "~{prefix}.dedup.sorted.bam.bai"
        File dedup_qc_metrics = "~{prefix}.dup.qc.txt"
    }

    runtime {
        cpu : cpus
        memory : memory_gb+'G'
        disks : 'local-disk ${disk_gb} ${disk_type}'
        docker : docker_image
    }

    parameter_meta {
        coordinate_sorted_bam: {
                description: 'Bam file',
                help: 'Output bam from alignment.',
                example: 'sample.align.bam',
            }
        prefix: {
                description: 'Prefix for output files',
                help: 'Prefix that will be used to name the output files',
                examples: 'MyExperiment'
            }
    }

}
