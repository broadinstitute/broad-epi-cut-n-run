version 1.0

import "../tasks/cutnrun_qc.wdl" as qc_task
import "../tasks/cutnrun_generate_tracks.wdl" as generate_tracks_task
import "../tasks/cutnrun_qc_bed.wdl" as qc_bed_task

workflow qc_cut_n_run {
    input {
        File coordinate_sorted_bam
        File chromosome_sizes_file
        Int fragment_minimum_size_cutoff
        String? prefix
    }

    call qc_task.qc as qc {
        input: 
            coordinate_sorted_bam=coordinate_sorted_bam,
            fragment_minimum_size_cutoff=fragment_minimum_size_cutoff,
            chromosome_sizes_file=chromosome_sizes_file,
            prefix=prefix
    }

    call generate_tracks_task.generate_tracks as generate_tracks_unique {
        input: 
            bam=qc.final_bam_unique,
            chromosome_sizes_file=chromosome_sizes_file,
            library_size=qc.number_usable_fragments_unique,
            prefix="${prefix}_unique"
    }

    call generate_tracks_task.generate_tracks as generate_tracks_unique_and_multi {
        input: 
            bam=qc.final_bam_unique_and_multi,
            chromosome_sizes_file=chromosome_sizes_file,
            library_size=qc.number_usable_fragments_unique_and_multi,
            prefix="${prefix}_unique_and_multi"
    }

    call qc_bed_task.qc as bed_qc {
        input: 
            coord_sorted_bam=coordinate_sorted_bam,
            chromosome_sizes_file=chromosome_sizes_file,
            fragment_minimum_size_cutoff=fragment_minimum_size_cutoff,
            prefix=prefix
    }


    output {
        # QC bed outputs
        File namesorted_bedpe = bed_qc.namesorted_bedpe
        # QC outputs
        File final_bam_unique = qc.final_bam_unique
        File final_bam_unique_and_multi = qc.final_bam_unique_and_multi
        Int number_usable_reads_unique_and_multi = qc.number_usable_reads_unique_and_multi
        Int number_usable_reads_unique = qc.number_usable_reads_unique
        File fragment_size_distribution_unique_plot_pdf = qc.fragment_size_distribution_unique_plot_pdf
        File fragment_size_distribution_unique_plot_png = qc.fragment_size_distribution_unique_plot_png
        File fragment_size_distribution_unique_and_multi_plot_pdf = qc.fragment_size_distribution_unique_and_multi_plot_pdf
        File fragment_size_distribution_unique_and_multi_plot_png = qc.fragment_size_distribution_unique_and_multi_plot_png
        File fragment_size_distribution_unique_txt = qc.fragment_size_distribution_unique_txt
        File fragment_size_distribution_unique_and_multi_txt = qc.fragment_size_distribution_unique_and_multi_txt
        File summary_fragment_counts_unique = qc.summary_fragment_counts_unique
        Int number_total_fragments_unique = qc.number_total_fragments_unique
        Int number_usable_fragments_unique = qc.number_usable_fragments_unique
        File summary_fragment_counts_unique_and_multi = qc.summary_fragment_counts_unique_and_multi
        Int number_total_fragments_unique_and_multi = qc.number_total_fragments_unique_and_multi
        Int number_usable_fragments_unique_and_multi = qc.number_usable_fragments_unique_and_multi
        # Generate tracks outputs
        File bedgraph_unique = generate_tracks_unique.bedgraph
        File bedgraph_cpm_unique = generate_tracks_unique.bedgraph_cpm
        File bigwig_unique = generate_tracks_unique.bigwig
        File bigwig_cpm_unique = generate_tracks_unique.bigwig_cpm
        File bedgraph_unique_and_multi = generate_tracks_unique_and_multi.bedgraph
        File bedgraph_cpm_unique_and_multi = generate_tracks_unique_and_multi.bedgraph_cpm
        File bigwig_unique_and_multi = generate_tracks_unique_and_multi.bigwig
        File bigwig_cpm_unique_and_multi = generate_tracks_unique_and_multi.bigwig_cpm
    }
}