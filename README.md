Using MAGMA to find causative celltypes for genetically complex traits
using MAGMA
================
Nathan Skene & Julien Bryois
2020-12-03

  - [Introduction](#introduction)
  - [Installation](#installation)
  - [Using the package (basic usage)](#using-the-package-basic-usage)
      - [Set parameters to be used for the
        analysis](#set-parameters-to-be-used-for-the-analysis)
      - [Install and load all the required R packages and
        data](#install-and-load-all-the-required-r-packages-and-data)
      - [Prepare quantile groups for
        celltypes](#prepare-quantile-groups-for-celltypes)
      - [Download summary statistics file & check it is properly
        formatted](#download-summary-statistics-file-check-it-is-properly-formatted)
      - [Map SNPs to Genes](#map-snps-to-genes)
      - [Run the main cell type association
        analysis](#run-the-main-cell-type-association-analysis)
      - [Run the conditional cell type association analysis (linear
        mode)](#run-the-conditional-cell-type-association-analysis-linear-mode)
  - [Conditional analyses (top 10%
    mode)](#conditional-analyses-top-10-mode)
  - [Controlling for a second GWAS](#controlling-for-a-second-gwas)
      - [Download and prepare the ‘Prospective memory’ GWAS summary
        statistics](#download-and-prepare-the-prospective-memory-gwas-summary-statistics)
      - [Check which cell types this GWAS is associated with at
        baseline](#check-which-cell-types-this-gwas-is-associated-with-at-baseline)
      - [Compare enrichments in the two GWAS using a tile
        plot](#compare-enrichments-in-the-two-gwas-using-a-tile-plot)
      - [Check which cell types ‘Fluid Intelligence’ is associated with
        after controlling for ‘Prospective
        memory’](#check-which-cell-types-fluid-intelligence-is-associated-with-after-controlling-for-prospective-memory)
  - [Calculate cell type enrichments directly (using linear
    model)](#calculate-cell-type-enrichments-directly-using-linear-model)
  - [Gene set enrichments](#gene-set-enrichments)
  - [Who do I talk to?](#who-do-i-talk-to)
  - [Citation](#citation)

<!-- Readme.md is generated from Readme.Rmd. Please edit that file -->

## Introduction

This R package contains code used for testing which cell types can
explain the heritability signal from GWAS summary statistics. The method
was described in our 2018 Nature Genetics paper, *“Genetic
identification of brain cell types underlying schizophrenia”*. This
package takes GWAS summary statistics & Single Cell Transcriptome
specificity data (in EWCE’s CTD format) as input. As output it
calculates the associations between the GWAS trait and the celltypes.

## Installation

Before installing this package it is neccesary to install the magma
software package. Please download it from
<https://ctg.cncr.nl/software/magma>. Please do note, the magma software
which forms the backend of this package was developed by Christian de
Leeuw from Daniella Posthuma’s lab. If you use this package to generate
publishable results then you must cite their publication (listed below).

The magma executable should be copied to a directory that is on the
$PATH (e.g. ‘/usr/local/bin’) so that R can find it. Alternatively you
can download it to whereever you want to and add the folder containing
it to your
[PATH](https://www.howtogeek.com/658904/how-to-add-a-directory-to-your-path-in-linux/).
That is, if you’ve placed the file in ‘\~/Packages/’ and you use bash
(instead of e.g. zsh) then add to ‘\~/.bash\_profile’ this line “export
PATH=\~/Packages/magma:$PATH”. Then install this package as follows:

``` r
if(!"devtools" %in% row.names(installed.packages())){
  install.packages("devtools")
}
library(devtools)

if(!"EWCE" %in% row.names(installed.packages())){
  install_github("NathanSkene/EWCE")
}
library(EWCE) 

if(!"MAGMA.Celltyping" %in% row.names(installed.packages())){
  install_github("NathanSkene/MAGMA_Celltyping")
}
library(MAGMA.Celltyping) # Note the "." instead of "_"

if(!"One2One" %in% row.names(installed.packages())){
  devtools::install_github("NathanSkene/One2One")
}
library(One2One)
```

## Using the package (basic usage)

### Set parameters to be used for the analysis

Specify where you want the large files to be downloaded to.

``` r
storage_dir <- "~/Downloads"
```

``` r
# Set path the 1000 genomes reference data.
genome_ref_dir = file.path(storage_dir,"g1000_eur")
if(!file.exists(sprintf("%s/g1000_eur.bed",genome_ref_dir))){
    download.file("https://ctg.cncr.nl/software/MAGMA/ref_data/g1000_eur.zip",destfile=sprintf("%s.zip",genome_ref_dir))
    unzip(sprintf("%s.zip",genome_ref_dir),exdir=genome_ref_dir)
}
genome_ref_path = sprintf("%s/g1000_eur",genome_ref_dir)
```

### Install and load all the required R packages and data

The EWCE package comes with a celltype specificity dataset which we use
as an example. If you want to import your own single cell RNA-seq
dataset, then this needs converting into CTD format; please see the EWCE
tutorial (<https://github.com/NathanSkene/EWCE/>) for explanation of how
to do this.

The [One2One](https://github.com/NathanSkene/One2One) package is used to
obtain 1:1 orthologs.

``` r
# Load the celltype data
data(ctd)

# Load the mouse to human 1:1 orthologs from the One2One package
data(ortholog_data_Mouse_Human)
```

Note that the cell type dataset loaded in the code above is the
Karolinksa cortex/hippocampus data only. For the full Karolinska dataset
with hypothalamus and midbrain instead use the following:

``` r
data(ctd_allKI)
```

Or for the DRONC seq or AIBS datasets use

    data(ctd_Tasic)
    data(ctd_DivSeq)
    data(ctd_AIBS)
    data(ctd_DRONC_human)
    data(ctd_DRONC_human)

### Prepare quantile groups for celltypes

First we need to calculate the quantile groups for each celltype within
the single cell dataset. This is done using the
`prepare.quantile.groups` function. If your single cell dataset is not
from mouse, then change the specificity\_species argument. If you wish
to use a smaller number of bins then

``` r
ctd = prepare.quantile.groups(ctd,specificity_species="mouse",numberOfBins=40)

# Examine how the quantile groups look
print(ctd[[1]]$specificity_quantiles[c("Gfap","Dlg4","Aif1"),])
print(table(ctd[[1]]$specificity_quantiles[,1]))
```

### Download summary statistics file & check it is properly formatted

We need to have a summary statistics file to analyse as input. As an
example download summary statistics for Fluid Intelligence, based on the
UK Biobank, generated by Ben Neale’s group.

The function `format_sumstats_for_magma` does some basic processing to
get it into the right format. Please note, this function is NOT
guarenteed to work. It will work on some sumstats but until the
community gets it’s act together and standardises how we share these, it
is not possible to write a generic function for this. If it doesn’t work
then what you will need to roll your sleeves up and just reformat the
file yourself such that the following criteria are met:

  - SNP, CHR, BP as first three columns.
  - It has at least one of these columns:
    (“Z”,“OR”,“BETA”,“LOG\_ODDS”,“SIGNED\_SUMSTAT”)
  - It has all of these columns: (“SNP”,“CHR”,“BP”,“P”,“A1”,“A2”)

The UK Biobank data from Ben Neale uses GRCh37 so hit ‘1’ when it asks.
If you’re using your own data and it asks you’ll need to check this.

``` r
# Download and unzip the summary statistics file
library(R.utils)
gwas_sumstats_path = file.path(storage_dir,"20016_irnt.gwas.imputed_v3.both_sexes.tsv")
if(!file.exists(gwas_sumstats_path)){
    #download.file("https://www.dropbox.com/s/shsiq0brkax886j/20016.assoc.tsv.gz?raw=1",destfile=sprintf("%s.gz",gwas_sumstats_path))
    download.file("https://www.dropbox.com/s/t3lrfj1id8133sx/20016_irnt.gwas.imputed_v3.both_sexes.tsv.bgz?dl=1",destfile=sprintf("%s.gz",gwas_sumstats_path))
    gunzip(sprintf("%s.gz",gwas_sumstats_path),gwas_sumstats_path)
}

# Format it (i.e. column headers etc)
tmpSumStatsPath = format_sumstats_for_magma(path=gwas_sumstats_path)
gwas_sumstats_path_formatted = sprintf("%s.formatted",gwas_sumstats_path)
file.copy(from=tmpSumStatsPath,to=gwas_sumstats_path_formatted,overwrite = TRUE)
```

### Map SNPs to Genes

``` r
genesOutPath = map.snps.to.genes(path_formatted=gwas_sumstats_path_formatted,
                                 genome_ref_path=genome_ref_path)
```

### Run the main cell type association analysis

The analyses can be run in either linear or top10% enrichment modes.
Let’s start with linear:

``` r
ctAssocsLinear = calculate_celltype_associations(ctd=ctd,
                                                 gwas_sumstats_path=gwas_sumstats_path_formatted,
                                                 genome_ref_path=genome_ref_path,
                                                 specificity_species = "mouse")
FigsLinear = plot_celltype_associations(ctAssocs=ctAssocsLinear,
                                        ctd=ctd)
```

Now let’s add the top 10% mode

``` r
ctAssocsTop = calculate_celltype_associations(ctd=ctd,
                                              gwas_sumstats_path=gwas_sumstats_path_formatted,
                                              genome_ref_path=genome_ref_path,
                                              EnrichmentMode="Top 10%")
FigsTopDecile = plot_celltype_associations(ctAssocs=ctAssocsTop,
                                           ctd=ctd)
```

Then plot linear together with the top decile mode

``` r
ctAssocMerged = merge_magma_results(ctAssoc1=ctAssocsLinear,
                                    ctAssoc2=ctAssocsTop)
FigsMerged = plot_celltype_associations(ctAssocs=ctAssocMerged,
                                        ctd=ctd)
```

### Run the conditional cell type association analysis (linear mode)

By default, it is assumed that you want to run the linear enrichment
analysis. There are two modes for conditional analyses, you can either
control for the top N cell types from the baseline analysis (in which
case, set controlTopNcells) or control for specific specified cell types
(in which case, set controlledCTs).

``` r
# Conditional analysis
ctCondAssocs = calculate_conditional_celltype_associations(ctd,gwas_sumstats_path_formatted,genome_ref_path=genome_ref_path,analysis_name = "Conditional",controlTopNcells=2)
plot_celltype_associations(ctCondAssocs,ctd=ctd)
```

Let’s try as an alternative to control for expression of both the level
1 pyramidal neuron types at the same time

``` r
ctCondAssocs = calculate_conditional_celltype_associations(ctd,gwas_sumstats_path_formatted,genome_ref_path=genome_ref_path,analysis_name = "Conditional",controlledCTs=c("pyramidal CA1","pyramidal SS","interneurons"),controlledAnnotLevel=1)
plot_celltype_associations(ctCondAssocs,ctd=ctd)
```

Note that Periventricular Microglia (PVM) go from totally
non-significant to significant once the neurons are controlled for. Test
if this change is significant as follows:

``` r
magma1 = ctCondAssocs[[2]]$results[ctCondAssocs[[2]]$results$CONTROL=="BASELINE",]
magma2 = ctCondAssocs[[2]]$results[ctCondAssocs[[2]]$results$CONTROL=="pyramidal CA1,pyramidal SS,interneurons",]
resCompared = compare.trait.enrichments(magma1=magma1,magma2=magma2,annotLevel=2,ctd=ctd)
resCompared[1:3,]
```

Using this approach we can see that the increased enrichment is
microglia in the controlled analysis is almost significantly increased
relative to the baseline analysis.

## Conditional analyses (top 10% mode)

Conditional analyses can also be performed with top 10% mode (although
the conditioning is done in linear mode)

``` r
ctCondAssocsTopTen = calculate_conditional_celltype_associations(ctd,gwas_sumstats_path_formatted,genome_ref_path=genome_ref_path,analysis_name = "Conditional",controlledCTs=c("pyramidal CA1","pyramidal SS","interneurons"),controlledAnnotLevel=1,EnrichmentMode = "Top 10%")
plot_celltype_associations(ctCondAssocsTopTen,ctd=ctd)
```

## Controlling for a second GWAS

We now want to test enrichments that remain in a GWAS after we control
for a second GWAS. So let’s download a second GWAS sumstats file and
prepare it for analysis.

20018.assoc.tsv is the sumstats file for ‘Prospective memory result’
from the UK Biobank.

20016.assoc.tsv is the sumstats file for ‘Fluid Intelligence Score’ from
the UK Biobank.

So let’s subtract genes associated with prospective memory from those
involved in fluid intelligence.

### Download and prepare the ‘Prospective memory’ GWAS summary statistics

``` r
# Download and unzip the summary statistics file
library(R.utils)
gwas_sumstats_path = "~/Downloads/20018.gwas.imputed_v3.both_sexes.tsv"
if(!file.exists(gwas_sumstats_path)){
    download.file("https://www.dropbox.com/s/j6mde051pl8k8vu/20018.gwas.imputed_v3.both_sexes.tsv.bgz?dl=1",destfile=sprintf("%s.gz",gwas_sumstats_path))
    gunzip(sprintf("%s.gz",gwas_sumstats_path),gwas_sumstats_path)
}

# Format & map SNPs to genes
tmpSumStatsPath = format_sumstats_for_magma(gwas_sumstats_path)
gwas_sumstats_path_formatted = sprintf("%s.formatted",gwas_sumstats_path)
file.copy(from=tmpSumStatsPath,to=gwas_sumstats_path_formatted,overwrite = TRUE)

genesOutPath = map.snps.to.genes(gwas_sumstats_path_formatted,genome_ref_path=genome_ref_path)
```

### Check which cell types this GWAS is associated with at baseline

``` r
gwas_sumstats_path_Memory = "~/Downloads/20018.gwas.imputed_v3.both_sexes.tsv.formatted"
gwas_sumstats_path_Intelligence = "~/Downloads/20016.gwas.imputed_v3.both_sexes.tsv.formatted"
ctAssocsLinearMemory = calculate_celltype_associations(ctd,gwas_sumstats_path_Memory,genome_ref_path=genome_ref_path,specificity_species = "mouse")
ctAssocsLinearIntelligence = calculate_celltype_associations(ctd,gwas_sumstats_path_Intelligence,genome_ref_path=genome_ref_path,specificity_species = "mouse")
plot_celltype_associations(ctAssocsLinearMemory,ctd=ctd)
```

### Compare enrichments in the two GWAS using a tile plot

``` r
ctAssocMerged_MemInt = merge_magma_results(ctAssocsLinearMemory,ctAssocsLinearIntelligence)
FigsMerged_MemInt = magma.tileplot(ctd=ctd,results=ctAssocMerged_MemInt[[1]]$results,annotLevel=1,fileTag="Merged_MemInt_lvl1",output_path = "~/Desktop")
FigsMerged_MemInt = magma.tileplot(ctd=ctd,results=ctAssocMerged_MemInt[[2]]$results,annotLevel=2,fileTag="Merged_MemInt_lvl2",output_path = "~/Desktop")
```

### Check which cell types ‘Fluid Intelligence’ is associated with after controlling for ‘Prospective memory’

``` r
# Set paths for GWAS sum stats + .genes.out file (with the z-scores)
gwas_sumstats_path = gwas_sumstats_path_Intelligence # "/Users/natske/GWAS_Summary_Statistics/20016.assoc.tsv"
memoryGenesOut = sprintf("%s.genes.out",get.magma.paths(gwas_sumstats_path_Memory,upstream_kb = 10,downstream_kb = 1.5)$filePathPrefix)

ctAssocsLinear = calculate_celltype_associations(ctd,gwas_sumstats_path,genome_ref_path=genome_ref_path,specificity_species = "mouse",genesOutCOND=memoryGenesOut,analysis_name = "ControllingForPropMemory")
FigsLinear = plot_celltype_associations(ctAssocsLinear,ctd=ctd,fileTag = "ControllingForPropMemory")
```

We find that after controlling for prospective memory, there is no
significant enrichment left associated with fluid intelligence.

## Calculate cell type enrichments directly (using linear model)

``` r
magmaGenesOut = adjust.zstat.in.genesOut(ctd,magma_file="/Users/natske/GWAS_Summary_Statistics/MAGMA_Files/20016.assoc.tsv.10UP.1.5DOWN/20016.assoc.tsv.10UP.1.5DOWN.genes.out",sctSpecies="mouse")
output = calculate.celltype.enrichment.probabilities.wtLimma(magmaAdjZ=magmaGenesOut,ctd,thresh=0.0001,sctSpecies="mouse",annotLevel=4)
```

We can then get the probability of the celltype being enriched as
follows

``` r
print(sort(output))
```

The results should closely resemble those obtained using MAGMA

## Gene set enrichments

To test whether a gene set (in HGNC or MGI format) is enriched using
MAGMA the following commands can be used:

``` r
data("rbfox_binding")
gwas_sumstats_path = "/Users/natske/GWAS_Summary_Statistics/20016.assoc.tsv"
geneset_res = calculate_geneset_enrichment(geneset=rbfox_binding,gwas_sumstats_path=gwas_sumstats_path,analysis_name="Rbfox_20016",upstream_kb=10,downstream_kb=1.5,genome_ref_path=genome_ref_path,geneset_species="mouse")
print(geneset_res)
```

We can then test whether the geneset is still enriched after controlling
for celltype enrichment:

``` r
data(ctd_allKI)
ctd = prepare.quantile.groups(ctd,specificity_species="mouse",numberOfBins=40)
analysis_name="Rbfox_16_pyrSS"
controlledCTs = c("pyramidal SS")
cond_geneset_res_pyrSS = calculate_conditional_geneset_enrichment(geneset,ctd,controlledAnnotLevel=1,controlledCTs,gwas_sumstats_path,analysis_name=analysis_name,genome_ref_path=genome_ref_path,specificity_species = "mouse")
controlledCTs = c("pyramidal CA1")
cond_geneset_res_pyrCA1 = calculate_conditional_geneset_enrichment(geneset,ctd,controlledAnnotLevel=1,controlledCTs,gwas_sumstats_path,analysis_name=analysis_name,genome_ref_path=genome_ref_path,specificity_species = "mouse")
controlledCTs = c("pyramidal CA1","pyramidal SS")
cond_geneset_res_pyr = calculate_conditional_geneset_enrichment(geneset,ctd,controlledAnnotLevel=1,controlledCTs,gwas_sumstats_path,analysis_name=analysis_name,genome_ref_path=genome_ref_path,specificity_species = "mouse")
controlledCTs = c("Medium Spiny Neuron")
cond_geneset_res_MSN = calculate_conditional_geneset_enrichment(geneset,ctd,controlledAnnotLevel=1,controlledCTs,gwas_sumstats_path,analysis_name=analysis_name,genome_ref_path=genome_ref_path,specificity_species = "mouse")
controlledCTs = c("Medium Spiny Neuron","pyramidal CA1","pyramidal SS","interneurons")
cond_geneset_res = calculate_conditional_geneset_enrichment(geneset,ctd,controlledAnnotLevel=1,controlledCTs,gwas_sumstats_path,analysis_name=analysis_name,genome_ref_path=genome_ref_path,specificity_species = "mouse")
```

## Who do I talk to?

If you have any issues using the package then please get in touch with
Nathan Skene (n.skene at imperial.ac.uk). Bug reports etc are all most
welcome, we want the package to be easy to use for everyone\!

## Citation

If you use the software then please cite

[Skene, et al. Genetic identification of brain cell types underlying
schizophrenia. Nature Genetics,
2018.](https://www.nature.com/articles/s41588-018-0129-5)

The package utilises the MAGMA package developed in the Complex Trait
Genetics lab at VU university (not us\!) so please also cite their work:

[de Leeuw, et al. MAGMA: Generalized gene-set analysis of GWAS data.
PLoS Comput Biol,
2015.](https://journals.plos.org/ploscompbiol/article?id=10.1371%2Fjournal.pcbi.1004219)

If you use the EWCE package as well then please cite

[Skene, et al. Identification of Vulnerable Cell Types in Major Brain
Disorders Using Single Cell Transcriptomes and Expression Weighted Cell
Type Enrichment. Front. Neurosci,
2016.](https://www.frontiersin.org/articles/10.3389/fnins.2016.00016/full)

If you use the cortex/hippocampus single cell data associated with this
package then please cite the following papers:

[Zeisel, et al. Cell types in the mouse cortex and hippocampus revealed
by single-cell RNA-seq. Science,
2015.](http://www.sciencemag.org/content/early/2015/02/18/science.aaa1934.abstract)

If you use the midbrain and hypothalamus single cell datasets associated
with the 2018 paper then please cite the following papers:

[La Manno, et al. Molecular Diversity of Midbrain Development in Mouse,
Human, and Stem Cells. Cell,
2016.](http://www.cell.com/cell/fulltext/S0092-8674\(16\)31309-5)

[Romanov, et al. Molecular interrogation of hypothalamic organization
reveals distinct dopamine neuronal subtypes. Nature Neuroscience,
2016.](http://www.nature.com/neuro/journal/vaop/ncurrent/full/nn.4462.html)
