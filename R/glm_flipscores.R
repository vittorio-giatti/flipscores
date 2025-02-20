#' @title Performing customized testing with GLM's estimation
#'
#' @description Used to both fit generalized linear models and perform many tests on coefficients.
#' All of them based on flipped likelihood scores. Referring to canonical glm function options,
#' this one integrates that with more coefficient testing ways: test statistic type, score type,
#' resampling type and test direction. The resulting output is same as the late,
#' but p-value is calculated accounting to new preferencies.
#'
#' @param formula an object of class "formula" (or one that can be coerced to that class): a symbolic description of the model to be fitted.
#' @param X1 X1 is the covariate tested under the alternative hypotesis (H1).
#' @param data an optional data frame, list or environment (or object coercible by as.data.frame to a data frame)
#' containing the variables in the model. If not found in data, the variables are taken from environment(formula),
#' typically the environment from which glm is called.
#' @param family a description of the error distribution and link function to be used in the model.
#' For glm this can be a character string naming a family function, a family function or the result of a call to a family function.
#' For glm.fit only the third option is supported.
#' @param alternative Should be "greater", "less" or "two.sided"
#' @param scoreType The type of score that is computed, either "basic" or "effective".
#' Using "effective" takes into account nuisance estimation.
#' @param statTest Choose a test statistic from flip.statTest. See "flip" package.
#' @param testType by default testType="permutation". The use of option "combination" is more efficient when
#'   X is indicator of groups (i.e. C>1 samples testing). When the total number of possible combinations exceeds 10 thousand,
#'   "permutation" is performed. As an alternative, if you choose "rotation", resampling is performed through random linear
#'   combinations (i.e. a rotation test is performed). This option is useful when only few permutations are available, that is,
#'   minimum reachable significance is hight. See also the details section for the algorithm used. The old syntax rotationTest=TRUE
#'   is maintained for compatibility but is deprecated, use testType="rotation" instead.
#' @param nperms Number of resamples performed. Note: the maximum number of possible permutation is n!^p.
#' Where n indicates the number of observations (rows) and p indicates the number of
#' covariates (columns). R typing: factorial(n)^p. Default is 1000..
#'
#' @usage glm_flipscores = function(formula, family, data, alternative = 0, scoreType = "basic", statTest = "t",
#' testType = "permutation", nperms=1000, weights, subset, na.action, start = NULL,
#' etastart, mustart, offset, control = list(...), model = TRUE, method = "glm.fit",
#' x = FALSE, y = TRUE,  singular.ok = TRUE, contrasts = NULL, ...)
#'
#' @return summary.glm with customized p-values
#'
#' @examples
#' data(iris)
#' data=iris[iris$Species!="setosa",]
#' data$Species=factor(data$Species)
#' data$Petal.Width=data$Petal.Width>median(data$Petal.Width)
#' scoreType = "basic"
#' m1 = glm_flipscores(formula=Species~.+Petal.Width*Petal.Length, 
#' family=binomial, data=data, alternative=0,n_flips=1000)
#' summary(m1)
#' summary(glm(formula, family, data, alternative, scoreType, statTest, testType, B))
#' data = as.data.frame(Titanic)
#' formula = Freq~.
#' family = poisson(link = "log")
#' scoreType = "basic"
#' statTest = "t"
#' alternative = 0
#' testType = "permutation"
#' nperms = 1000
#' m1 = glm_flipscores(formula, family, data, alternative, scoreType, statTest, testType, nperms)
#' m1
#'
#' @docType package
#'
#' @author Livio Finos, Vittorio Giatti \email{livio.finos@unipd.it}
#'
#' @seealso flip
#'
#' @name glm_flipscores
#'
#' @export

glm_flipscores<-function(formula, family, data,
                         score_type = "orthogonalized",
                         n_flips=1000, 
                         ...){
  # catturo la call,
  mf <- match.call()

  if(match(c("alternative"), names(call), 0L)){
    if (alternative == "less" | alternative == "smaller") {alternative = -1}
    if (alternative == "two.sided") {alternative = 0}
    if (alternative == "greater" | alternative == "larger") {alternative = 1}}
  else alternative=0

  score_type=match.arg(score_type,c("orthogonalized","effective","basic"))
  if(missing(score_type))
    stop("test type is not specified or recognized")

  # individuo i parametri specifici di flip score
  m <- match(c("score_type","n_flips","alternative","id"), names(mf), 0L)
  m <- m[m>0]
  flip_param_call= mf[c(1L,m)]
  #rinomino la funzione da chiamare:
  flip_param_call[[1L]]=quote(flip::flip)
  names(flip_param_call)[names(flip_param_call)=="alternative"]="tail"

  # mi tengo solo quelli buoni per glm
  if(length(m)>0) mf <- mf[-m]
  #rinomino la funzione da chiamare:
  mf[[1L]]=quote(glm)
  param_x_ORIGINAL=mf$x
  
  ############### fit the H1 model and append the scores
  model <- compute_scores_glm(mf,score_type)
  
  ###############################
  ## compute flips
  
  ### RENDERE PI§ AGILE INPUT DI ID + quality check
  # id <- model.extract(mf, id)
  if(!is.null(flip_param_call$id))
    model$scores=rowsum(model$scores,eval(flip_param_call$id))
  
  # ## qui usi direttamente eval:                                                              flip_param_call                                                              scoreType = scoreType)})
  flip_param_call$Y=model$scores
  flip_param_call$statTest = "sum"
  results=eval(flip_param_call, parent.frame())
  
  ### output
  model$Tspace=results@permT/nrow(model$scores)
  model$p.values=flip:::p.value(results)
  model$score_type=score_type
  model$n_flips=n_flips

  
  if(is.null(param_x_ORIGINAL)||(!param_x_ORIGINAL)) model$x=NULL
  # class(model) <- 
  class(model) <- c("flipscores", c("glm", "lm"))
  return(model)
}