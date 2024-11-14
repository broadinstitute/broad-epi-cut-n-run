version 1.0

# TASK
# cutnrun-bowtie2

task cutnrun_align {
    meta {
        version: 'v0.1'
        author: 'Eugenio Mattei (emattei@broadinstitute.org) at Broad Institute of MIT and Harvard'
        description: 'Broad Institute of MIT and Harvard Cut-and-Run pipeline: align task using bowtie2'
    }

    input {
        # This task takes in input the preprocessed fastqs and align them to the genome.
        Array[File] fastq_R1
        Array[File] fastq_R2
        String? prefix
        File genome_index       # This is a tar.gz folder with all the index files.
        String genome_name      # GRCh38, mm10

        Boolean dovetail = true
        Boolean no_mixed = false
        Boolean no_discordant = false
        Boolean very_sensitive = false
        Int multimappers = -1

        Int? cpus = 16
        Int? memory_gb = 64
        Int disk_gb = 200
        String docker_image = "us.gcr.io/buenrostro-share-seq/share_task_bowtie2"
        
    }

    # Determining disk type base on the size of disk.
    String disk_type = if disk_gb > 375 then "SSD" else "LOCAL"
    

    # Define tmp file name
    String unsorted_bam = "${default="cutnrun" prefix}.cutnrun.align.${genome_name}.bam"
    # Define the output names
    String sorted_bam = "${default="cutnrun" prefix}.cutnrun.align.${genome_name}.sorted.bam"
    String sorted_bai = "${default="cutnrun" prefix}.cutnrun.align.${genome_name}.sorted.bam.bai"
    String alignment_log = "${default="cutnrun" prefix}.cutnrun.align.${genome_name}.log"

    command {
        set -e

        tar zxvf ${genome_index} --no-same-owner -C ./
        genome_prefix=$(basename $(find . -type f -name "*.rev.1.bt2") .rev.1.bt2)

        bowtie2 \
            --phred33 \
            ~{true='--no-mixed ' false='' no_mixed} \
            ~{true='--no-discordant ' false='' no_discordant} \
            ~{true='--very-sensitive ' false='' very_sensitive} \
            ~{true='--dovetail ' false='' dovetail} \
            ~{if multimappers > 0 then "-k " + "~{multimappers}" else "" } \
            -p ${cpus} \
            -x $genome_prefix \
            -1 ${sep="," fastq_R1} \
            -2 ${sep="," fastq_R2} 2> ${alignment_log} |\
            samtools view \
                -bS \
                -@ ${cpus} \
                - \
                -o ${unsorted_bam}


        samtools sort \
            -@ ${cpus} \
            -m 2G \
            ${unsorted_bam} > ${sorted_bam}
        samtools index -@ ${cpus} ${sorted_bam}

    }

    output {
        File raw_sorted_bam = sorted_bam
        File raw_sorted_bai = sorted_bai
        File alignment_log = alignment_log
    }

    runtime {
        cpu : cpus
        memory : memory_gb+'G'
        disks : 'local-disk ${disk_gb} ${disk_type}'
        docker : docker_image
    }

    parameter_meta {
        fastq_R1: {
                description: 'Read1 fastq',
                help: 'Processed fastq for read1.',
                example: 'processed.atac.R1.fq.gz',
            }
        fastq_R2: {
                description: 'Read2 fastq',
                help: 'Processed fastq for read2.',
                example: 'processed.atac.R2.fq.gz'
            }
        genome_index: {
                description: 'Bowtie2 indexes',
                help: 'Index files for bowtie2 to use during alignment.',
                examples: ['hg19.tar.gz']
            }
        genome_name: {
                description: 'Reference name',
                help: 'The name of the reference genome used by the aligner.',
                examples: ['GRCh38', 'mm10']
            }
        prefix: {
                description: 'Prefix for output files',
                help: 'Prefix that will be used to name the output files',
                examples: 'MyExperiment'
            }
        dovetail: {
                description: 'Dovetail alignment',
                help: 'Perform dovetail alignment.'
            }
        no_mixed: {
                description: 'No mixed alignments',
                help: 'Do not allow mixed alignments.'
            }
        no_discordant: {
                description: 'No discordant alignments',
                help: 'Do not allow discordant alignments.'
            }
        very_sensitive: {
                description: 'Very sensitive alignment',
                help: 'Perform very sensitive alignment.'
            }
        multimappers: {
                description: 'Multimappers',
                help: 'Number of multimappers to allow. -1 means off.'
            }
        cpus: {
                description: 'Number of cpus',
                help: 'Set the number of cpus useb by bowtie2',
                default: 16
            }
        docker_image: {
                description: 'Docker image.',
                help: 'Docker image for preprocessing step. Dependencies: python3 -m pip install Levenshtein pyyaml Bio; apt install pigz',
                example: ['put link to gcr or dockerhub']
            }
    }

}
