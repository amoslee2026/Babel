#!/usr/bin/env python3
"""Test quality gate -- delegates to shared gate runner."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "_gate_common"))
from gate_runner import main as gate_main
sys.argv = [sys.argv[0], "test"] + sys.argv[1:]
gate_main()
