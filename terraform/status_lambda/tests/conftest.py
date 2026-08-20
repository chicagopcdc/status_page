import os
import sys

# The Lambda package is flat (src/*.py is copied to the package root), so the
# tests import it the same way the runtime does.
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "src"))
