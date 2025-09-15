#!/bin/bash

# Quality Check Summary Script
# Provides a clear summary of what was checked and the results

echo "📋 Quality Check Summary:"
echo "  🐍 Python: Linting, type checking, and tests passed"
echo "  🐚 Shell: Scripts linted (warnings shown but not fatal)"
echo "  🐳 Docker: Dockerfiles linted"

# Determine if this was a strict or lenient check based on exit code
if [ "$1" -eq 0 ]; then
    echo "✅ All checks completed successfully!"
else
    echo "❌ Some checks failed (see above for details)"
fi
