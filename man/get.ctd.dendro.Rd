% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/get.ctd.dendro.r
\name{get.ctd.dendro}
\alias{get.ctd.dendro}
\title{Get CTD dendro}
\usage{
get.ctd.dendro(ctd, annotLevel)
}
\arguments{
\item{ctd}{Cell type data strucutre containing $specificity_quantiles}

\item{annotLevel}{Annot level for which the gene covar file should be constructed}
}
\value{
List containing ddata and ordered_cells
}
\description{
Get all dendrogram features used for plotting a dendrogram of cell type
}
\examples{
get.ctd.dendro(ctd,annotLevel=2)
}
