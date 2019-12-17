---
appname: printReads
description: ''
location: /work/knode05/milanesej/GenomeAnalysisTK-2.8-1/GenomeAnalysisTK.jar
parameters:
  -
    argument: -T
    ordinal: 1
    value: PrintReads
    valuetype: string
  -
    argument: -I
    ordinal: 2
    value: ${sample}_N_realigned.bam
    valuetype: string
  -
    argument: -R
    ordinal: 3
    value: $ref
    valuetype: string
  -
    argument: -o
    ordinal: 4
    value: ${sample}_N_realigned_recal.bam
    valuetype: string
  -
    argument: -BQSR
    ordinal: 5
    value: ${sample}_N_recal_data.grp
    valuetype: string
