---
appname: realign
description: ''
location: /work/knode05/milanesej/GenomeAnalysisTK-2.8-1/GenomeAnalysisTK.jar
parameters:
  -
    argument: -T
    ordinal: 1
    value: IndelRealigner
    valuetype: string
  -
    argument: -I
    ordinal: 2
    value: ${sample}_N_rmdup_grp_rmlq.bam
    valuetype: string
  -
    argument: -R
    ordinal: 3
    value: $ref
    valuetype: string
  -
    argument: -targetIntervals
    ordinal: 4
    value: ${sample}_N_forRealign.intervals
    valuetype: string
  -
    argument: --out
    ordinal: 5
    value: ${sample}_N_realigned.bam
    valuetype: string
  -
    argument: -LOD
    ordinal: 6
    value: '0.4'
    valuetype: string
  -
    argument: -compress
    ordinal: 7
    value: '5'
    valuetype: integer
