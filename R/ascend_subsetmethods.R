# Functions for subsetting EMSets
#' SubsetCondition
#'
#' Subset specific conditions from a \linkS4class{EMSet} object.
#'
#' @param object A \linkS4class{EMSet} object
#' @param conditions Name of the columns which contain boolean information on whether to keep or discard a cell.
#'
#' @return An \linkS4class{EMSet} containing only this batch.
#' @include ascend_objects.R
#' @export
setGeneric(name = "SubsetCondition", def = function(object, conditions) {
    standardGeneric("SubsetCondition")
})

setMethod("SubsetCondition", signature("EMSet"), function(object, conditions = c()) {
  # Check if selected batches are present in the batches column
  if (!any(conditions %in% colnames(object@CellInformation))) {
    stop("None of your selected batches are present in the dataset.")
  }

  # Create a new object to output, ensures original object does not get overwritten.
  subset.obj <- object

  # Retrieve data from relevant slots
  expression.matrix <- GetExpressionMatrix(subset.obj, format = "data.frame")
  cell.info <- subset.obj@CellInformation

  # Select out the specified columns
  subset.cell.info <- cell.info[, c(1, which(colnames(cell.info) %in% conditions))]

  # Select out rows that are true in at least one column
  keep.list <- c()

  for (condition in conditions) {
    keep.list <- c(keep.list, which(subset.cell.info[, condition]))
  }

  keep.list <- unique(keep.list)
  subset.cell.info <- cell.info[keep.list, c(1, 2, which(colnames(cell.info) %in% conditions))]
  keep.barcodes <- subset.cell.info[,1]

  # Subset the expression matrix.
  subset.matrix <- expression.matrix[, keep.barcodes]
  subset.obj <- ReplaceExpressionMatrix(subset.obj, subset.matrix)
  subset.obj <- ReplaceCellInfo(subset.obj, subset.cell.info)
  subset.obj <- SyncSlots(subset.obj)

  # Clean up the object
  subset.obj@PCA <- list()
  subset.obj@Clusters <- list()
  subset.obj@Log <- c(subset.obj@Log, list(SubsetByCondition = TRUE, SubsettedConditions = conditions))
  return(subset.obj)
})


#' SubsetBatch
#'
#' Subset a specific batch from a \linkS4class{EMSet} object. This data is already normalised, but if you wish to recluster the data, you will need to use the RunPCA function again.
#'
#' @param object A \linkS4class{EMSet} object
#' @param batches Name or number of the batch(es) you would like to subset.
#'
#' @return An \linkS4class{EMSet} containing only this batch.
#' @include ascend_objects.R
#' @export
setGeneric(name = "SubsetBatch", def = function(object, batches) {
    standardGeneric("SubsetBatch")
})

setMethod("SubsetBatch", signature("EMSet"), function(object, batches = c()) {
    # Check if selected batches are present in the batches column
    if (!any(batches %in% object@CellInformation[, 2])) {
        stop("None of your selected batches are present in the dataset.")
    }

    # Create a new object to output, ensures original object does not get overwritten.
    subset.obj <- object

    # Retrieve data from relevant slots
    expression.matrix <- GetExpressionMatrix(subset.obj, format = "data.frame")
    cell.info <- subset.obj@CellInformation

    # Get barcodes for selected clusters
    subset.cell.info <- cell.info[which(cell.info[, 2] %in% batches), ]

    # Subset the expression matrix.
    subset.matrix <- expression.matrix[, unlist(subset.cell.info[, 1])]
    subset.obj <- ReplaceExpressionMatrix(subset.obj, subset.matrix)
    subset.obj <- SyncSlots(subset.obj)

    # Clean up the object
    subset.obj@PCA <- list()
    subset.obj@Clusters <- list()
    subset.obj@Log <- c(subset.obj@Log, list(SubsetByBatches = TRUE, SubsettedBatches = batches))
    return(subset.obj)
})

#' SubsetCluster
#'
#' Subset a \linkS4class{EMSet} object by cluster. Please make sure you have clustered with \code{\link{RunCORE}} before using this function.
#' This data is already normalised, but if you wish to recluster the data, you will need to use the RunPCA function again.
#'
#' @param object A \linkS4class{EMSet} object
#' @param clusters Clusters to subset from the dataset.
#' @return Returns an \linkS4class{EMSet} containing only this cluster.
#' @include ascend_objects.R
#' @export
#'
setGeneric(name = "SubsetCluster", def = function(object, clusters) {
    standardGeneric("SubsetCluster")
})

setMethod("SubsetCluster", signature("EMSet"), function(object, clusters = c()) {
    # Check if data has been clustered
    if (is.null(object@CellInformation[, "cluster"])) {
        stop("Please cluster your data before using this function.")
    }

    # Check if selected clusters are present in the clustered column
    if (!any(clusters %in% object@CellInformation[, "cluster"])) {
        stop("None of your selected clusters are present in the dataset.")
    }

    if (missing(clusters)) {
        stop("Please specify which cluster(s) you would like to extract from this object.")
    }

    # Create a new object to output, ensures original object does not get overwritten.
    subset.obj <- object

    # Retrieve data from relevant slots
    expression.matrix <- GetExpressionMatrix(subset.obj, format = "data.frame")
    cell.info <- subset.obj@CellInformation

    # Get barcodes for selected clusters
    subset.cell.info <- cell.info[which(cell.info$cluster %in% clusters), ]

    # Subset the expression matrix.
    subset.matrix <- expression.matrix[, as.character(subset.cell.info[, 1])]
    subset.obj <- ReplaceExpressionMatrix(subset.obj, subset.matrix)
    subset.obj <- SyncSlots(subset.obj)

    # Clean up the object
    subset.obj@PCA <- list()
    subset.obj@Clusters <- list()
    subset.obj@Log <- c(subset.obj@Log, list(SubsetByCluster = TRUE, SubsettedClusters = clusters))
    return(subset.obj)
})

#' SubsetCells
#'
#' Subset cells in the supplied list from an \linkS4class{EMSet}.
#'
#' @param object An \linkS4class{EMSet}
#' @param cell.barcodes A list of cell identifiers to subset from the \linkS4class{EMSet}
#' @return An \linkS4class{EMSet}
#' @include ascend_objects.R
#' @export
#'
setGeneric(name = "SubsetCells", def = function(object, cell.barcodes) {
    standardGeneric("SubsetCells")
})

setMethod("SubsetCells", signature("EMSet"), function(object, cell.barcodes = c()) {
    # Check cells are in the expression matrix.
    expression.matrix <- GetExpressionMatrix(object, "data.frame")
    cell.info <- GetCellInfo(object)
    gene.info <- GetGeneInfo(object)
    control.list <- GetControls(object)
    present.cells <- cell.barcodes[cell.barcodes %in% colnames(expression.matrix)]
    
    # Missing cell catch
    if (length(present.cells) == 0) {
        stop("All listed cells were not present in the EMSet.")
    } else {
        # Subset out information
        subset.matrix <- expression.matrix[, present.cells]
        colnames(subset.matrix) <- present.cells
        subset.obj <- ReplaceExpressionMatrix(object, subset.matrix)
        subset.obj <- SyncSlots(subset.obj)

        # Clear Clustering and PCA
        subset.obj@Clusters <- list()
        subset.obj@PCA <- list()

        return(subset.obj)
    }
})
