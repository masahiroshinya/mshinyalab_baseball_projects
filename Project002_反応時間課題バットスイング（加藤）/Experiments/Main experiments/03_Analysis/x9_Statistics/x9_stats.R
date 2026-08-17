# x9_stats.R — Methods 2-5 の手続きに従った統計処理
# 実行: setwd("Experiments/Main experiments/03_Analysis") してから source("x9_Statistics/x9_stats.R")

library(tidyverse)
library(rstatix)

df <- read_csv("x8_StatTable/stat_table_subject.csv", show_col_types = FALSE) |>
mutate(
Subject   = factor(Subject),
Condition = factor(Condition, levels = c("free", "simple", "gonogo", "gostop"))
)

# 従属変数と、その分散分析に含める条件（反応時間だけ 3 水準）
dv_spec <- list(
RTForce_ms  = c("simple", "gonogo", "gostop"),
RTHand_ms   = c("simple", "gonogo", "gostop"),
PeakVelTop  = levels(df$Condition),
PeakVelTopX = levels(df$Condition),
PeakFz1_BW  = levels(df$Condition),
PeakFz2_BW  = levels(df$Condition)
)

run_one <- function(dv, conds) {

d <- df |>
filter(Condition %in% conds) |>
select(Subject, Condition, value = all_of(dv)) |>
drop_na(value) |>
mutate(Condition = droplevels(Condition))

# 反復測定なので、全条件が揃っていない被験者は除く
complete_subj <- d |> count(Subject) |> filter(n == length(conds)) |> pull(Subject)
d <- d |> filter(Subject %in% complete_subj)

cat("\n==================== ", dv, " ====================\n", sep = "")
cat("有効被験者数: n = ", n_distinct(d$Subject), "\n", sep = "")

if (n_distinct(d$Subject) < 3) {
    cat("被験者数が足りないため、検定は実行しません（記述統計のみ）。\n")
    print(d |> group_by(Condition) |> get_summary_stats(value, type = "mean_sd"))
    return(invisible(NULL))
    }

    cat("\n--- 記述統計 ---\n")
    print(d |> group_by(Condition) |> get_summary_stats(value, type = "mean_sd"))

    # (2) 正規性
    sw <- d |> group_by(Condition) |> shapiro_test(value)
    cat("\n--- Shapiro-Wilk 検定 ---\n"); print(sw)
    normal <- all(sw$p > .05)

    if (normal) {
        # (3)(4) 反復測定分散分析。Mauchly と Greenhouse-Geisser 補正は
        #        anova_test が自動で出す（$`Mauchly's Test`, $`Sphericity Corrections`）
        cat("\n--- 一元配置反復測定分散分析 ---\n")
        aov <- anova_test(data = d, dv = value, wid = Subject, within = Condition,
        effect.size = "pes")
        print(get_anova_table(aov, correction = "auto"))
        print(aov)

        # (5)(6) 事後検定：Bonferroni 補正の対応のある t 検定と Cohen's d
        cat("\n--- 事後検定（対応のある t 検定 / Bonferroni）---\n")
        print(d |> pairwise_t_test(value ~ Condition, paired = TRUE,
        p.adjust.method = "bonferroni"))
        print(d |> cohens_d(value ~ Condition, paired = TRUE))

        } else {
            # (7) 正規性を満たさない場合の代替手法
            cat("\n--- 正規性が棄却されたため Friedman 検定に切り替え ---\n")
            print(d |> friedman_test(value ~ Condition | Subject))
            print(d |> friedman_effsize(value ~ Condition | Subject))

            cat("\n--- 事後検定（Wilcoxon 符号付順位検定 / Bonferroni）---\n")
            print(d |> pairwise_wilcox_test(value ~ Condition, paired = TRUE,
        p.adjust.method = "bonferroni"))
        }
        }

        sink("x9_Statistics/x9_stats_result.txt", split = TRUE)
        for (dv in names(dv_spec)) run_one(dv, dv_spec[[dv]])
            sink()
