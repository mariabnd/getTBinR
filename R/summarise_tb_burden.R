#' Summarise TB Burden - By Region, Globally and for Custom Groups
#'
#'
#' @description Summarise TB burden metrics by region, globally, and for custom groupings. For variables with
#' uncertainty represented by confidence intervals bootstrapping can be used (assuming a normal distribution) to
#' include this in any estimated summary measures. Currently two statistics are supported; the mean (with
#' 95\% confidence intervals) and the median (with 95\% interquartile range), rates and proportions.
#' @param samples Numeric, the number of samples to use to generate confidence
#' intervals (only used when \code{conf} are present)
#' @param compare_to_world Logical, defaults to \code{TRUE}. Should a comparison be made to
#' the metric of interests global value.
#' @param custom_compare Logical, defaults to \code{NULL}. A named list of custom countries.
#' @param compare_all_regions Logical, defaults to \code{TRUE}. Should all regions be compared.
#' @param truncate_at_zero Logical, defaults to \code{TRUE}. Should lower bounds be truncated at zero?
#' @param stat Character string, defaults to \code{"rate"}. The statistic to use to summarise the metric, currently
#' `"mean"`, `"median"`, `"rate"` and `"prop"` are supported. Note "mean" and "median" do not recompute the supplied
#' country levels values but can be used to summarise the distribution of region or global metrics. `"prop"` and`"rate"`
#' compute the overall incidence rate for a given grouping (i.e the sum of the metric divided by the sum of the denominator).
#' @param denom Character string defaulting to `e_pop_num` (country level population). If `stat` is set to `rate` or
#' `prop` then this is the parameter to use as the denominator.
#' @param rate_scale Numeric defaults to 100,000. The scaling to use for rates. If `stat` is to set to `prop` then this defaults
#' to 1.
#' @inheritParams prepare_df_plot
#' @return A tibble containing summarised values (with 95% confidence intervals) for the metric of choice
#' stratified by area and year.
#' @export
#'
#' @import magrittr
#' @importFrom dplyr mutate group_by ungroup select select_at mutate_at left_join lag bind_rows summarise summarise_at one_of rename_at arrange n contains
#' @importFrom purrr map map2_dfr compact reduce map_lgl
#' @importFrom tibble as_tibble
#' @importFrom tidyr nest unnest
#' @importFrom stats qnorm sd median quantile
#' @examples
#'
#' ## Get the most recent year of data
#' tb_burden <- get_tb_burden()
#' most_recent_year <- max(tb_burden$year)
#'
#' ## Get summary of the e_mdr_pct_rr_new cases
#' summarise_tb_burden(
#'   metric = "e_mdr_pct_rr_new",
#'   years = most_recent_year,
#'   stat = "mean",
#'   samples = 100,
#'   compare_all_regions = TRUE,
#'   compare_to_world = TRUE,
#'   verbose = TRUE
#' )
#' \dontrun{
#' ## Get median (with 95% IQR) of the case fatality rate for regions and the world
#' ## Boostrapping uncertainty in country measures
#' summarise_tb_burden(
#'   metric = "cfr",
#'   years = most_recent_year,
#'   samples = 100,
#'   stat = "median",
#'   compare_all_regions = TRUE,
#'   compare_to_world = TRUE,
#'   verbose = FALSE
#' )
#'
#'
#' ## Get summary data for the UK, Europe and the world
#' ## Bootstrapping CI's
#' summarise_tb_burden(
#'   metric = "e_inc_num",
#'   samples = 100,
#'   stat = "median",
#'   countries = "United Kingdom",
#'   compare_to_world = TRUE,
#'   compare_to_region = TRUE,
#'   verbose = FALSE
#' )
#'
#' ## Get an overview of incidence rates regionally and globally compared to the UK
#' summarise_tb_burden(
#'   metric = "e_inc_num",
#'   stat = "rate",
#'   countries = "United Kingdom",
#'   compare_to_world = TRUE,
#'   compare_to_region = TRUE,
#'   verbose = FALSE
#' )
#' }
summarise_tb_burden <- function(df = NULL,
                                dict = NULL,
                                metric = "e_inc_num",
                                metric_label = NULL,
                                conf = c("_lo", "_hi"),
                                years = NULL,
                                samples = 1000,
                                countries = NULL,
                                compare_to_region = FALSE,
                                compare_to_world = TRUE,
                                custom_compare = NULL,
                                compare_all_regions = TRUE,
                                stat = "rate",
                                denom = "e_pop_num",
                                rate_scale = 1e5,
                                truncate_at_zero = TRUE,
                                annual_change = FALSE,
                                download_data = TRUE,
                                save = TRUE,
                                verbose = FALSE,
                                ...) {

  ## Deal with undefined global function notes
  . <- NULL
  Area <- NULL
  Year <- NULL
  country <- NULL
  data <- NULL
  e_pop_num <- NULL
  g_whoregion <- NULL
  id <- NULL
  mean_hi <- NULL
  mean_lo <- NULL
  n <- NULL
  pop <- NULL
  year <- NULL
  area <- NULL
  metrics <- NULL

  ## Set rate scale to be 1 if computing proportion
  if (stat == "prop") {
    rate_scale <- 1
  }

  ## Set up function to compute variable summary
  get_summary <- function(summarised_df,
                          int_rate_scale = rate_scale,
                          int_metrics = metrics) {
    if (stat == "mean") {
      summarised_df <- summarised_df %>%
        summarise(
          mean = mean(samples, na.rm = TRUE),
          sd = sd(samples, na.rm = TRUE)
        ) %>%
        mutate(
          mean_lo = qnorm(0.025, mean, sd),
          mean_hi = qnorm(0.975, mean, sd)
        )
    } else if (stat == "median") {
      summarised_df <- summarised_df %>%
        summarise(
          mean = median(samples, na.rm = TRUE),
          mean_lo = quantile(samples, 0.025, na.rm = TRUE),
          mean_hi = quantile(samples, 0.975, na.rm = TRUE)
        )
    } else if (stat %in% c("rate", "prop")) {
      summarised_df <- summarised_df %>%
        summarise_at(
          .vars = c(metrics, "denom"),
          list(~ sum(as.numeric(.), na.rm = T))
        ) %>%
        mutate_at(
          .vars = int_metrics,
          .funs = list(~ . / denom * int_rate_scale)
        ) %>%
        select(-denom)


      colnames(summarised_df) <- c("Area", "Year", paste0("mean", c("", "_lo", "_hi")))
    } else {
      stop("This statistic is not currently supported.")
    }
    return(summarised_df)
  }

  if (!is.null(countries)) {
    if (verbose) {
      message("Extracting data for specified countries")
    }

    countries_df <- prepare_df_plot(
      df = df,
      dict = dict,
      metric = metric,
      metric_label = metric_label,
      conf = conf,
      countries = countries,
      compare_to_region = FALSE,
      annual_change = FALSE,
      download_data = download_data,
      save = save,
      verbose = verbose,
      ...
    )$df

    countries_df <- mutate(countries_df, Area = as.character(country))
  } else {
    countries_df <- NULL
  }

  if (compare_to_region | compare_all_regions) {
    if (compare_all_regions) {
      countries_region <- NULL
    } else {
      countries_region <- countries
    }

    regions_df <- prepare_df_plot(
      df = df,
      dict = dict,
      metric = metric,
      metric_label = metric_label,
      conf = conf,
      countries = countries_region,
      compare_to_region = TRUE,
      annual_change = FALSE,
      download_data = download_data,
      save = save,
      verbose = verbose,
      ...
    )$df

    regions_df <- mutate(regions_df, Area = as.character(g_whoregion))
  } else {
    regions_df <- NULL
  }

  if (compare_to_world) {
    world_df <- prepare_df_plot(
      df = df,
      dict = dict,
      metric = metric,
      metric_label = metric_label,
      conf = conf,
      countries = NULL,
      compare_to_region = FALSE,
      annual_change = FALSE,
      download_data = download_data,
      save = save,
      verbose = verbose,
      ...
    )$df

    world_df <- mutate(world_df, Area = "Global")
  } else {
    world_df <- NULL
  }



  if (!is.null(custom_compare)) {
    if (!is.list(custom_compare)) {
      stop("custom_compare must be a named list of 1 or more groups of countries")
    }

    if (!length(names(custom_compare)) == length(custom_compare)) {
      stop("Each group must have an associated name")
    }

    custom_group_df <- suppressWarnings(
      map2_dfr(
        custom_compare,
        names(custom_compare), ~ prepare_df_plot(
          df = df,
          dict = dict,
          metric = metric,
          metric_label = metric_label,
          conf = conf,
          countries = .x,
          compare_to_region = FALSE,
          annual_change = FALSE,
          download_data = download_data,
          save = save,
          verbose = verbose,
          ...
        )$df %>%
          mutate(Area = .y)
      )
    )
  } else {
    custom_group_df <- NULL
  }

  if (compare_to_region | compare_all_regions | !is.null(custom_group_df) | compare_to_world) {
    ## Combine into a single data-set
    all_df <- list(regions_df, custom_group_df, world_df)
    all_df <- compact(all_df)
    all_df <- suppressWarnings(reduce(all_df, bind_rows))

    ## Filter for require years
    if (!is.null(years)) {
      if (verbose) {
        message("Filtering to use only data from: ", paste(years, collapse = ", "))
      }
      all_df <- filter(all_df, year %in% years)
    }

    ## Get summarised estimate for points values

    sim_to_metric <- names(all_df)[grepl(metric, names(all_df))]

    conf_present <- map_lgl(conf, ~ any(grepl(., sim_to_metric))) %>%
      all()

    if (!conf_present) {
      if (verbose) {
        message("Confidence intervals were not found using your specified conf, so defaulting to estimating
                only based on the point estimate.")
      }
      conf <- NULL
    }

    if (stat %in% c("prop", "rate")) {
      if (!is.null(conf)) {
        metrics <- c(metric, paste0(metric, conf))
      } else {
        metrics <- c(metric, paste0(metric, c("_lo", "_hi")))
        all_df[metrics] <- all_df[[metric]]
      }


      summarised_df <- all_df %>%
        rename_at(.vars = denom, ~"denom")
    } else if (is.null(conf)) {
      summarised_df <- all_df %>%
        rename_at(.vars = metric, .funs = list(~ paste0("samples")))
    } else {
      metrics <- c(metric, paste0(metric, conf))

      ## If the data comes with confidence intervals attached
      summarised_df <- all_df %>%
        mutate_at(
          .vars = metrics,
          .funs = list(~ ifelse(is.na(.), all_df[[metric]], .))
        ) %>%
        group_by(Area, Year)

      summarised_df$sd <- (summarised_df[[metrics[3]]] - summarised_df[[metrics[2]]]) / (2 * 1.96)

      summarised_df <- summarised_df %>%
        ungroup() %>%
        mutate(id = 1:n()) %>%
        group_by(Area, Year, id) %>%
        tidyr::nest() %>%
        mutate(sample = map(data, ~ data.frame(samples = suppressWarnings(
          rnorm(
            samples,
            .[[metrics[1]]],
            .$sd
          )
        )) %>%
          as_tibble())) %>%
        tidyr::unnest(sample)
    }

    ## Get upper and lower confidence intervals
    summarised_df <- summarised_df %>%
      group_by(Area, Year) %>%
      get_summary() %>%
      ungroup() %>%
      mutate_at(
        .vars = c("mean", "mean_lo", "mean_hi"),
        .funs = list(~ ifelse(. %in% NaN, NA, .))
      )


    ## Clean up summarised results
    summarised_df <- summarised_df %>%
      select(Area, Year, mean, mean_lo, mean_hi)

    if (truncate_at_zero) {
      summarised_df <- summarised_df %>%
        mutate_at(
          .vars = c("mean", "mean_lo", "mean_hi"),
          .funs = list(~ ifelse(. < 0, 0, .))
        )
    }

    colnames(summarised_df) <- c("area", "year", paste0(metric, c("", "_lo", "_hi")))
  } else {
    summarised_df <- NULL
  }

  ## Get list of areas
  area_list <- names(custom_compare)

  if (!is.null(regions_df)) {
    area_list <- c(area_list, unique(regions_df$Area)[order(unique(regions_df$Area))])
  }

  area_list <- c(area_list, "Global")

  if (!is.null(countries_df)) {
    if (!is.null(conf)) {
      metrics <- c(metric, paste0(metric, conf))
    } else {
      metrics <- c(metric, paste0(metric, c("_lo", "_hi")))
      countries_df[metrics] <- countries_df[[metric]]
    }

    output_df <- countries_df %>%
      select(area = Area, year, one_of(paste0(metric, c("", "_lo", "_hi"))), contains(denom))

    if (!is.null(years)) {
      output_df <- filter(output_df, year %in% years)
    }

    ## Estimate rate/proportions for countries specified.
    if (stat %in% c("rate", "prop")) {
      output_df <- output_df %>%
        rename_at(.vars = denom, .funs = ~"denom") %>%
        group_by(area, year) %>%
        get_summary() %>%
        ungroup() %>%
        mutate_at(
          .vars = c("mean", "mean_lo", "mean_hi"),
          .funs = list(~ ifelse(. %in% NaN, NA, .))
        )

      colnames(output_df) <- c("area", "year", paste0(metric, c("", "_lo", "_hi")))
    }

    if (!is.null(summarised_df)) {
      output_df <- output_df %>%
        bind_rows(summarised_df)
    }

    area_list <- c(unique(countries_df$Area), area_list)
  } else {
    output_df <- summarised_df
  }


  output_df <- mutate(output_df, area = factor(area, levels = area_list))

  ## Estimate annual change
  if (annual_change) {
    if (is.null(conf)) {
      metrics <- metric
    } else {
      metrics <- c(metric, paste0(metric, conf))
    }

    output_df <- output_df %>%
      group_by(area) %>%
      arrange(year) %>%
      mutate_at(.vars = metrics, .funs = list(~ (. - lag(.)) / lag(.))) %>%
      arrange(year) %>%
      slice(-1) %>%
      ungroup() %>%
      mutate_at(
        .vars = metrics,
        .funs = list(~ replace(., is.nan(.), NA))
      )
  }

  return(output_df)
}
