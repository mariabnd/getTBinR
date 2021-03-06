#' Plot an overview of TB Burden for Multiple Countries
#'
#' @description This functions returns a dot plot for a given metric over a specified
#' list of countries. If \code{compare_to_region} is specified then a given country will
#' be compared to others in its region. This enables the user to rapidly understand trends in
#' Tuberculosis over time and the progress towards global elimination.
#' @param legend Character string, defaults to `"right"`. Position of the legend see `?ggplot2::theme` for defaults but known
#' options are: `"none"`, `"top"`, `"right"` and `"bottom"`.
#' @inheritParams plot_tb_burden
#' @seealso get_tb_burden search_data_dict
#' @return A dot plot of any numeric metric by country.
#' @export
#' @importFrom ggplot2 ggplot aes geom_point geom_hline coord_flip theme theme_minimal labs facet_wrap
#' @importFrom rlang .data
#' @importFrom viridis scale_colour_viridis
#' @importFrom plotly ggplotly style
#' @importFrom scales percent
#' @examples
#'
#' ## Plot incidence rates over time for both the United Kingdom and Botswana
#' plot_tb_burden_overview(
#'   countries = c("United Kingdom", "Botswana"),
#'   compare_to_region = FALSE
#' )
#'
#' ## Plot percentage annual change in incidence rates.
#' plot_tb_burden_overview(
#'   countries = c("United Kingdom", "Botswana"),
#'   compare_to_region = FALSE, annual_change = TRUE
#' )
#'
#' ## Compare incidence rates in the UK and Botswana to incidence rates in their regions
#' plot_tb_burden_overview(
#'   countries = c("United Kingdom", "Botswana"),
#'   compare_to_region = TRUE
#' )
#'
#' ## Find variables relating to mortality in the WHO dataset
#' search_data_dict(def = "mortality")
#'
#' ## Compare mortality rates (exc HIV) in the UK and Botswana to mortality rates in their regions
#' ## Do not show progress messages
#' plot_tb_burden_overview(
#'   metric = "e_mort_exc_tbhiv_100k",
#'   countries = c("United Kingdom", "Botswana"),
#'   compare_to_region = TRUE, verbose = FALSE
#' )
plot_tb_burden_overview <- function(df = NULL, dict = NULL,
                                    metric = "e_inc_100k",
                                    metric_label = NULL,
                                    countries = NULL,
                                    years = NULL,
                                    compare_to_region = FALSE,
                                    facet = NULL, annual_change = FALSE,
                                    trans = "identity",
                                    legend = "bottom",
                                    scales = "free_y",
                                    interactive = FALSE,
                                    download_data = TRUE,
                                    save = TRUE,
                                    viridis_palette = "viridis",
                                    viridis_direction = -1,
                                    viridis_end = 0.9,
                                    verbose = FALSE,
                                    ...) {
  Year <- NULL

  df_prep <- prepare_df_plot(
    df = df,
    dict = dict,
    metric = metric,
    metric_label = metric_label,
    countries = countries,
    years = years,
    compare_to_region = compare_to_region,
    facet = facet,
    annual_change = annual_change,
    trans = trans,
    download_data = download_data,
    save = save,
    verbose = verbose,
    ...
  )
  country <- NULL

  plot <- ggplot(df_prep$df, aes(
    x = country,
    y = .data[[df_prep$metric_label]],
    col = Year
  )) +
    geom_point(alpha = 0.6, size = 1.5, na.rm = TRUE)

  plot <- plot +
    scale_colour_viridis(
      end = viridis_end, direction = viridis_direction,
      discrete = FALSE, trans = trans,
      option = viridis_palette
    ) +
    theme_minimal() +
    theme(legend.position = legend) +
    labs(
      x = "Country", y = df_prep$metric_label,
      caption = "Source: World Health Organization"
    ) +
    coord_flip()

  if (annual_change) {
    plot <- plot +
      scale_y_continuous(labels = percent, trans = trans) +
      geom_hline(yintercept = 0, linetype = 2, alpha = 0.6)
  } else {
    plot <- plot +
      scale_y_continuous(trans = trans)
  }

  if (!is.null(df_prep$facet)) {
    plot <- plot +
      facet_wrap(df_prep$facet, scales = scales)
  }

  if (interactive) {
    plot <- plotly::ggplotly(plot) %>%
      style(hoverlabel = list(bgcolor = "white"), hoveron = "fill")
  }

  return(plot)
}
