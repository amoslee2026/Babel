#!/usr/bin/env python3
"""score.py - 从 metrics.json 计算 6 维度 + 5 阶段评分"""

import json
import sys
from pathlib import Path

# 问题定义中的预期值（从 complete_ai_soc_v1.json 提取）
EXPECTED = {
    "modules": 30,         # 预期模块数 25-35，取中值
    "clock_domains": 6,
    "io_count": 50,        # 外部6 + 内部44
    "area_budget_mm2": 50,
    "power_budget_w": 15,
    "npu_tops": 16,
    "cpu_dmips": 8000,
    "test_scenarios": 30,
}

AREA_BUDGET_UM2 = EXPECTED["area_budget_mm2"] * 1e6  # mm2 -> um2


def safe_div(a, b, default=0.0):
    return a / b if b and b != 0 else default


def clamp(v, lo=0.0, hi=1.0):
    return max(lo, min(hi, v))


def compute_stage_scores(m):
    """计算 5 个阶段评分"""
    stages = m["stage_metrics"]
    scores = {}

    # S1: Arch/Spec
    s1_schema = 1.0 if stages["arch"]["mas_files_count"] > 0 and stages["arch"]["completed"] else 0.0
    s1_req = clamp(safe_div(stages["arch"]["module_count"], EXPECTED["modules"]))
    s1_module = clamp(safe_div(stages["arch"]["mas_files_count"], EXPECTED["modules"]))
    scores["S1_arch"] = round(0.4 * s1_schema + 0.3 * s1_req + 0.3 * s1_module, 4)

    # S2: RTL
    s2_lint = 1.0 if stages["rtl"]["lint_errors"] == 0 else max(0, 1 - stages["rtl"]["lint_errors"] / 100)
    s2_port = clamp(safe_div(stages["rtl"]["file_count"], EXPECTED["modules"]))
    s2_style = 1.0 if stages["rtl"]["lint_warnings"] <= 5 else clamp(1 - (stages["rtl"]["lint_warnings"] - 5) / 50)
    scores["S2_rtl"] = round(0.4 * s2_lint + 0.3 * s2_port + 0.3 * s2_style, 4)

    # S3: Verification
    s3_func = clamp(stages["verification"]["functional_coverage"] / 100)
    s3_code = clamp((
        stages["verification"]["line_coverage"] +
        stages["verification"]["branch_coverage"] +
        stages["verification"]["toggle_coverage"]
    ) / 300)
    s3_test = clamp(safe_div(
        stages["verification"]["test_pass_count"],
        stages["verification"]["test_count"]
    )) if stages["verification"]["test_count"] > 0 else 0.0
    scores["S3_verification"] = round(0.35 * s3_func + 0.30 * s3_code + 0.35 * s3_test, 4)

    # S4: Synthesis
    pd = stages["pd"]
    wns = pd["wns_ns"] if pd["completed"] else -10
    s4_timing = 1.0 if wns >= 0 else max(0, 1 + wns / 10)
    synth = stages["synthesis"]
    s4_area = clamp(safe_div(AREA_BUDGET_UM2, synth["total_area_um2"])) if synth["total_area_um2"] > 0 else 0.0
    s4_module = clamp(safe_div(synth["modules_passed"], synth["modules_total"])) if synth["modules_total"] > 0 else 0.0
    scores["S4_synthesis"] = round(0.40 * s4_timing + 0.30 * s4_area + 0.30 * s4_module, 4)

    # S5: PD
    if pd["completed"]:
        s5_drc = 1.0 if pd["drc_violations"] == 0 else max(0, 1 - pd["drc_violations"] / 1000)
        s5_lvs = 1.0 if pd["lvs_match"] else 0.0
        s5_route = 1.0 if pd["routing_success"] else 0.0
        scores["S5_pd"] = round(0.40 * s5_drc + 0.35 * s5_lvs + 0.25 * s5_route, 4)
    else:
        scores["S5_pd"] = 0.0

    return scores


