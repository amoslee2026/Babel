#!/usr/bin/env python3
"""compare.py - 对比多个 LLM 的 benchmark 运行结果"""

import json
import sys
from pathlib import Path
from datetime import datetime


def load_scores(run_dir):
    """从运行目录加载 scores.json"""
    p = Path(run_dir)
    scores_path = p / "results" / "scores.json"
    if not scores_path.exists():
        return None
    data = json.loads(scores_path.read_text())
    # 提取 LLM 名称（从目录名）
    data["run_dir"] = str(p.name)
    data["llm"] = p.name.split("_2026")[0] if "_2026" in p.name else p.name
    return data


def print_leaderboard(runs):
    """打印排行榜"""
    runs_sorted = sorted(runs, key=lambda r: r["final_score"], reverse=True)

    print(f"\n{'='*90}")
    print(f"BabelBench Leaderboard")
    print(f"Generated: {datetime.now().isoformat()}")
    print(f"Problem: complete_ai_soc_v1")
    print(f"{'='*90}\n")

    # 表头
    print(f"{'Rank':<5} {'LLM':<25} {'Score':>8} {'Correct':>9} {'Complete':>9} {'Quality':>9} {'Effic':>8} {'Robust':>8} {'Cost':>8}")
    print(f"{'-'*5} {'-'*25} {'-'*8} {'-'*9} {'-'*9} {'-'*9} {'-'*8} {'-'*8} {'-'*8}")

    for i, r in enumerate(runs_sorted, 1):
        d = r["dimensions"]
        print(f"{i:<5} {r['llm']:<25} {r['final_score']:>7.1%} "
              f"{d['correctness']['score']:>8.1%} "
              f"{d['completeness']['score']:>8.1%} "
              f"{d['quality']['score']:>8.1%} "
              f"{d['efficiency']['score']:>7.1%} "
              f"{d['robustness']['score']:>7.1%} "
              f"{d['cost_effectiveness']['score']:>7.1%}")


def print_stage_comparison(runs):
    """打印阶段对比"""
    print(f"\n{'='*90}")
    print(f"Stage-by-Stage Comparison")
    print(f"{'='*90}\n")

    print(f"{'LLM':<25} {'Arch':>8} {'RTL':>8} {'Verif':>8} {'Synth':>8} {'PD':>8} {'Done':>6}")
    print(f"{'-'*25} {'-'*8} {'-'*8} {'-'*8} {'-'*8} {'-'*8} {'-'*6}")

    for r in sorted(runs, key=lambda r: r["final_score"], reverse=True):
        s = r["stages"]
        # 计算完成的阶段数
        done = sum(1 for v in s.values() if v > 0)
        print(f"{r['llm']:<25} "
              f"{s.get('S1_arch', 0):>7.1%} "
              f"{s.get('S2_rtl', 0):>7.1%} "
              f"{s.get('S3_verification', 0):>7.1%} "
              f"{s.get('S4_synthesis', 0):>7.1%} "
              f"{s.get('S5_pd', 0):>7.1%} "
              f"{done:>5}/5")


def print_dimension_detail(runs):
    """打印各维度详细子分数"""
    for r in sorted(runs, key=lambda r: r["final_score"], reverse=True):
        print(f"\n--- {r['llm']} (Score: {r['final_score']:.1%}) ---")
        for dim_name, dim_data in r["dimensions"].items():
            print(f"  {dim_name}: {dim_data['score']:.1%}")
            for sub_name, sub_val in dim_data.get("sub_scores", {}).items():
                print(f"    {sub_name}: {sub_val:.1%}")


def generate_markdown(runs, output_path):
    """生成 Markdown 对比报告"""
    runs_sorted = sorted(runs, key=lambda r: r["final_score"], reverse=True)

    lines = []
    lines.append(f"# BabelBench Comparison Report\n")
    lines.append(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
    lines.append(f"Problem: `complete_ai_soc_v1`\n")

    # 排行榜
    lines.append(f"\n## Leaderboard\n")
    lines.append(f"| Rank | LLM | Score | Correctness | Completeness | Quality | Efficiency | Robustness | Cost |")
    lines.append(f"|------|-----|-------|-------------|-------------|---------|------------|------------|------|")
    for i, r in enumerate(runs_sorted, 1):
        d = r["dimensions"]
        lines.append(f"| {i} | {r['llm']} | **{r['final_score']:.1%}** "
                      f"| {d['correctness']['score']:.1%} | {d['completeness']['score']:.1%} "
                      f"| {d['quality']['score']:.1%} | {d['efficiency']['score']:.1%} "
                      f"| {d['robustness']['score']:.1%} | {d['cost_effectiveness']['score']:.1%} |")

    # 阶段对比
    lines.append(f"\n## Stage-by-Stage\n")
    lines.append(f"| LLM | Arch | RTL | Verification | Synthesis | PD | Completed |")
    lines.append(f"|-----|------|-----|-------------|-----------|-----|-----------|")
    for r in runs_sorted:
        s = r["stages"]
        done = sum(1 for v in s.values() if v > 0)
        lines.append(f"| {r['llm']} | {s.get('S1_arch',0):.1%} | {s.get('S2_rtl',0):.1%} "
                      f"| {s.get('S3_verification',0):.1%} | {s.get('S4_synthesis',0):.1%} "
                      f"| {s.get('S5_pd',0):.1%} | {done}/5 |")

    # 详细分析
    lines.append(f"\n## Analysis\n")
    if len(runs_sorted) >= 2:
        best = runs_sorted[0]
        worst = runs_sorted[-1]
        lines.append(f"- **Best overall**: {best['llm']} ({best['final_score']:.1%})")
        lines.append(f"- **Gap**: {best['final_score'] - worst['final_score']:.1%} between best and worst")

        # 找各维度最强
        for dim in ["correctness", "completeness", "quality", "efficiency", "robustness", "cost_effectiveness"]:
            dim_best = max(runs_sorted, key=lambda r: r["dimensions"][dim]["score"])
            lines.append(f"- **Best {dim}**: {dim_best['llm']} ({dim_best['dimensions'][dim]['score']:.1%})")

    lines.append(f"\n---\n*Generated by BabelBench*\n")

    Path(output_path).write_text("\n".join(lines))
    print(f"\nMarkdown report saved to: {output_path}")


def main():
    if len(sys.argv) < 2:
        print("Usage: compare.py <run_dir1> [run_dir2] ...")
        print("       compare.py --all <runs_parent_dir>")
        sys.exit(1)

    run_dirs = []
    if sys.argv[1] == "--all":
        parent = Path(sys.argv[2])
        run_dirs = sorted([d for d in parent.iterdir() if d.is_dir() and (d / "results" / "scores.json").exists()])
    else:
        run_dirs = [Path(d) for d in sys.argv[1:]]

    runs = []
    for d in run_dirs:
        r = load_scores(d)
        if r:
            runs.append(r)
        else:
            print(f"WARNING: No scores.json in {d}, skipping. Run score.py first.")

    if not runs:
        print("ERROR: No valid runs found.")
        sys.exit(1)

    print_leaderboard(runs)
    print_stage_comparison(runs)
    print_dimension_detail(runs)

    # 生成 Markdown 报告
    if len(runs) >= 2:
        output_dir = Path(run_dirs[0]).parent
        md_path = output_dir / "comparison_report.md"
        generate_markdown(runs, md_path)


if __name__ == "__main__":
    main()
