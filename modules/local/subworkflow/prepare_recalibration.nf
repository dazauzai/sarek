/*
================================================================================
                        PREPARE RECALIBRATION
================================================================================
*/

include { GATK_BASERECALIBRATOR  as BASERECALIBRATOR }  from '../../nf-core/software/gatk/baserecalibrator'
include { GATK_GATHERBQSRREPORTS as GATHERBQSRREPORTS } from '../../nf-core/software/gatk/gatherbqsrreports'

workflow PREPARE_RECALIBRATION {
    take:
        bam_markduplicates
        intervals
        dbsnp
        dbsnp_tbi
        dict
        fai
        fasta
        known_indels
        known_indels_tbi

    main:

    bam_baserecalibrator = bam_markduplicates.combine(intervals)
    BASERECALIBRATOR(bam_baserecalibrator, dbsnp, dbsnp_tbi, dict, fai, fasta, known_indels, known_indels_tbi)
    table_bqsr = BASERECALIBRATOR.out.report
    tsv_bqsr   = BASERECALIBRATOR.out.tsv

    // STEP 3.5: MERGING RECALIBRATION TABLES
    if (!params.no_intervals) {
        BASERECALIBRATOR.out.report.map{ meta, table ->
            patient = meta.patient
            sample  = meta.sample
            gender  = meta.gender
            status  = meta.status
            [patient, sample, gender, status, table]
        }.groupTuple(by: [0,1]).set{ recaltable }

        recaltable = recaltable.map {
            patient, sample, gender, status, recal ->

            def meta = [:]
            meta.patient = patient
            meta.sample = sample
            meta.gender = gender[0]
            meta.status = status[0]
            meta.id = sample

            [meta, recal]
        }

        GATHERBQSRREPORTS(recaltable)
        table_bqsr = GATHERBQSRREPORTS.out.table
        tsv_bqsr   = GATHERBQSRREPORTS.out.tsv

    }

    // Creating TSV files to restart from this step
    tsv_bqsr.collectFile(storeDir: "${params.outdir}/Preprocessing/TSV") { meta ->
        patient = meta.patient
        sample  = meta.sample
        gender  = meta.gender
        status  = meta.status
        bam = "${params.outdir}/Preprocessing/${sample}/DuplicatesMarked/${sample}.md.bam"
        bai = "${params.outdir}/Preprocessing/${sample}/DuplicatesMarked/${sample}.md.bam.bai"
        ["duplicates_marked_no_table_${sample}.tsv", "${patient}\t${gender}\t${status}\t${sample}\t${bam}\t${bai}\n"]
    }

    tsv_bqsr.map { meta ->
        patient = meta.patient
        sample  = meta.sample
        gender  = meta.gender
        status  = meta.status
        bam = "${params.outdir}/Preprocessing/${sample}/DuplicatesMarked/${sample}.md.bam"
        bai = "${params.outdir}/Preprocessing/${sample}/DuplicatesMarked/${sample}.md.bam.bai"
        "${patient}\t${gender}\t${status}\t${sample}\t${bam}\t${bai}\n"
    }.collectFile(name: 'duplicates_marked_no_table.tsv', sort: true, storeDir: "${params.outdir}/Preprocessing/TSV")

    emit:
        table_bqsr = table_bqsr
}