def compute_dimension_scores(m, stage_scores):
    """计算 6 维度评分"""
    stages = m["stage_metrics"]
    eff = m["efficiency_metrics"]
    dims = {}

    # --- Correctness (0.25) ---
    c1 = clamp(safe_div(eff["stages_completed"], eff["stages_total"]))
    gate_pass = sum(1 for s in stage_scores.values() if s >= 0.7) / 5
    c2 = gate_pass
    c3 = 1.0 if stages["arch"]["mas_files_count"] > 0 else 0.0
    c4 = 1.0 if stages["rtl"]["lint_errors"] == 0 else max(0, 1 - stages["rtl"]["lint_errors"] / 100)
    pd = stages["pd"]
    if pd["completed"]:
        c5 = (1.0 if pd["drc_violations"] == 0 else 0.0) * 0.5 + (1.0 if pd["lvs_match"] else 0.0) * 0.5
    else:
        c5 = 0.0
    correctness = 0.30 * c1 + 0.25 * c2 + 0.15 * c3 + 0.15 * c4 + 0.15 * c5
    dims["correctness"] = {
        "score": round(correctness, 4),
        "sub_scores": {
            "C1_pipeline_success": round(c1, 4),
            "C2_stage_gate_pass": round(c2, 4),
            "C3_schema_valid": round(c3, 4),
            "C4_lint_clean": round(c4, 4),
            "C5_drc_lvs_clean": round(c5, 4),
        }
    }

    # --- Completeness (0.20) ---
    cp1 = clamp(eff["stages_completed"] / 5)
    cp2 = clamp(safe_div(stages["arch"]["module_count"], EXPECTED["modules"]))
    cp3 = clamp(safe_div(stages["arch"]["io_count"], EXPECTED["io_count"]))
    cp4 = clamp(safe_div(stages["arch"]["clock_domain_count"], EXPECTED["clock_domains"]))
    cp5 = clamp(safe_div(stages["verification"]["test_count"], EXPECTED["test_scenarios"]))
    completeness = 0.30 * cp1 + 0.25 * cp2 + 0.20 * cp3 + 0.15 * cp4 + 0.10 * cp5
    dims["completeness"] = {
        "score": round(completeness, 4),
        "sub_scores": {
            "CP1_highest_stage": round(cp1, 4),
            "CP2_module_coverage": round(cp2, 4),
            "CP3_io_coverage": round(cp3, 4),
            "CP4_clock_domain_coverage": round(cp4, 4),
            "CP5_feature_coverage": round(cp5, 4),
        }
    }

    # --- Quality (0.20) ---
    wns = pd["wns_ns"] if pd["completed"] else -10
    q1 = 1.0 if wns >= 0 else max(0, 1 + wns / 10)
    synth_area = stages["synthesis"]["total_area_um2"]
    q2 = clamp(safe_div(AREA_BUDGET_UM2, synth_area)) if synth_area > 0 else 0.0
    q3 = 1.0  # power: 暂无自动测量，默认 1.0
    q4 = clamp(1 / (1 + stages["rtl"]["lint_warnings"]))
    q5 = clamp(1 / (1 + max(0, pd["drc_violations"]))) if pd["completed"] else 0.0
    quality = 0.30 * q1 + 0.25 * q2 + 0.25 * q3 + 0.10 * q4 + 0.10 * q5
    dims["quality"] = {
        "score": round(quality, 4),
        "sub_scores": {
            "Q1_timing_closure": round(q1, 4),
            "Q2_area_efficiency": round(q2, 4),
            "Q3_power_efficiency": round(q3, 4),
            "Q4_lint_warnings": round(q4, 4),
            "Q5_drc_violations": round(q5, 4),
        }
    }

    # --- Efficiency (0.15) ---
    # 基于 stages_completed 和 lint/coverage 迭代次数
    iterations = stages["verification"]["iteration_count"]
    e1 = clamp(1.0 / max(1, iterations / 3))  # 3 次迭代为基准
    e2 = clamp(safe_div(eff["stages_completed"], eff["stages_total"]))
    e3 = 1.0 if stages["rtl"]["lint_errors"] == 0 and stages["rtl"]["lint_warnings"] <= 5 else 0.5
    efficiency = 0.40 * e1 + 0.30 * e2 + 0.30 * e3
    dims["efficiency"] = {
        "score": round(efficiency, 4),
        "sub_scores": {
            "E1_iteration_efficiency": round(e1, 4),
            "E2_stage_completion": round(e2, 4),
            "E3_first_pass_quality": round(e3, 4),
        }
    }

    # --- Robustness (0.10) ---
    synth_fail = stages["synthesis"]["modules_failed"]
    r1 = clamp(1 - safe_div(synth_fail, max(1, stages["synthesis"]["modules_total"])))
    r2 = 1.0 if stages["verification"]["test_fail_count"] == 0 else clamp(
        1 - safe_div(stages["verification"]["test_fail_count"], max(1, stages["verification"]["test_count"]))
    )
    r3 = clamp(1.0 / max(1, iterations - 1)) if iterations > 1 else 1.0
    robustness = 0.50 * r1 + 0.30 * r2 + 0.20 * r3
    dims["robustness"] = {
        "score": round(robustness, 4),
        "sub_scores": {
            "R1_synth_pass_rate": round(r1, 4),
            "R2_test_pass_rate": round(r2, 4),
            "R3_iteration_stability": round(r3, 4),
        }
    }

    # --- Cost-Effectiveness (0.10) ---
    # 基于 stages_completed 作为代理（token/cost 需要额外采集）
    f1 = clamp(eff["stages_completed"] / 5)
    f2 = clamp(safe_div(stages["synthesis"]["modules_passed"], EXPECTED["modules"]))
    f3 = 1.0 if pd["completed"] and pd["gds_success"] else 0.0
    cost_eff = 0.50 * f1 + 0.30 * f2 + 0.20 * f3
    dims["cost_effectiveness"] = {
        "score": round(cost_eff, 4),
        "sub_scores": {
            "F1_stage_completion": round(f1, 4),
            "F2_synth_coverage": round(f2, 4),
            "F3_gds_delivery": round(f3, 4),
        }
    }

    return dims


