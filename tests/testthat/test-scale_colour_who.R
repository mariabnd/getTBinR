context("scale_colour_who")

test_that("scale_colour_who can be used with package plotting functions", {
  plot <- plot_tb_burden_summary(
    countries = "United Kingdom", compare_all_regions = FALSE,
    compare_to_region = TRUE, conf = NULL, verbose = FALSE
  ) +
    theme_who() +
    scale_colour_who(reverse = TRUE)

  expect_true(!is.null(plot))
  expect_equal("ggplot", class(plot)[2])
  skip_on_cran()
  vdiffr::expect_doppelganger("who-colour-summary", plot)
})


test_that("scale_color_who can be used with package plotting functions", {
  plot <- plot_tb_burden_summary(
    countries = "United Kingdom", compare_all_regions = FALSE,
    compare_to_region = TRUE, conf = NULL, verbose = FALSE
  ) +
    theme_who() +
    scale_color_who(reverse = TRUE)

  expect_true(!is.null(plot))
  expect_equal("ggplot", class(plot)[2])
  skip_on_cran()
  vdiffr::expect_doppelganger("who-color-summary", plot)
})
