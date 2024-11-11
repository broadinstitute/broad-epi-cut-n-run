version 1.0

import "tasks/task_qc.wdl" as qc

workflow qc_cut_n_run {
    input {
        File bam
        Int fragment_minimum_size_cutoff
        String? prefix
    }

    call qc {
        input: 
            bam=bam,
            fragment_minimum_size_cutoff=fragment_minimum_size_cutoff,
            prefix=prefix
    }


    output {
        File filtered_bam_unique = qc.filtered_bam_unique
        File filtered_bam_unique_and_multi = qc.filtered_bam_unique_and_multi
        Int number_usable_reads_unique_and_multi = qc.number_usable_reads_unique_and_multi
        Int number_usable_reads_unique = qc.number_usable_reads_unique
        File fragment_size_distribution_unique_plot_pdf = qc.fragment_size_distribution_unique_plot_pdf
        File fragment_size_distribution_unique_plot_png = qc.fragment_size_distribution_unique_plot_png
        File fragment_size_distribution_unique_and_multi_plot_pdf = qc.fragment_size_distribution_unique_and_multi_plot_pdf
        File fragment_size_distribution_unique_and_multi_plot_png = qc.fragment_size_distribution_unique_and_multi_plot_png
        File summary_fragment_counts_unique = qc.summary_fragment_counts_unique
        Int number_total_fragment_unique = qc.number_total_fragment_unique
        Int number_usable_fragments_unique = qc.number_usable_fragments_unique
        File summary_fragment_counts_unique_and_multi = qc.summary_fragment_counts_unique_and_multi
        Int number_total_fragment_unique_and_multi = qc.number_total_fragment_unique_and_multi
        Int number_usable_fragments_unique_and_multi = qc.number_usable_fragments_unique_and_multi

    }
}