def compute_final_score(dims):
    """加权求和"""
    weights = {
        "correctness": 0.25,
        "completeness": 0.20,
        "quality": 0.20,
        "efficiency": 0.15,
        "robustness": 0.10,
        "cost_effectiveness": 0.10,
    }
    return round(sum(dims[k]["score"] * w for k, w in weights.items()), 4)


def main():
    sandbox = Path(sys.argv[1])
    metrics_path = sandbox / "results" / "metrics.json"

    if not metrics_path.exists():
        print(f"ERROR: {metrics_path} not found. Run collect_results.sh first.")
        sys.exit(1)

    m = json.loads(metrics_path.read_text())

    stage_scores = compute_stage_scores(m)
    dims = compute_dimension_scores(m, stage_scores)
    final = compute_final_score(dims)

    result = {
        "sandbox": str(sandbox),
        "scored": __import__("datetime").datetime.now().isoformat(),
        "dimensions": dims,
        "stages": stage_scores,
        "final_score": final,
    }

    out_path = sandbox / "results" / "scores.json"
    out_path.write_text(json.dumps(result, indent=2, ensure_ascii=False))

    # 打印摘要
    print(f"\n{'='*60}")
    print(f"BabelBench Score: {final:.2%}")
    print(f"{'='*60}")
    print(f"\nDimensions:")
    for name, d in dims.items():
        bar = "█" * int(d["score"] * 20) + "░" * (20 - int(d["score"] * 20))
        print(f"  {name:22s} {d['score']:.2%}  {bar}")
    print(f"\nStages:")
    for name, score in stage_scores.items():
        bar = "█" * int(score * 20) + "░" * (20 - int(score * 20))
        status = "PASS" if score >= 0.7 else "FAIL"
        print(f"  {name:22s} {score:.2%}  {bar}  [{status}]")
    print(f"\nScores saved to: {out_path}")


if __name__ == "__main__":
    main()
