version 1.0

import "tasks/cutnrun_task_trim.wdl" as cutnrun_task_trim
import "tasks/cutnrun_task_bowtie2.wdl" as cutnrun_task_align
import "tasks/cutnrun_task_dedup.wdl" as cutnrun_task_dedup
import "tasks/cutnrun_task_peak.wdl" as cutnrun_task_peak_calling
import "workflows/qc-cut-n-run.wdl" as qc_cutnrun

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

        String prefix = "cutnrun-sample"
        String prefix_ctrl = "cutnrun-ctrl"
        String genome_name

        Boolean trim_fastqs = true
        Boolean peak_calling = false
    }

    if(trim_fastqs){
        scatter (idx in range(length(target_fastq_R1))){
            call cutnrun_task_trim.cutnrun_trim as trim_target {
                input:
                    fastq_R1 = target_fastq_R1[idx],
                    fastq_R2 = target_fastq_R2[idx],
                    prefix = prefix
            }
        }

        scatter (idx in range(length(ctrl_fastq_R1))){
            call cutnrun_task_trim.cutnrun_trim as trim_ctrl {
                input:
                    fastq_R1 = ctrl_fastq_R1[idx],
                    fastq_R2 = ctrl_fastq_R2[idx],
                    prefix = prefix_ctrl
            }
        }
    }

    # Processing target sample
    call cutnrun_task_align.cutnrun_align as target_align {
        input:
            fastq_R1 = select_first([trim_target.trimmed_R1, target_fastq_R1]),
            fastq_R2 = select_first([trim_target.trimmed_R2, target_fastq_R2]),
            genome_index = idx_tar,
            genome_name = genome_name,
            prefix = prefix
    }
    call cutnrun_task_dedup.cutnrun_dedup as target_dedup {
        input:
            coordinate_sorted_bam = target_align.raw_sorted_bam,
            prefix = prefix
    }
    call qc_cutnrun.qc_cut_n_run as target_qc {
        input:
            coordinate_sorted_bam = target_dedup.sorted_dedup_bam,
            chromosome_sizes_file = chrom_sizes,
            fragment_minimum_size_cutoff = 120,
            prefix = prefix
    }

    # Processing control
    call cutnrun_task_align.cutnrun_align as ctrl_align {
        input:
            fastq_R1 = select_first([trim_ctrl.trimmed_R1, target_fastq_R1]),
            fastq_R2 = select_first([trim_ctrl.trimmed_R2, target_fastq_R2]),
            genome_index = idx_tar,
            genome_name = genome_name,
            prefix = prefix_ctrl
    }

    call cutnrun_task_dedup.cutnrun_dedup as ctrl_dedup {
        input:
            coordinate_sorted_bam = ctrl_align.raw_sorted_bam,
            prefix = prefix_ctrl
    }

    call qc_cutnrun.qc_cut_n_run as ctrl_qc {
        input:
            coordinate_sorted_bam = ctrl_dedup.sorted_dedup_bam,
            chromosome_sizes_file = chrom_sizes,
            fragment_minimum_size_cutoff = 120,
            prefix = prefix_ctrl
    }

    if(peak_calling){
        call cutnrun_task_peak_calling.cutnrun_peak as peaks {
            input:
                bedgraph_input = target_qc.bedgraph_unique_and_multi,
                bedgraph_ctrl = ctrl_qc.bedgraph_unique_and_multi,
                chr_sizes = chrom_sizes,
                prefix = prefix
        }
    }


    output {
        File target_alignment_log = target_align.alignment_log
        File target_dedup_sorted_bam = target_dedup.sorted_dedup_bam
        File target_dedup_sorted_bai = target_dedup.sorted_dedup_bai
        File target_dedup_qc_metrics = target_dedup.dedup_qc_metrics

        File ctrl_alignment_log = ctrl_align.alignment_log
        File ctrl_dedup_sorted_bam = ctrl_dedup.sorted_dedup_bam
        File ctrl_dedup_sorted_bai = ctrl_dedup.sorted_dedup_bai
        File ctrl_dedup_qc_metrics = ctrl_dedup.dedup_qc_metrics

        File? narrow_peak = peaks.narrow_peak
        File? bedgraph_peak_norm = peaks.bedgraph_peak_norm
        File? bw_peak_norm = peaks.bw_peak_norm
    
        File target_qc_filtered_bam_unique = target_qc.final_bam_unique
        File target_qc_filtered_bam_unique_and_multi = target_qc.final_bam_unique_and_multi
        Int target_qc_number_usable_reads_unique_and_multi = target_qc.number_usable_reads_unique_and_multi
        Int target_qc_number_usable_reads_unique = target_qc.number_usable_reads_unique
        File target_qc_fragment_size_distribution_unique_plot_pdf = target_qc.fragment_size_distribution_unique_plot_pdf
        File target_qc_fragment_size_distribution_unique_plot_png = target_qc.fragment_size_distribution_unique_plot_png
        File target_qc_fragment_size_distribution_unique_and_multi_plot_pdf = target_qc.fragment_size_distribution_unique_and_multi_plot_pdf
        File target_qc_fragment_size_distribution_unique_and_multi_plot_png = target_qc.fragment_size_distribution_unique_and_multi_plot_png
        File target_qc_fragment_size_distribution_unique_txt = target_qc.fragment_size_distribution_unique_txt
        File target_qc_fragment_size_distribution_unique_and_multi_txt = target_qc.fragment_size_distribution_unique_and_multi_txt
        File target_qc_bedgraph_unique = target_qc.bedgraph_unique
        File target_qc_bedgraph_cpm_unique = target_qc.bedgraph_cpm_unique
        File target_qc_bigwig_unique = target_qc.bigwig_unique
        File target_qc_bigwig_cpm_unique = target_qc.bigwig_cpm_unique
        File target_qc_bedgraph_unique_and_multi = target_qc.bedgraph_unique_and_multi
        File target_qc_bedgraph_cpm_unique_and_multi = target_qc.bedgraph_cpm_unique_and_multi
        File target_qc_bigwig_unique_and_multi = target_qc.bigwig_unique_and_multi
        File target_qc_bigwig_cpm_unique_and_multi = target_qc.bigwig_cpm_unique_and_multi

        File ctrl_qc_filtered_bam_unique = ctrl_qc.final_bam_unique
        File ctrl_qc_filtered_bam_unique_and_multi = ctrl_qc.final_bam_unique_and_multi
        Int ctrl_qc_number_usable_reads_unique_and_multi = ctrl_qc.number_usable_reads_unique_and_multi
        Int ctrl_qc_number_usable_reads_unique = ctrl_qc.number_usable_reads_unique
        File ctrl_qc_fragment_size_distribution_unique_plot_pdf = ctrl_qc.fragment_size_distribution_unique_plot_pdf
        File ctrl_qc_fragment_size_distribution_unique_plot_png = ctrl_qc.fragment_size_distribution_unique_plot_png
        File ctrl_qc_fragment_size_distribution_unique_and_multi_plot_pdf = ctrl_qc.fragment_size_distribution_unique_and_multi_plot_pdf
        File ctrl_qc_fragment_size_distribution_unique_and_multi_plot_png = ctrl_qc.fragment_size_distribution_unique_and_multi_plot_png
        File ctrl_qc_fragment_size_distribution_unique_txt = ctrl_qc.fragment_size_distribution_unique_txt
        File ctrl_qc_fragment_size_distribution_unique_and_multi_txt = ctrl_qc.fragment_size_distribution_unique_and_multi_txt
        File ctrl_qc_bedgraph_unique = ctrl_qc.bedgraph_unique
        File ctrl_qc_bedgraph_cpm_unique = ctrl_qc.bedgraph_cpm_unique
        File ctrl_qc_bigwig_unique = ctrl_qc.bigwig_unique
        File ctrl_qc_bigwig_cpm_unique = ctrl_qc.bigwig_cpm_unique
        File ctrl_qc_bedgraph_unique_and_multi = ctrl_qc.bedgraph_unique_and_multi
        File ctrl_qc_bedgraph_cpm_unique_and_multi = ctrl_qc.bedgraph_cpm_unique_and_multi
        File ctrl_qc_bigwig_unique_and_multi = ctrl_qc.bigwig_unique_and_multi
        File ctrl_qc_bigwig_cpm_unique_and_multi = ctrl_qc.bigwig_cpm_unique_and_multi
    }
}
