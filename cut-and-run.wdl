version 1.0

import "tasks/cutnrun_task_trim.wdl" as cutnrun_task_trim
import "tasks/cutnrun_task_bowtie2.wdl" as cutnrun_task_align
import "tasks/cutnrun_task_bam2bed.wdl" as cutnrun_task_bam2bed
import "tasks/cutnrun_task_viz.wdl" as cutnrun_task_visualization
import "tasks/cutnrun_task_peak.wdl" as cutnrun_task_peak_calling
import "tasks/cutnrun_task_deeptools.wdl" as cutnrun_task_deeptools

workflow wf_cut_and_run {
    meta {
        version: 'v0.1'
            author: 'Eugenio Mattei (emattei@broadinstitute.org) @ Broad Institute of MIT and Harvard'
            description: 'Broad Institute of MIT and Harvard cut-and-run pipeline.'
    }

    input {
        Array[File] target_fastq_R1
        Array[File] target_fastq_R2
        Array[File] ctrl_fastq_R1
        Array[File] ctrl_fastq_R2
        File idx_tar
        File chrom_sizes
        File tss
        File genes
        String? normalization = "norm"
        String? stringency = "relaxed"
        String prefix = "cutnrun-sample"
        String prefix_ctrl = "cutnrun-ctrl"
        String genome_name
        String? docker
        Boolean trim_fastqs = true
    }

    if(trim_fastqs){
        scatter (idx in range(length(target_fastq_R1))){
            call cutnrun_task_trim.cutnrun_trim as trim {
                input:
                    fastq_R1 = target_fastq_R1[idx],
                    fastq_R2 = target_fastq_R2[idx],
                    prefix = prefix
            }
        }
    }

    call cutnrun_task_align.cutnrun_align as target_align {
        input:
            fastq_R1 = select_first([trim.trimmed_R1, target_fastq_R1]),
            fastq_R2 = select_first([trim.trimmed_R1, target_fastq_R1]),
            genome_index = idx_tar,
            genome_name = genome_name,
            prefix = prefix
    }

    call cutnrun_task_align.cutnrun_align as ctrl_align {
        input:
            fastq_R1 = ctrl_fastq_R1,
            fastq_R2 = ctrl_fastq_R2,
            genome_index = idx_tar,
            genome_name = genome_name,
            prefix = prefix_ctrl
    }

        call cutnrun_task_bam2bed.cutnrun_bam2bed as target_bam2bed {
           input:
            bam = target_align.cutnrun_alignment,
            prefix = prefix
        }

        call cutnrun_task_bam2bed.cutnrun_bam2bed as ctrl_bam2bed {
           input:
            bam = ctrl_align.cutnrun_alignment,
            prefix = prefix_ctrl
        }

    call cutnrun_task_visualization.cutnrun_viz as target_track_generation {
        input:
            bedpe = target_bam2bed.bedpe,
            chr_sizes = chrom_sizes,
            prefix = prefix
    }

    call cutnrun_task_visualization.cutnrun_viz as ctrl_track_generation {
        input:
            bedpe = ctrl_bam2bed.bedpe,
            chr_sizes = chrom_sizes,
            prefix = prefix_ctrl
    }

    call cutnrun_task_peak_calling.cutnrun_peak as peak_calling {
        input:
            bedgraph_input = target_track_generation.bedgraph,
            bedgraph_ctrl = ctrl_track_generation.bedgraph,
            chr_sizes = chrom_sizes,
            normalization = normalization,
            stringency = stringency,
            prefix = prefix
    }

    call cutnrun_task_deeptools.cutnrun_deeptools as ctrl_deeptools {
        input:
            cleaned_bam = ctrl_bam2bed.clean_bam,
            chr_sizes = chrom_sizes,
            tss = tss,
            genes = genes,
            prefix = prefix_ctrl
    }

    call cutnrun_task_deeptools.cutnrun_deeptools as target_deeptools {
        input:
            cleaned_bam = target_bam2bed.clean_bam,
            chr_sizes = chrom_sizes,
            tss = tss,
            genes = genes,
            prefix = prefix
    }

    call sort as ctrl_sort{
        input:
            cleaned_bam = ctrl_bam2bed.clean_bam,
            prefix = prefix_ctrl
    }

    call sort as target_sort{
        input:
            cleaned_bam = target_bam2bed.clean_bam,
            prefix = prefix
    }

        output {
            File target_alignment_bam = target_align.cutnrun_alignment
            File target_alignment_log = target_align.cutnrun_alignment_log
            File target_bedpe = target_bam2bed.bedpe
            File target_cleaned_bam = target_bam2bed.clean_bam
            File target_cleaned_sorted_bam = target_sort.clean_sorted_bam
            File target_bedgrapgh = target_track_generation.bedgraph
            File target_bigwig = target_track_generation.bigwig
            File target_deeptools_heatmap_genes = target_deeptools.heatmap_genes
            File target_deeptools_heatmap_tss = target_deeptools.heatmap_tss
            File target_deeptools_bw = target_deeptools.cleaned_deeptools_bw

            File ctrl_alignment_bam = ctrl_align.cutnrun_alignment
            File ctrl_alignment_log = ctrl_align.cutnrun_alignment_log
            File ctrl_bedpe = ctrl_bam2bed.bedpe
            File ctrl_cleaned_bam = ctrl_bam2bed.clean_bam
            File ctrl_cleaned_sorted_bam = ctrl_sort.clean_sorted_bam
            File ctrl_bedgrapgh = ctrl_track_generation.bedgraph
            File ctrl_bigwig = ctrl_track_generation.bigwig
            File ctrl_deeptools_heatmap_genes = ctrl_deeptools.heatmap_genes
            File ctrl_deeptools_heatmap_tss = ctrl_deeptools.heatmap_tss
            File ctrl_deeptools_bw = ctrl_deeptools.cleaned_deeptools_bw


            #File narrow_peak = peak_calling.narrow_peak
            #File bedgraph_peak_norm = peak_calling.bedgraph_peak_norm
            #File bw_peak_norm = peak_calling.bw_peak_norm
    }
}

task sort {
  input {
    String prefix
    File cleaned_bam
  }
  String outbam = '${default="cutnrun" prefix}.dedup.cleaned.sorted.bam'
  command {
    $(which samtools) sort -@ 8 -m 3G ${cleaned_bam} -o ${outbam}
  }
  output {
    File clean_sorted_bam = "${outbam}"
  }
  runtime {
    maxRetries : 0
    cpu : 8
    memory : '32 GB'
    disks : 'local-disk 100 SSD'
    docker : 'us.gcr.io/buenrostro-share-seq/share_task_star'
  }
}
