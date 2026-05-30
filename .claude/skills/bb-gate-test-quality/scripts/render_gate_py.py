#!/usr/bin/env python3
"""Render test gate check configuration."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "_gate_common"))
from render_gate_config import main
sys.argv = [sys.argv[0], "test"] + sys.argv[1:]
main()
